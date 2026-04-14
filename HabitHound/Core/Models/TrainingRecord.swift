import SwiftUI

struct TrainingRecord: Codable, Identifiable, Hashable {
    let id: UUID
    var petId: UUID
    let guardianId: UUID
    var recordedAt: Date
    var status: TrainingStatus
    var distance: Distance
    var distraction: Distraction
    var duration: TrainingDuration
    var notes: String?
    var isShared: Bool
    var score: Int
    var planItemId: UUID?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case petId = "pet_id"
        case guardianId = "guardian_id"
        case recordedAt = "recorded_at"
        case status, distance, distraction, duration, notes
        case isShared = "is_shared"
        case score
        case planItemId = "plan_item_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Status

enum TrainingStatus: String, Codable, CaseIterable {
    case red, orange, yellow, green

    var color: Color {
        switch self {
        case .red:    return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green:  return .green
        }
    }

    var label: String {
        switch self {
        case .red:    return "Not getting it"
        case .orange: return "Occasional success"
        case .yellow: return "Halfway there"
        case .green:  return "Success"
        }
    }

    // Derives status from a 0–5 rep score (5 reps = one session).
    // Green (5/5) → advance; Yellow (3–4/5) / Orange (2/5) → stay; Red (0–1/5) → drop back.
    static func from(score: Int) -> TrainingStatus {
        switch score {
        case 5:     return .green
        case 3, 4:  return .yellow
        case 2:     return .orange
        default:    return .red
        }
    }

    var shortLabel: String {
        switch self {
        case .red:    return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green:  return "Green"
        }
    }
}

// MARK: - Three D's

enum Distance: String, Codable, CaseIterable {
    case armsLength = "arms_length"
    case sixFeet = "6_feet"
    case twelveFeet = "12_feet"
    case twentyFeet = "20_feet"
    case twentyPlusFeet = "20_plus_feet"

    var label: String {
        switch self {
        case .armsLength:     return "Arm's length"
        case .sixFeet:        return "6 ft"
        case .twelveFeet:     return "12 ft"
        case .twentyFeet:     return "20 ft"
        case .twentyPlusFeet: return "20+ ft"
        }
    }
}

enum Distraction: String, Codable, CaseIterable {
    case none, any

    var label: String {
        switch self {
        case .none: return "None"
        case .any:  return "Any"
        }
    }
}

enum TrainingDuration: String, Codable, CaseIterable {
    case instant
    case fiveSeconds = "5_seconds"
    case fivePlusSeconds = "5_plus_seconds"

    var label: String {
        switch self {
        case .instant:         return "Instant"
        case .fiveSeconds:     return "5 sec"
        case .fivePlusSeconds: return "5+ sec"
        }
    }
}
