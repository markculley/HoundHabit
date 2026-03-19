import SwiftUI
import Supabase

struct AccountView: View {
    @State private var profile: Profile?
    @State private var isLoading = true

    private let authService = AuthService()

    private var user: Supabase.User? {
        supabase.auth.currentUser
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Account") {
                        LabeledContent("Role", value: profile?.role.rawValue.capitalized ?? "—")
                        LabeledContent("Name", value: profile?.fullName ?? "—")
                        LabeledContent("Email", value: user?.email ?? "—")
                    }

                    Section("Dates") {
                        if let createdAt = user?.createdAt {
                            LabeledContent("Created", value: createdAt.formatted(date: .abbreviated, time: .shortened))
                        }
                        if let lastSignIn = user?.lastSignInAt {
                            LabeledContent("Last Login", value: lastSignIn.formatted(date: .abbreviated, time: .shortened))
                        } else {
                            LabeledContent("Last Login", value: "—")
                        }
                    }
                }
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            profile = try? await authService.currentProfile()
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        AccountView()
    }
}
