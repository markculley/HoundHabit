import Foundation

struct Pet: Codable, Identifiable {
    let id: UUID
    let guardianId: UUID
    var name: String
    var breed: String?
    var photoUrl: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case guardianId = "guardian_id"
        case name
        case breed
        case photoUrl = "photo_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
