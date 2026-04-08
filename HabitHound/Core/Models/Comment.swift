import Foundation

struct Comment: Codable, Identifiable, Hashable {
    let id: UUID
    let trainingRecordId: UUID
    let authorId: UUID
    let body: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case trainingRecordId = "training_record_id"
        case authorId         = "author_id"
        case body
        case createdAt        = "created_at"
        case updatedAt        = "updated_at"
    }
}
