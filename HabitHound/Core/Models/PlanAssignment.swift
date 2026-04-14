import Foundation

struct PlanAssignment: Codable, Identifiable, Hashable {
    let id: UUID
    let planId: UUID
    let trainerId: UUID
    let guardianId: UUID
    let petId: UUID?
    let assignedAt: Date
    var currentItemId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case planId         = "plan_id"
        case trainerId      = "trainer_id"
        case guardianId     = "guardian_id"
        case petId          = "pet_id"
        case assignedAt     = "assigned_at"
        case currentItemId  = "current_item_id"
    }
}
