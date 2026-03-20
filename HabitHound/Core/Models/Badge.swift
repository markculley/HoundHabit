import SwiftUI

struct Badge: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let badgeType: BadgeType
    let earnedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case badgeType = "badge_type"
        case earnedAt = "earned_at"
    }
}

// MARK: - BadgeType

enum BadgeType: String, Codable, CaseIterable, Identifiable {
    case firstSession    = "first_session"
    case firstGreen      = "first_green"
    case sevenDayStreak  = "7_day_streak"
    case thirtyDayStreak = "30_day_streak"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstSession:    return "First Step"
        case .firstGreen:      return "Green Light"
        case .sevenDayStreak:  return "Week Warrior"
        case .thirtyDayStreak: return "Monthly Master"
        }
    }

    var description: String {
        switch self {
        case .firstSession:    return "Logged your first training session"
        case .firstGreen:      return "Earned your first green status"
        case .sevenDayStreak:  return "Trained 7 days in a row"
        case .thirtyDayStreak: return "Trained 30 days in a row"
        }
    }

    var systemImage: String {
        switch self {
        case .firstSession:    return "pawprint.fill"
        case .firstGreen:      return "checkmark.seal.fill"
        case .sevenDayStreak:  return "flame.fill"
        case .thirtyDayStreak: return "trophy.fill"
        }
    }

    var color: Color {
        switch self {
        case .firstSession:    return .blue
        case .firstGreen:      return .green
        case .sevenDayStreak:  return .orange
        case .thirtyDayStreak: return .yellow
        }
    }
}
