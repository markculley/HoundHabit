import SwiftUI

struct ContentView: View {
    @Environment(AppRouter.self) var router

    var body: some View {
        switch router.route {
        case .unauthenticated:
            LoginView()
        case .guardian:
            GuardianTabView()
        case .trainer:
            TrainerTabView()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppRouter())
}
