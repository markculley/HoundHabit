import Foundation
import Supabase

enum PlanProgress {
    case todo
    case inProgress
    case done

    var label: String {
        switch self {
        case .todo:       return "To Do"
        case .inProgress: return "In Progress"
        case .done:       return "Done"
        }
    }
}

@MainActor
@Observable
class GuardianPlanViewModel {
    var assignedPlans: [AssignedPlan] = []
    var items: [UUID: [TrainingPlanItem]] = [:]      // keyed by plan.id
    var behaviors: [UUID: [Behavior]] = [:]           // keyed by plan.id
    /// All of the guardian's training records — used to compute per-step completion.
    var records: [TrainingRecord] = []
    var isLoading = false
    var errorMessage: String?
    var lastAdvancementMessage: String?

    private let service = TrainingPlanService()
    private let recordService = TrainingRecordService()

    // MARK: - Load

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            assignedPlans = try await service.fetchAssignedPlans()
            guard !assignedPlans.isEmpty else { return }

            // Capture before entering task groups (main actor isolation).
            let plansToFetch = assignedPlans

            typealias ItemPair     = (UUID, [TrainingPlanItem])
            typealias BehaviorPair = (UUID, [Behavior])

            let fetchedItems: [ItemPair] = await withTaskGroup(of: ItemPair.self) { group in
                for ap in plansToFetch {
                    let planId = ap.plan.id
                    group.addTask {
                        let result = try? await TrainingPlanService().fetchAssignedPlanItems(planId: planId)
                        return (planId, result ?? [])
                    }
                }
                var collected: [ItemPair] = []
                for await pair in group { collected.append(pair) }
                return collected
            }

            let fetchedBehaviors: [BehaviorPair] = await withTaskGroup(of: BehaviorPair.self) { group in
                for ap in plansToFetch {
                    let planId = ap.plan.id
                    group.addTask {
                        let result = try? await TrainingPlanService().fetchBehaviors(planId: planId)
                        return (planId, result ?? [])
                    }
                }
                var collected: [BehaviorPair] = []
                for await pair in group { collected.append(pair) }
                return collected
            }

            for (planId, planItems) in fetchedItems {
                items[planId] = planItems
            }
            for (planId, planBehaviors) in fetchedBehaviors {
                behaviors[planId] = planBehaviors
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sharing

    func updateSharing(for assignedPlan: AssignedPlan, isShared: Bool) async {
        do {
            try await service.updateAssignmentSharing(assignmentId: assignedPlan.assignment.id, isShared: isShared)
            if let idx = assignedPlans.firstIndex(where: { $0.assignment.id == assignedPlan.assignment.id }) {
                assignedPlans[idx].assignment.isShared = isShared
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadItems(for planId: UUID) async {
        do {
            async let fetchedItems     = service.fetchAssignedPlanItems(planId: planId)
            async let fetchedBehaviors = service.fetchBehaviors(planId: planId)
            items[planId]     = try await fetchedItems
            behaviors[planId] = try await fetchedBehaviors
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Loads all of the guardian's training records. Used to compute per-step
    /// completion in the plan detail view.
    func loadRecords() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        records = (try? await recordService.fetchRecords(guardianId: userId)) ?? []
    }

    // MARK: - Step Completion

    /// A step is **complete** once the guardian has logged a score of 5 on it on
    /// 3 consecutive calendar days. Completion is sticky — any historical 3-day
    /// run counts, and once earned it stays earned.
    ///
    /// Returns whether the step is complete and the longest historical run of
    /// consecutive calendar days that each had a score-5 session (the streak the
    /// step list shows as "N / 3 days" while incomplete).
    func stepCompletion(planItemId: UUID) -> (isComplete: Bool, bestStreak: Int) {
        let calendar = Calendar.current
        let perfectDays = Set(
            records
                .filter { $0.planItemId == planItemId && $0.score == 5 }
                .map { calendar.startOfDay(for: $0.recordedAt) }
        ).sorted()
        guard !perfectDays.isEmpty else { return (false, 0) }

        var best = 1
        var run = 1
        for i in 1..<perfectDays.count {
            if calendar.date(byAdding: .day, value: 1, to: perfectDays[i - 1]) == perfectDays[i] {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
        }
        return (best >= 3, best)
    }

    /// Steps are gated sequentially **within a behavior**: a step is locked
    /// until the previous step in the same behavior is complete. The first step
    /// of a behavior is never locked, and behaviors are independent of one
    /// another. Steps with no behavior (legacy data) are sequenced among themselves.
    func isStepLocked(_ item: TrainingPlanItem) -> Bool {
        let siblings = (items[item.planId] ?? [])
            .filter { $0.behaviorId == item.behaviorId }
            .sorted { $0.sortOrder < $1.sortOrder }
        guard let index = siblings.firstIndex(where: { $0.id == item.id }), index > 0 else {
            return false   // first step in the behavior — always unlocked
        }
        return !stepCompletion(planItemId: siblings[index - 1].id).isComplete
    }

    // MARK: - Plan Progress

    func planProgress(for assignedPlan: AssignedPlan) -> PlanProgress {
        guard let currentId = assignedPlan.assignment.currentItemId else { return .todo }
        let sorted = (items[assignedPlan.plan.id] ?? []).sorted { $0.sortOrder < $1.sortOrder }
        guard let lastItem = sorted.last else { return .inProgress }
        return currentId == lastItem.id ? .done : .inProgress
    }

    // MARK: - Current Step

    /// Resolves the current step for an assignment. Falls back to the first step when
    /// `currentItemId` is nil (i.e. the Guardian hasn't practiced yet).
    func currentItem(for assignedPlan: AssignedPlan, in items: [TrainingPlanItem]) -> TrainingPlanItem? {
        let sorted = items.sorted { $0.sortOrder < $1.sortOrder }
        guard !sorted.isEmpty else { return nil }
        if let currentId = assignedPlan.assignment.currentItemId {
            return sorted.first { $0.id == currentId } ?? sorted.first
        }
        return sorted.first
    }

    // MARK: - Step Advancement

    /// After a plan-linked session is logged, updates `current_item_id` on the assignment
    /// based on the 0–5 rep score and sets `lastAdvancementMessage` for display.
    func advanceCurrentStep(assignedPlan: AssignedPlan, score: Int, planItems: [TrainingPlanItem]) async {
        let sorted = planItems.sorted { $0.sortOrder < $1.sortOrder }
        guard !sorted.isEmpty else { return }

        guard let currentIdx = sorted.firstIndex(where: { item in
            item.id == (assignedPlan.assignment.currentItemId ?? sorted.first?.id)
        }) else { return }

        let newIdx: Int
        if score == 5 {
            newIdx = min(currentIdx + 1, sorted.count - 1)
        } else if score <= 1 {
            newIdx = max(currentIdx - 1, 0)
        } else {
            newIdx = currentIdx
        }

        let newItem = sorted[newIdx]
        lastAdvancementMessage = advancementMessage(
            score: score,
            oldIdx: currentIdx,
            newIdx: newIdx,
            item: newItem,
            total: sorted.count
        )

        // Always persist: even "stay" sets currentItemId if it was nil
        guard newItem.id != assignedPlan.assignment.currentItemId else { return }

        do {
            try await service.updateCurrentItem(assignmentId: assignedPlan.assignment.id, itemId: newItem.id)
            // Update in-memory so the view reflects immediately
            if let planIdx = assignedPlans.firstIndex(where: { $0.assignment.id == assignedPlan.assignment.id }) {
                assignedPlans[planIdx].assignment.currentItemId = newItem.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private

    private func advancementMessage(score: Int, oldIdx: Int, newIdx: Int, item: TrainingPlanItem, total: Int) -> String {
        if score == 5 {
            if newIdx > oldIdx {
                return "Great work! Moving to step \(item.sortOrder + 1): \(item.title)."
            } else {
                return "Amazing — you've mastered all the steps in this plan!"
            }
        } else if score <= 1 {
            if newIdx < oldIdx {
                return "Let's build some confidence on step \(item.sortOrder + 1): \(item.title)."
            } else {
                return "Keep working on step \(item.sortOrder + 1). You've got this!"
            }
        } else {
            return "Good progress! Keep practicing step \(item.sortOrder + 1): \(item.title)."
        }
    }
}
