import Testing
import Foundation
@testable import HoundHabit

@Suite("TimerViewModel logic")
struct TimerViewModelTests {

    // MARK: - formatTime

    @Test("formatTime: sub-minute 30 seconds")
    func formatTime_subMinute_30() {
        #expect(timerFormatTime(30) == ":30")
    }

    @Test("formatTime: sub-minute 5 seconds")
    func formatTime_subMinute_5() {
        #expect(timerFormatTime(5) == ":05")
    }

    @Test("formatTime: over-minute 90 seconds")
    func formatTime_overMinute_90() {
        #expect(timerFormatTime(90) == "1:30")
    }

    @Test("formatTime: over-minute 65 seconds")
    func formatTime_overMinute_65() {
        #expect(timerFormatTime(65) == "1:05")
    }

    // MARK: - calculateProgress

    @Test("progress at start is 0")
    func progress_atStart() {
        #expect(timerCalculateProgress(remaining: 30, total: 30) == 0.0)
    }

    @Test("progress at complete is 1")
    func progress_atComplete() {
        #expect(timerCalculateProgress(remaining: 0, total: 30) == 1.0)
    }

    @Test("progress halfway is 0.5")
    func progress_halfway() {
        #expect(timerCalculateProgress(remaining: 15, total: 30) == 0.5)
    }

    @Test("progress clamped when remaining is negative")
    func progress_clamped() {
        #expect(timerCalculateProgress(remaining: -1, total: 30) == 1.0)
    }

    @Test("progress is 0 when total is 0")
    func progress_zeroTotal() {
        #expect(timerCalculateProgress(remaining: 0, total: 0) == 0.0)
    }
}
