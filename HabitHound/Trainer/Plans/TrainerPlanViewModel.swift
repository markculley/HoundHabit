import Foundation

@Observable
class TrainerPlanViewModel {
    var plans: [TrainingPlan] = []
    var items: [UUID: [TrainingPlanItem]] = [:]       // keyed by plan.id
    var assignments: [UUID: [PlanAssignment]] = [:]   // keyed by plan.id
    var guardians: [LinkedGuardian] = []
    var isLoading = false
    var errorMessage: String?

    private let service = TrainingPlanService()
    private let inviteService = InviteService()

    // MARK: - Plans

    func loadPlans() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let fetchedPlans     = service.fetchPlans()
            async let fetchedGuardians = inviteService.fetchLinkedGuardians()
            plans    = try await fetchedPlans
            guardians = (try? await fetchedGuardians) ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func guardianName(for guardianId: UUID) -> String {
        guardians.first { $0.guardianId == guardianId }?.profile.fullName ?? "Guardian"
    }

    func createPlan(title: String, description: String?) async {
        do {
            let plan = try await service.createPlan(title: title, description: description)
            plans.insert(plan, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updatePlan(_ plan: TrainingPlan) async {
        do {
            let updated = try await service.updatePlan(plan)
            if let idx = plans.firstIndex(where: { $0.id == plan.id }) {
                plans[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deletePlan(_ plan: TrainingPlan) async {
        do {
            try await service.deletePlan(id: plan.id)
            plans.removeAll { $0.id == plan.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Items

    func loadItems(for planId: UUID) async {
        do {
            items[planId] = try await service.fetchItems(planId: planId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addItem(to planId: UUID, title: String, distance: Distance, duration: TrainingDuration, distraction: Distraction) async {
        let nextOrder = items[planId, default: []].count
        do {
            let item = try await service.createItem(
                planId: planId,
                title: title,
                distance: distance,
                duration: duration,
                distraction: distraction,
                sortOrder: nextOrder
            )
            items[planId, default: []].append(item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateItem(_ item: TrainingPlanItem) async {
        do {
            let updated = try await service.updateItem(item)
            if let idx = items[item.planId]?.firstIndex(where: { $0.id == item.id }) {
                items[item.planId]![idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteItem(_ item: TrainingPlanItem) async {
        do {
            try await service.deleteItem(id: item.id)
            items[item.planId]?.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveItems(in planId: UUID, from source: IndexSet, to destination: Int) async {
        // Immediate in-memory reorder — prevents list snapping back during network call
        items[planId, default: []].move(fromOffsets: source, toOffset: destination)
        for idx in items[planId, default: []].indices {
            items[planId]![idx].sortOrder = idx
        }
        do {
            try await service.reorderItems(items[planId, default: []])
        } catch {
            errorMessage = error.localizedDescription
            await loadItems(for: planId)  // recover consistent state on failure
        }
    }

    // MARK: - Assignments

    func loadAssignments(for planId: UUID) async {
        do {
            assignments[planId] = try await service.fetchAssignments(planId: planId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func assignPlan(_ planId: UUID, to guardianId: UUID, petId: UUID?) async {
        do {
            let assignment = try await service.assignPlan(
                planId: planId,
                guardianId: guardianId,
                petId: petId
            )
            assignments[planId, default: []].insert(assignment, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAssignment(_ assignment: PlanAssignment) async {
        do {
            try await service.deleteAssignment(id: assignment.id)
            assignments[assignment.planId]?.removeAll { $0.id == assignment.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
