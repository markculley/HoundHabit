import Foundation

/// The 12 standard dog-training behaviors offered as presets.
///
/// Raw values are the display labels (not snake_case like the Three D's enums)
/// so the shared `behaviors.name` column stays human-readable across both
/// clients.
enum StandardBehavior: String, Codable, CaseIterable, Hashable {
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

/// A behavior's type: either one of the 12 standard presets, or a free-text
/// name a trainer typed. Both persist as a single string in `behaviors.name`,
/// so the guardian client and the DB column are unchanged by the distinction.
///
/// A custom name that exactly matches a standard label collapses to `.standard`
/// (see `init(rawValue:)`), keeping the taxonomy deterministic.
enum BehaviorType: Codable, Hashable {
    case standard(StandardBehavior)
    case custom(String)

    init(rawValue: String) {
        if let standard = StandardBehavior(rawValue: rawValue) {
            self = .standard(standard)
        } else {
            self = .custom(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .standard(let s): return s.rawValue
        case .custom(let name): return name
        }
    }

    var label: String { rawValue }

    var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }

    // Persist as a bare string so `Behavior.type` ⇄ `name` stays a plain column.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self.init(rawValue: raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
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
