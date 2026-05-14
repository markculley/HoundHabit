import Foundation

/// The 12 standard dog-training behaviors. A behavior is picked from this fixed
/// list — there is no free-text behavior name.
///
/// Raw values are the display labels (not snake_case like the Three D's enums)
/// so the shared `behaviors.name` column stays human-readable across both
/// clients; a DB CHECK constraint enforces these exact values.
enum BehaviorType: String, Codable, CaseIterable, Hashable {
    case sit       = "Sit"
    case down      = "Down"
    case leaveIt   = "Leave It"
    case dropIt    = "Drop It"
    case stand     = "Stand"
    case waitStay  = "Wait/Stay"
    case walk      = "Walk"
    case touch     = "Touch"
    case goToMat   = "Go to Mat"
    case recall    = "Recall"
    case off       = "Off"
    case attention = "Attention"

    var label: String { rawValue }
}

struct Behavior: Codable, Identifiable, Hashable {
    let id: UUID
    let planId: UUID
    var type: BehaviorType
    var sortOrder: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case planId    = "plan_id"
        case type      = "name"   // DB column is `name`; values are BehaviorType raw values
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }
}
