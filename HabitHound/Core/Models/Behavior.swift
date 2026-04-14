import Foundation

struct Behavior: Codable, Identifiable, Hashable {
    let id: UUID
    let planId: UUID
    var name: String
    var sortOrder: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case planId    = "plan_id"
        case name
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }
}
