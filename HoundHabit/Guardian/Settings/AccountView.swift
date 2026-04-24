import SwiftUI
import Supabase

struct AccountView: View {
    @State private var profile: Profile?
    @State private var isLoading = true
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

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

                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            if isDeleting {
                                HStack {
                                    ProgressView()
                                    Text("Deleting…")
                                }
                            } else {
                                Text("Delete Account")
                            }
                        }
                        .disabled(isDeleting)
                    } footer: {
                        Text("Permanently deletes your account and all associated data (pets, training records, plans, resources, comments). This cannot be undone.")
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
        .alert("Delete your account?", isPresented: $showDeleteConfirm) {
            Button("Delete Account", role: .destructive, action: deleteAccount)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and all associated data. This cannot be undone.")
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

    private func deleteAccount() {
        isDeleting = true
        Task {
            do {
                try await authService.deleteAccount()
            } catch {
                errorMessage = error.localizedDescription
                isDeleting = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        AccountView()
    }
}
