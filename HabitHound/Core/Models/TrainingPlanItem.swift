import Foundation

struct TrainingPlanItem: Codable, Identifiable, Hashable {
    let id: UUID
    let planId: UUID
    var sortOrder: Int
    var title: String
    var distance: Distance
    var duration: TrainingDuration
    var distraction: Distraction

    enum CodingKeys: String, CodingKey {
        case id
        case planId      = "plan_id"
        case sortOrder   = "sort_order"
        case title
        case distance
        case duration
        case distraction
    }
}
