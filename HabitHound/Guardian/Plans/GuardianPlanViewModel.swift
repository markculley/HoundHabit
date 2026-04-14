import Foundation

@Observable
class GuardianPlanViewModel {
    var assignedPlans: [AssignedPlan] = []
    var items: [UUID: [TrainingPlanItem]] = [:]   // keyed by plan.id
    var isLoading = false
    var errorMessage: String?
    var lastAdvancementMessage: String?

    private let service = TrainingPlanService()

    // MARK: - Load

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            assignedPlans = try await service.fetchAssignedPlans()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadItems(for planId: UUID) async {
        do {
            items[planId] = try await service.fetchAssignedPlanItems(planId: planId)
        } catch {
            errorMessage = error.localizedDescription
        }
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
