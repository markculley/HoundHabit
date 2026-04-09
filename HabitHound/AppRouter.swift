import SwiftUI
import Supabase

enum AppRoute {
    case unauthenticated
    case guardian
    case trainer
}

@Observable
class AppRouter {
    var route: AppRoute = .unauthenticated

    private let authService = AuthService()

    init() {
        Task { await observeAuthChanges() }
    }

    private func observeAuthChanges() async {
        for await (event, _) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                await resolveRoute()
            case .signedOut, .userDeleted:
                await MainActor.run { route = .unauthenticated }
            default:
                break
            }
        }
    }

    private func resolveRoute() async {
        do {
            if let profile = try await authService.currentProfile() {
                let newRoute: AppRoute = profile.role == .guardian ? .guardian : .trainer
                await MainActor.run { route = newRoute }
                if profile.role == .guardian {
                    Task { await NotificationManager().rescheduleIfNeeded() }
                }
            } else {
                await MainActor.run { route = .unauthenticated }
            }
        } catch {
            await MainActor.run { route = .unauthenticated }
        }
    }
}
