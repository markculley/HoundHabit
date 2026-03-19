import SwiftUI

struct SettingsView: View {
    private let authService = AuthService()
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                NavigationLink("Account") {
                    AccountView()
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
