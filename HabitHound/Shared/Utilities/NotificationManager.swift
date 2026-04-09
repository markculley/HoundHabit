import Foundation
import UserNotifications

struct NotificationManager {

    // MARK: - UserDefaults keys

    static let reminderEnabledKey        = "HabitHound.reminder.enabled"
    static let reminderHourKey           = "HabitHound.reminder.hour"
    static let reminderMinuteKey         = "HabitHound.reminder.minute"
    static let dailyReminderIdentifier   = "HabitHound.dailyReminder"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Persisted preferences

    var isReminderEnabled: Bool {
        defaults.bool(forKey: Self.reminderEnabledKey)
    }

    var reminderHour: Int {
        defaults.object(forKey: Self.reminderHourKey) == nil ? 9
            : defaults.integer(forKey: Self.reminderHourKey)
    }

    var reminderMinute: Int {
        defaults.integer(forKey: Self.reminderMinuteKey)
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Scheduling

    func scheduleReminder(hour: Int, minute: Int) async throws {
        // Remove any existing reminder first
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Daily Training Reminder"
        content.body  = "Time to train! Log a session in HabitHound."
        content.sound = .default

        var components = DateComponents()
        components.hour   = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.dailyReminderIdentifier,
            content: content,
            trigger: trigger
        )

        try await UNUserNotificationCenter.current().add(request)

        defaults.set(true,   forKey: Self.reminderEnabledKey)
        defaults.set(hour,   forKey: Self.reminderHourKey)
        defaults.set(minute, forKey: Self.reminderMinuteKey)
    }

    func cancelReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderIdentifier])
        defaults.set(false, forKey: Self.reminderEnabledKey)
    }

    // MARK: - Reschedule on launch

    func rescheduleIfNeeded() async {
        guard isReminderEnabled else { return }
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }
        try? await scheduleReminder(hour: reminderHour, minute: reminderMinute)
    }
}
