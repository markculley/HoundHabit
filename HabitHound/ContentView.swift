import SwiftUI

struct ContentView: View {
    @Environment(AppRouter.self) var router
    @Environment(ErrorStore.self) var errorStore

    var body: some View {
        Group {
            switch router.route {
            case .unauthenticated:
                LoginView()
            case .guardian:
                GuardianTabView()
            case .trainer:
                TrainerTabView()
            }
        }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { errorStore.message != nil },
            set: { if !$0 { errorStore.message = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorStore.message ?? "")
        }
    }
}

#Preview {
    ContentView()
        .environment(AppRouter())
        .environment(ErrorStore())
}
