import SwiftUI

struct ContentView: View {
    @Environment(AppRouter.self) var router
    @Environment(ErrorStore.self) var errorStore
    @State private var showSplash = true

    var body: some View {
        ZStack {
            mainContent
            if showSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut(duration: 0.35)) {
                showSplash = false
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

    @ViewBuilder
    private var mainContent: some View {
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
        .environment(ErrorStore())
}
