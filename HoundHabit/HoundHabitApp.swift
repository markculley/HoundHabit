import SwiftUI

@main
struct HoundHabitApp: App {
    @State private var router = AppRouter()
    @State private var errorStore = ErrorStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(router)
                .environment(errorStore)
        }
    }
}
