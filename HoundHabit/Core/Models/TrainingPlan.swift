import Foundation

struct TrainingPlan: Codable, Identifiable, Hashable {
    let id: UUID
    let trainerId: UUID
    var title: String
    var description: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case trainerId   = "trainer_id"
        case title
        case description
        case createdAt   = "created_at"
        case updatedAt   = "updated_at"
    }
}
