import SwiftUI

struct SettingsView: View {
    var isTrainer: Bool = false

    private let authService = AuthService()
    private let inviteService = InviteService()
    @State private var errorMessage: String?
    @State private var showEnterCode = false
    @State private var linkedTrainer: LinkedTrainer?

    var body: some View {
        List {
            Section {
                NavigationLink("Account") {
                    AccountView()
                }
                NavigationLink("Notifications") {
                    NotificationSettingsView()
                }
            }

            if !isTrainer {
                Section("Trainer") {
                    if let trainer = linkedTrainer {
                        LabeledContent("Linked Trainer",
                            value: trainer.profile.fullName ?? "Trainer")
                        Text("Linked \(trainer.linkedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Enter Invite Code") {
                            showEnterCode = true
                        }
                    }
                }
            }

            Section {
                Link(destination: URL(string: "https://www.cometncloud.com/houndhabitprivacypolicy")!) {
                    HStack {
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "arrow.up.forward.square")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    Task {
                        do {
                            try await authService.signOut()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .task {
            if !isTrainer {
                linkedTrainer = try? await inviteService.fetchLinkedTrainer()
            }
        }
        .sheet(isPresented: $showEnterCode) {
            EnterInviteCodeView()
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
