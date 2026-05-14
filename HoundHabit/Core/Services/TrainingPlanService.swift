import Foundation
import Supabase

struct TrainingPlanService {

    // MARK: - Trainer: Plans

    func fetchPlans() async throws -> [TrainingPlan] {
        guard let trainerId = supabase.auth.currentUser?.id else { return [] }
        return try await supabase
            .from("training_plans")
            .select()
            .eq("trainer_id", value: trainerId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func createPlan(title: String, description: String?) async throws -> TrainingPlan {
        guard let trainerId = supabase.auth.currentUser?.id else {
            throw PlanError.notAuthenticated
        }
        let insert = PlanInsert(trainerId: trainerId, title: title, description: description)
        return try await supabase
            .from("training_plans")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    func updatePlan(_ plan: TrainingPlan) async throws -> TrainingPlan {
        let update = PlanUpdate(title: plan.title, description: plan.description)
        return try await supabase
            .from("training_plans")
            .update(update)
            .eq("id", value: plan.id)
            .select()
            .single()
            .execute()
            .value
    }

    func deletePlan(id: UUID) async throws {
        try await supabase
            .from("training_plans")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Trainer: Behaviors

    func fetchBehaviors(planId: UUID) async throws -> [Behavior] {
        return try await supabase
            .from("behaviors")
            .select()
            .eq("plan_id", value: planId)
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    func createBehavior(planId: UUID, name: String, sortOrder: Int) async throws -> Behavior {
        let insert = BehaviorInsert(planId: planId, name: name, sortOrder: sortOrder)
        return try await supabase
            .from("behaviors")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    func updateBehavior(_ behavior: Behavior) async throws -> Behavior {
        let update = BehaviorUpdate(name: behavior.name, sortOrder: behavior.sortOrder)
        return try await supabase
            .from("behaviors")
            .update(update)
            .eq("id", value: behavior.id)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteBehavior(id: UUID) async throws {
        try await supabase
            .from("behaviors")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Persists new sort_order values for behaviors after a drag-reorder.
    func reorderBehaviors(_ behaviors: [Behavior]) async throws {
        guard !behaviors.isEmpty else { return }
        let updates = behaviors.enumerated().map { idx, b in
            BehaviorReorderUpdate(id: b.id, sortOrder: idx)
        }
        for u in updates {
            guard let name = behaviors.first(where: { $0.id == u.id })?.name else { continue }
            try await supabase
                .from("behaviors")
                .update(BehaviorUpdate(name: name, sortOrder: u.sortOrder))
                .eq("id", value: u.id)
                .execute()
        }
    }

    // MARK: - Trainer: Items

    func fetchItems(planId: UUID) async throws -> [TrainingPlanItem] {
        return try await supabase
            .from("training_plan_items")
            .select()
            .eq("plan_id", value: planId)
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    func fetchItems(behaviorId: UUID) async throws -> [TrainingPlanItem] {
        return try await supabase
            .from("training_plan_items")
            .select()
            .eq("behavior_id", value: behaviorId)
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    func createItem(
        planId: UUID,
        behaviorId: UUID?,
        title: String,
        distance: Distance,
        duration: TrainingDuration,
        distraction: Distraction,
        distanceCustomValue: String? = nil,
        durationCustomValue: String? = nil,
        distractionCustomValue: String? = nil,
        sortOrder: Int
    ) async throws -> TrainingPlanItem {
        let insert = ItemInsert(
            planId: planId,
            behaviorId: behaviorId,
            sortOrder: sortOrder,
            title: title,
            distance: distance,
            duration: duration,
            distraction: distraction,
            distanceCustomValue: distanceCustomValue,
            durationCustomValue: durationCustomValue,
            distractionCustomValue: distractionCustomValue
        )
        return try await supabase
            .from("training_plan_items")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    func updateItem(_ item: TrainingPlanItem) async throws -> TrainingPlanItem {
        let update = ItemUpdate(
            behaviorId: item.behaviorId,
            sortOrder: item.sortOrder,
            title: item.title,
            distance: item.distance,
            duration: item.duration,
            distraction: item.distraction,
            distanceCustomValue: item.distanceCustomValue,
            durationCustomValue: item.durationCustomValue,
            distractionCustomValue: item.distractionCustomValue
        )
        return try await supabase
            .from("training_plan_items")
            .update(update)
            .eq("id", value: item.id)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteItem(id: UUID) async throws {
        try await supabase
            .from("training_plan_items")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Replaces all items for a plan to persist new sort_order values after a drag-reorder.
    func reorderItems(_ items: [TrainingPlanItem]) async throws {
        guard !items.isEmpty else { return }
        let planId = items[0].planId
        try await supabase
            .from("training_plan_items")
            .delete()
            .eq("plan_id", value: planId)
            .execute()
        let inserts = items.enumerated().map { idx, item in
            ItemInsert(
                planId: item.planId,
                behaviorId: item.behaviorId,
                sortOrder: idx,
                title: item.title,
                distance: item.distance,
                duration: item.duration,
                distraction: item.distraction,
                distanceCustomValue: item.distanceCustomValue,
                durationCustomValue: item.durationCustomValue,
                distractionCustomValue: item.distractionCustomValue
            )
        }
        try await supabase
            .from("training_plan_items")
            .insert(inserts)
            .execute()
    }

    // MARK: - Trainer: Assignments

    func assignPlan(planId: UUID, guardianId: UUID, petId: UUID?) async throws -> PlanAssignment {
        guard let trainerId = supabase.auth.currentUser?.id else {
            throw PlanError.notAuthenticated
        }
        let insert = AssignmentInsert(planId: planId, trainerId: trainerId, guardianId: guardianId, petId: petId, isShared: true)
        return try await supabase
            .from("plan_assignments")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    func fetchAssignments(planId: UUID) async throws -> [PlanAssignment] {
        return try await supabase
            .from("plan_assignments")
            .select()
            .eq("plan_id", value: planId)
            .order("assigned_at", ascending: false)
            .execute()
            .value
    }

    /// Bulk fetch of every assignment owned by the current trainer. Used by the
    /// trainer's Plans list to badge rows with an assignment count without
    /// running one query per plan.
    func fetchAllAssignments() async throws -> [PlanAssignment] {
        guard let trainerId = supabase.auth.currentUser?.id else { return [] }
        return try await supabase
            .from("plan_assignments")
            .select()
            .eq("trainer_id", value: trainerId)
            .execute()
            .value
    }

    func deleteAssignment(id: UUID) async throws {
        try await supabase
            .from("plan_assignments")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Guardian: Assigned Plans

    func fetchAssignedPlans() async throws -> [AssignedPlan] {
        guard let guardianId = supabase.auth.currentUser?.id else { return [] }
        let assignments: [PlanAssignment] = try await supabase
            .from("plan_assignments")
            .select()
            .eq("guardian_id", value: guardianId)
            .order("assigned_at", ascending: false)
            .execute()
            .value
        guard !assignments.isEmpty else { return [] }
        let planIds = assignments.map(\.planId)
        let plans: [TrainingPlan] = try await supabase
            .from("training_plans")
            .select()
            .in("id", values: planIds)
            .execute()
            .value
        return assignments.compactMap { assignment in
            guard let plan = plans.first(where: { $0.id == assignment.planId }) else { return nil }
            return AssignedPlan(assignment: assignment, plan: plan)
        }
    }

    /// Returns the behavior name for a given plan item, or nil for items with no behavior or standalone sessions.
    func fetchBehaviorName(for planItemId: UUID) async throws -> String? {
        let item: TrainingPlanItem = try await supabase
            .from("training_plan_items")
            .select()
            .eq("id", value: planItemId)
            .single()
            .execute()
            .value
        guard let behaviorId = item.behaviorId else { return nil }
        let behavior: Behavior = try await supabase
            .from("behaviors")
            .select()
            .eq("id", value: behaviorId)
            .single()
            .execute()
            .value
        return behavior.name
    }

    func fetchAssignedPlanItems(planId: UUID) async throws -> [TrainingPlanItem] {
        return try await supabase
            .from("training_plan_items")
            .select()
            .eq("plan_id", value: planId)
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    func updateCurrentItem(assignmentId: UUID, itemId: UUID) async throws {
        let update = CurrentItemUpdate(currentItemId: itemId)
        try await supabase
            .from("plan_assignments")
            .update(update)
            .eq("id", value: assignmentId)
            .execute()
    }

    /// Updates the pet linked to an existing self-assignment.
    func updateAssignmentPet(assignmentId: UUID, petId: UUID?) async throws {
        struct PetUpdate: Encodable {
            let petId: UUID?
            enum CodingKeys: String, CodingKey { case petId = "pet_id" }
        }
        try await supabase
            .from("plan_assignments")
            .update(PetUpdate(petId: petId))
            .eq("id", value: assignmentId)
            .execute()
    }

    /// Toggles whether a guardian shares their session records with the trainer for this plan.
    func updateAssignmentSharing(assignmentId: UUID, isShared: Bool) async throws {
        try await supabase
            .from("plan_assignments")
            .update(SharingUpdate(isShared: isShared))
            .eq("id", value: assignmentId)
            .execute()
    }

    /// Duplicates a plan (+ behaviors + items) into a new lineage owned by the caller.
    /// Backed by the `copy_plan(uuid)` Postgres RPC, which performs the copy atomically.
    func copyPlan(planId: UUID) async throws -> TrainingPlan {
        struct Params: Encodable { let source_plan_id: UUID }
        let newPlanId: UUID = try await supabase
            .rpc("copy_plan", params: Params(source_plan_id: planId))
            .execute()
            .value

        return try await supabase
            .from("training_plans")
            .select()
            .eq("id", value: newPlanId)
            .single()
            .execute()
            .value
    }

}

// MARK: - AssignedPlan (join result, guardian's perspective)

struct AssignedPlan: Identifiable, Hashable {
    var id: UUID { assignment.id }
    var assignment: PlanAssignment
    let plan: TrainingPlan
}

// MARK: - Errors

enum PlanError: LocalizedError {
    case notAuthenticated
    case alreadyAssigned

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be signed in to perform this action."
        case .alreadyAssigned:  return "This guardian is already assigned to this plan."
        }
    }
}

// MARK: - Encodable helpers

private struct PlanInsert: Encodable {
    let trainerId: UUID
    let title: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case trainerId  = "trainer_id"
        case title
        case description
    }
}

private struct PlanUpdate: Encodable {
    let title: String
    let description: String?
}

private struct BehaviorInsert: Encodable {
    let planId: UUID
    let name: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case planId    = "plan_id"
        case name
        case sortOrder = "sort_order"
    }
}

private struct BehaviorUpdate: Encodable {
    let name: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case name
        case sortOrder = "sort_order"
    }
}

private struct BehaviorReorderUpdate {
    let id: UUID
    let sortOrder: Int
}

private struct ItemInsert: Encodable {
    let planId: UUID
    let behaviorId: UUID?
    let sortOrder: Int
    let title: String
    let distance: Distance
    let duration: TrainingDuration
    let distraction: Distraction
    let distanceCustomValue: String?
    let durationCustomValue: String?
    let distractionCustomValue: String?

    enum CodingKeys: String, CodingKey {
        case planId                 = "plan_id"
        case behaviorId             = "behavior_id"
        case sortOrder              = "sort_order"
        case title
        case distance
        case duration
        case distraction
        case distanceCustomValue    = "distance_custom"
        case durationCustomValue    = "duration_custom"
        case distractionCustomValue = "distraction_custom"
    }
}

private struct ItemUpdate: Encodable {
    let behaviorId: UUID?
    let sortOrder: Int
    let title: String
    let distance: Distance
    let duration: TrainingDuration
    let distraction: Distraction
    let distanceCustomValue: String?
    let durationCustomValue: String?
    let distractionCustomValue: String?

    enum CodingKeys: String, CodingKey {
        case behaviorId             = "behavior_id"
        case sortOrder              = "sort_order"
        case title
        case distance
        case duration
        case distraction
        case distanceCustomValue    = "distance_custom"
        case durationCustomValue    = "duration_custom"
        case distractionCustomValue = "distraction_custom"
    }
}

private struct CurrentItemUpdate: Encodable {
    let currentItemId: UUID

    enum CodingKeys: String, CodingKey {
        case currentItemId = "current_item_id"
    }
}

private struct AssignmentInsert: Encodable {
    let planId: UUID
    let trainerId: UUID
    let guardianId: UUID
    let petId: UUID?
    let isShared: Bool

    enum CodingKeys: String, CodingKey {
        case planId      = "plan_id"
        case trainerId   = "trainer_id"
        case guardianId  = "guardian_id"
        case petId       = "pet_id"
        case isShared    = "is_shared"
    }
}

private struct SharingUpdate: Encodable {
    let isShared: Bool
    enum CodingKeys: String, CodingKey { case isShared = "is_shared" }
}
