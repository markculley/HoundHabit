import Foundation

struct Invite: Codable, Identifiable, Hashable {
    let id: UUID
    let trainerId: UUID
    let email: String
    let code: String
    let status: InviteStatus
    let createdAt: Date
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case trainerId = "trainer_id"
        case email, code, status
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}

enum InviteStatus: String, Codable, CaseIterable {
    case pending  = "pending"
    case accepted = "accepted"
    case expired  = "expired"
}
