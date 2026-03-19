import SwiftUI

@main
struct HabitHoundApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(router)
        }
    }
}
