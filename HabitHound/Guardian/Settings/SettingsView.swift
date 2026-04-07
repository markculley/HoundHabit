import SwiftUI

struct SettingsView: View {
    private let authService = AuthService()
    @State private var errorMessage: String?
    @State private var showEnterCode = false

    var body: some View {
        List {
            Section {
                NavigationLink("Account") {
                    AccountView()
                }
            }

            Section("Trainer") {
                Button("Enter Invite Code") {
                    showEnterCode = true
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
