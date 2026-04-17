import Foundation

struct PlanAssignment: Codable, Identifiable, Hashable {
    let id: UUID
    let planId: UUID
    let trainerId: UUID
    let guardianId: UUID
    let petId: UUID?
    let assignedAt: Date
    var currentItemId: UUID?
    /// Whether the guardian has opted in to sharing session records with the trainer.
    /// Defaults to true for trainer-assigned plans; false for self-assigned plans.
    var isShared: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case planId         = "plan_id"
        case trainerId      = "trainer_id"
        case guardianId     = "guardian_id"
        case petId          = "pet_id"
        case assignedAt     = "assigned_at"
        case currentItemId  = "current_item_id"
        case isShared       = "is_shared"
    }
}
