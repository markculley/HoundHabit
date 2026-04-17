import Foundation

struct TrainerGuardianLink: Codable, Identifiable, Hashable {
    let id: UUID
    let trainerId: UUID
    let guardianId: UUID
    let status: LinkStatus
    let linkedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case trainerId  = "trainer_id"
        case guardianId = "guardian_id"
        case status
        case linkedAt   = "linked_at"
    }
}

enum LinkStatus: String, Codable, CaseIterable {
    case active   = "active"
    case inactive = "inactive"
}
