import Foundation

struct TrainingPlanItem: Codable, Identifiable, Hashable {
    let id: UUID
    let planId: UUID
    var sortOrder: Int
    var title: String
    var description: String?

    enum CodingKeys: String, CodingKey {
        case id
        case planId      = "plan_id"
        case sortOrder   = "sort_order"
        case title
        case description
    }
}
