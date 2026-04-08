import SwiftUI

struct SettingsView: View {
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
            }

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
            linkedTrainer = try? await inviteService.fetchLinkedTrainer()
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
