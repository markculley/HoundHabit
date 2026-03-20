import Foundation

struct BadgeService {
    func fetchBadges(userId: UUID) async throws -> [Badge] {
        try await supabase
            .from("badges")
            .select()
            .eq("user_id", value: userId.uuidString.lowercased())
            .order("earned_at")
            .execute()
            .value
    }
}
