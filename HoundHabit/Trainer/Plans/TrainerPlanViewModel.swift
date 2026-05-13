import Foundation

@Observable
class TrainerPlanViewModel {
    var plans: [TrainingPlan] = []
    var behaviors: [UUID: [Behavior]] = [:]          // keyed by plan.id
    var items: [UUID: [TrainingPlanItem]] = [:]      // keyed by plan.id (all items across behaviors)
    var assignments: [UUID: [PlanAssignment]] = [:]  // keyed by plan.id
    var guardians: [LinkedGuardian] = []
    var pets: [UUID: Pet] = [:]                     // keyed by pet.id
    var isLoading = false
    var errorMessage: String?

    private let service = TrainingPlanService()
    private let inviteService = InviteService()
    private let petService = PetService()

    // MARK: - Plans

    func loadPlans() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let fetchedPlans     = service.fetchPlans()
            async let fetchedGuardians = inviteService.fetchLinkedGuardians()
            plans     = try await fetchedPlans
            guardians = (try? await fetchedGuardians) ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func guardianName(for guardianId: UUID) -> String {
        guardians.first { $0.guardianId == guardianId }?.profile.fullName ?? "Guardian"
    }

    func petName(for petId: UUID?) -> String {
        guard let petId else { return "Any pet" }
        return pets[petId]?.name ?? "Pet"
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

    /// Returns the newly-copied plan, or nil on error. Adds it to `plans` so
    /// the trainer's list reflects the copy without a refetch.
    func copyPlan(_ source: TrainingPlan) async -> TrainingPlan? {
        do {
            let copy = try await service.copyPlan(planId: source.id)
            plans.insert(copy, at: 0)
            return copy
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Behaviors

    func loadBehaviors(for planId: UUID) async {
        do {
            behaviors[planId] = try await service.fetchBehaviors(planId: planId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addBehavior(to planId: UUID, name: String) async {
        let nextOrder = behaviors[planId, default: []].count
        do {
            let behavior = try await service.createBehavior(
                planId: planId,
                name: name,
                sortOrder: nextOrder
            )
            behaviors[planId, default: []].append(behavior)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateBehavior(_ behavior: Behavior) async {
        do {
            let updated = try await service.updateBehavior(behavior)
            if let idx = behaviors[behavior.planId]?.firstIndex(where: { $0.id == behavior.id }) {
                behaviors[behavior.planId]![idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteBehavior(_ behavior: Behavior) async {
        do {
            try await service.deleteBehavior(id: behavior.id)
            behaviors[behavior.planId]?.removeAll { $0.id == behavior.id }
            // Also remove items that belonged to this behavior
            items[behavior.planId]?.removeAll { $0.behaviorId == behavior.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveBehaviors(in planId: UUID, from source: IndexSet, to destination: Int) async {
        behaviors[planId, default: []].move(fromOffsets: source, toOffset: destination)
        for idx in behaviors[planId, default: []].indices {
            behaviors[planId]![idx].sortOrder = idx
        }
        do {
            try await service.reorderBehaviors(behaviors[planId, default: []])
        } catch {
            errorMessage = error.localizedDescription
            await loadBehaviors(for: planId)
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

    func loadItems(for behavior: Behavior) async {
        do {
            let fetched = try await service.fetchItems(behaviorId: behavior.id)
            // Merge into the plan-level items dictionary
            let planId = behavior.planId
            var current = items[planId, default: []]
            current.removeAll { $0.behaviorId == behavior.id }
            current.append(contentsOf: fetched)
            items[planId] = current
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addItem(
        to planId: UUID,
        behaviorId: UUID?,
        title: String,
        distance: Distance,
        duration: TrainingDuration,
        distraction: Distraction,
        distanceCustomValue: String? = nil,
        durationCustomValue: String? = nil,
        distractionCustomValue: String? = nil
    ) async {
        let behaviorItems = items[planId, default: []].filter { $0.behaviorId == behaviorId }
        let nextOrder = behaviorItems.count
        do {
            let item = try await service.createItem(
                planId: planId,
                behaviorId: behaviorId,
                title: title,
                distance: distance,
                duration: duration,
                distraction: distraction,
                distanceCustomValue: distanceCustomValue,
                durationCustomValue: durationCustomValue,
                distractionCustomValue: distractionCustomValue,
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

    func moveItems(in planId: UUID, behaviorId: UUID?, from source: IndexSet, to destination: Int) async {
        var behaviorItems = items[planId, default: []].filter { $0.behaviorId == behaviorId }
        behaviorItems.move(fromOffsets: source, toOffset: destination)
        for idx in behaviorItems.indices {
            behaviorItems[idx].sortOrder = idx
        }
        // Merge back into the plan-level items list
        var allItems = items[planId, default: []].filter { $0.behaviorId != behaviorId }
        allItems.append(contentsOf: behaviorItems)
        items[planId] = allItems
        do {
            try await service.reorderItems(behaviorItems)
        } catch {
            errorMessage = error.localizedDescription
            await loadItems(for: planId)
        }
    }

    // MARK: - Assignment Progress

    func planProgress(for assignment: PlanAssignment) -> PlanProgress {
        guard let currentId = assignment.currentItemId else { return .todo }
        let sorted = (items[assignment.planId] ?? []).sorted { $0.sortOrder < $1.sortOrder }
        guard let lastItem = sorted.last else { return .inProgress }
        return currentId == lastItem.id ? .done : .inProgress
    }

    // MARK: - Assignments

    func loadAssignments(for planId: UUID) async {
        do {
            let fetched = try await service.fetchAssignments(planId: planId)
            assignments[planId] = fetched
            // Fetch pets for every guardian that appears in these assignments
            let guardianIds = Array(Set(fetched.map(\.guardianId)))
            var fetchedPets: [Pet] = []
            await withTaskGroup(of: [Pet].self) { group in
                for guardianId in guardianIds {
                    group.addTask { (try? await self.petService.fetchPets(guardianId: guardianId)) ?? [] }
                }
                for await result in group {
                    fetchedPets.append(contentsOf: result)
                }
            }
            for pet in fetchedPets {
                pets[pet.id] = pet
            }
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
