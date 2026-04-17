import SwiftUI
import UserNotifications

// MARK: - ViewModel

@Observable
final class NotificationSettingsViewModel {
    var isEnabled: Bool = false
    var reminderTime: Date = Calendar.current.date(
        bySettingHour: 9, minute: 0, second: 0, of: Date()
    ) ?? Date()
    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var errorMessage: String?

    private let manager = NotificationManager()

    func onAppear() async {
        isEnabled = manager.isReminderEnabled
        authorizationStatus = await manager.authorizationStatus()
        // Restore saved time into the picker
        var components = DateComponents()
        components.hour   = manager.reminderHour
        components.minute = manager.reminderMinute
        if let date = Calendar.current.date(from: components) {
            reminderTime = date
        }
    }

    func toggleReminder() async {
        if isEnabled {
            // Turning off
            manager.cancelReminder()
            isEnabled = false
        } else {
            // Turning on — request permission first
            let granted = await manager.requestPermission()
            authorizationStatus = await manager.authorizationStatus()
            guard granted else {
                isEnabled = false
                return
            }
            let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            do {
                try await manager.scheduleReminder(
                    hour: components.hour ?? 9,
                    minute: components.minute ?? 0
                )
                isEnabled = true
            } catch {
                errorMessage = error.localizedDescription
                isEnabled = false
            }
        }
    }

    func updateReminderTime(_ date: Date) async {
        guard isEnabled else { return }
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        do {
            try await manager.scheduleReminder(
                hour: components.hour ?? 9,
                minute: components.minute ?? 0
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - View

struct NotificationSettingsView: View {
    @State private var viewModel = NotificationSettingsViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section("Daily Reminder") {
                Toggle("Remind me to train", isOn: Binding(
                    get: { viewModel.isEnabled },
                    set: { _ in Task { await viewModel.toggleReminder() } }
                ))

                if viewModel.isEnabled {
                    DatePicker(
                        "Time",
                        selection: $viewModel.reminderTime,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: viewModel.reminderTime) { _, newTime in
                        Task { await viewModel.updateReminderTime(newTime) }
                    }
                }
            }

            if viewModel.authorizationStatus == .denied {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notifications are disabled")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Enable notifications for Hound Habit in iOS Settings to receive daily reminders.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Notifications")
        .task { await viewModel.onAppear() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.onAppear() } }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
