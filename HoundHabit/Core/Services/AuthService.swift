import Foundation
import Supabase

struct AuthService {

    // MARK: - Email / Password

    func signUp(email: String, password: String, fullName: String, role: Profile.Role) async throws {
        // Profile is created automatically via a Postgres trigger on auth.users.
        // We pass role and full_name as metadata so the trigger can read them.
        try await supabase.auth.signUp(
            email: email,
            password: password,
            data: ["full_name": .string(fullName), "role": .string(role.rawValue)]
        )
    }

    func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    // MARK: - Apple

    func signInWithApple(idToken: String, nonce: String) async throws {
        try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    // MARK: - Profile

    func currentProfile() async throws -> Profile? {
        guard let userId = supabase.auth.currentUser?.id else { return nil }
        return try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
    }

    func fetchProfile(id: UUID) async throws -> Profile? {
        try await supabase
            .from("profiles")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }
}

