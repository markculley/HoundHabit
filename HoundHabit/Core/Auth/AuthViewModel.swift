import Foundation
import AuthenticationServices
import CryptoKit

@Observable
class AuthViewModel {
    var email = ""
    var password = ""
    var fullName = ""
    var selectedRole: Profile.Role = .guardian
    var isLoading = false
    var errorMessage: String?

    private let authService = AuthService()
    private var pendingNonce: String?

    // MARK: - Email / Password

    func signIn() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await authService.signIn(email: email, password: password)
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func signUp() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await authService.signUp(
                email: email,
                password: password,
                fullName: fullName,
                role: selectedRole
            )
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    // MARK: - Sign in with Apple

    /// Call in the `request` closure of SignInWithAppleButton to get the hashed nonce.
    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        pendingNonce = nonce
        return sha256(nonce)
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let idTokenData = credential.identityToken,
                let idToken = String(data: idTokenData, encoding: .utf8),
                let nonce = pendingNonce
            else {
                errorMessage = "Apple Sign In failed: missing credentials."
                return
            }
            Task {
                isLoading = true
                defer { isLoading = false }
                do {
                    try await authService.signInWithApple(idToken: idToken, nonce: nonce)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Error mapping

    private func friendlyMessage(for error: Error) -> String {
        let raw = error.localizedDescription.lowercased()
        if raw.contains("email") && (raw.contains("invalid") || raw.contains("phone")) {
            return "Please enter a valid email address."
        }
        if raw.contains("invalid login credentials") || raw.contains("invalid password") {
            return "Incorrect email or password."
        }
        if raw.contains("user already registered") || raw.contains("already been registered") {
            return "An account with this email already exists."
        }
        if raw.contains("password should be at least") {
            return "Password must be at least 6 characters."
        }
        if raw.contains("network") || raw.contains("internet") {
            return "Connection error. Please check your internet and try again."
        }
        return error.localizedDescription
    }

    // MARK: - Helpers

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        return randomBytes.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
