import Foundation

@Observable
class DashboardViewModel {
    /// Shared with TrainingRecordDetailView so edits/deletes propagate back to the feed.
    var recordViewModel = TrainingRecordViewModel()
    var pets: [Pet] = []
    var badges: [Badge] = []
    var currentStreak: Int = 0
    var isLoading = false
    var errorMessage: String?

    var linkedTrainer: LinkedTrainer?
    var planCount: Int = 0

    private let petService = PetService()
    private let badgeService = BadgeService()
    private let inviteService = InviteService()
    private let planService = TrainingPlanService()

    var records: [TrainingRecord] { recordViewModel.records }

    /// The 3 most recently earned badges, shown on the dashboard.
    var recentBadges: [Badge] {
        badges.sorted { $0.earnedAt > $1.earnedAt }.prefix(3).map { $0 }
    }

    func load() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let fetchedPets    = petService.fetchPets(guardianId: userId)
            async let fetchedBadges  = badgeService.fetchBadges(userId: userId)
            async let fetchedTrainer = inviteService.fetchLinkedTrainer()
            async let fetchedPlans   = planService.fetchAssignedPlans()
            await recordViewModel.loadRecords()
            pets          = try await fetchedPets
            badges        = (try? await fetchedBadges) ?? []
            linkedTrainer = try? await fetchedTrainer
            planCount     = (try? await fetchedPlans)?.count ?? 0
            currentStreak = computeStreak()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func petName(for petId: UUID) -> String {
        pets.first { $0.id == petId }?.name ?? "Unknown Pet"
    }

    // MARK: - Streak

    private func computeStreak() -> Int {
        DashboardViewModel.computeStreak(sessionDates: records.map { $0.recordedAt })
    }

    /// Pure function — extracted for testability.
    /// `today` defaults to now; pass a fixed date in tests.
    static func computeStreak(sessionDates: [Date], today: Date = Date()) -> Int {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)

        // Unique calendar days that have at least one session
        let sessionDays = Set(sessionDates.map { calendar.startOfDay(for: $0) })
        guard !sessionDays.isEmpty else { return 0 }

        // Start from today; if no session today, try yesterday
        var checkDate = todayStart
        if !sessionDays.contains(todayStart) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart),
                  sessionDays.contains(yesterday) else { return 0 }
            checkDate = yesterday
        }

        var streak = 0
        while sessionDays.contains(checkDate) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }
}
