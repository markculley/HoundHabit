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

    func createItem(planId: UUID, title: String, description: String?, sortOrder: Int) async throws -> TrainingPlanItem {
        let insert = ItemInsert(planId: planId, sortOrder: sortOrder, title: title, description: description)
        return try await supabase
            .from("training_plan_items")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    func updateItem(_ item: TrainingPlanItem) async throws -> TrainingPlanItem {
        let update = ItemUpdate(sortOrder: item.sortOrder, title: item.title, description: item.description)
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
            ItemInsert(planId: item.planId, sortOrder: idx, title: item.title, description: item.description)
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
        let insert = AssignmentInsert(planId: planId, trainerId: trainerId, guardianId: guardianId, petId: petId)
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

    func fetchAssignedPlanItems(planId: UUID) async throws -> [TrainingPlanItem] {
        return try await supabase
            .from("training_plan_items")
            .select()
            .eq("plan_id", value: planId)
            .order("sort_order", ascending: true)
            .execute()
            .value
    }
}

// MARK: - AssignedPlan (join result, guardian's perspective)

struct AssignedPlan: Identifiable, Hashable {
    var id: UUID { assignment.id }
    let assignment: PlanAssignment
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

private struct ItemInsert: Encodable {
    let planId: UUID
    let sortOrder: Int
    let title: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case planId      = "plan_id"
        case sortOrder   = "sort_order"
        case title
        case description
    }
}

private struct ItemUpdate: Encodable {
    let sortOrder: Int
    let title: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case sortOrder   = "sort_order"
        case title
        case description
    }
}

private struct AssignmentInsert: Encodable {
    let planId: UUID
    let trainerId: UUID
    let guardianId: UUID
    let petId: UUID?

    enum CodingKeys: String, CodingKey {
        case planId      = "plan_id"
        case trainerId   = "trainer_id"
        case guardianId  = "guardian_id"
        case petId       = "pet_id"
    }
}
