import Testing
import Foundation
@testable import HoundHabit

@Suite("NotificationManager preferences")
struct NotificationManagerTests {

    private func makeManager() -> NotificationManager {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        return NotificationManager(defaults: defaults)
    }

    @Test("Default reminder hour is 9")
    func defaultHourIsNine() {
        let manager = makeManager()
        #expect(manager.reminderHour == 9)
    }

    @Test("Default reminder minute is 0")
    func defaultMinuteIsZero() {
        let manager = makeManager()
        #expect(manager.reminderMinute == 0)
    }

    @Test("Default reminder enabled is false")
    func defaultEnabledIsFalse() {
        let manager = makeManager()
        #expect(manager.isReminderEnabled == false)
    }

    @Test("cancelReminder sets enabled to false")
    func cancelReminderSetsEnabledFalse() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(true, forKey: NotificationManager.reminderEnabledKey)
        let manager = NotificationManager(defaults: defaults)
        manager.cancelReminder()
        #expect(manager.isReminderEnabled == false)
    }

    @Test("Persists custom hour and minute")
    func persistsCustomTime() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(14, forKey: NotificationManager.reminderHourKey)
        defaults.set(30, forKey: NotificationManager.reminderMinuteKey)
        let manager = NotificationManager(defaults: defaults)
        #expect(manager.reminderHour == 14)
        #expect(manager.reminderMinute == 30)
    }
}
