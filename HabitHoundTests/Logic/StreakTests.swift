import Testing
import Foundation
@testable import HabitHound

@Suite("Streak computation")
struct StreakTests {

    /// Builds a Date for a given number of days offset from `today`.
    /// Negative = past, 0 = today.
    private func day(_ offset: Int, relativeTo today: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: today)!
    }

    private func streak(_ offsets: [Int], today: Date = Date()) -> Int {
        let dates = offsets.map { day($0, relativeTo: today) }
        return DashboardViewModel.computeStreak(sessionDates: dates, today: today)
    }

    // MARK: - Basic cases

    @Test func noSessions_returnsZero() {
        #expect(streak([]) == 0)
    }

    @Test func sessionToday_returnsOne() {
        #expect(streak([0]) == 1)
    }

    @Test func sessionYesterdayOnly_returnsOne() {
        #expect(streak([-1]) == 1)
    }

    @Test func gapTwoDaysAgo_returnsZero() {
        // Last session was 2 days ago — streak is broken
        #expect(streak([-2]) == 0)
    }

    // MARK: - Consecutive days

    @Test func threeDaysIncludingToday() {
        #expect(streak([0, -1, -2]) == 3)
    }

    @Test func threeDaysEndingYesterday() {
        #expect(streak([-1, -2, -3]) == 3)
    }

    @Test func fiveDayStreak() {
        #expect(streak([0, -1, -2, -3, -4]) == 5)
    }

    // MARK: - Gaps in history

    @Test func gapInMiddle_countsFromMostRecent() {
        // Sessions today, yesterday, and 3 days ago (gap on day -2)
        #expect(streak([0, -1, -3]) == 2)
    }

    @Test func onlyOldSessions_returnsZero() {
        #expect(streak([-5, -6, -7]) == 0)
    }

    // MARK: - Duplicates (multiple sessions on same day)

    @Test func multipleSessionsSameDay_countAsOne() {
        // Two sessions today should not inflate the streak
        #expect(streak([0, 0]) == 1)
    }

    @Test func multipleSessionsPerDayOverStreak() {
        // 3-day streak with 2 sessions on day 0 and 3 on day -1
        #expect(streak([0, 0, -1, -1, -1, -2]) == 3)
    }
}
