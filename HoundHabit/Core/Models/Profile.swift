import Foundation

struct Profile: Codable, Identifiable {
    let id: UUID
    let role: Role
    var fullName: String?
    var avatarUrl: String?
    let createdAt: Date
    let updatedAt: Date

    enum Role: String, Codable {
        case guardian
        case trainer
    }

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
