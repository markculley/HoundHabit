import SwiftUI

struct GuardianTabView: View {
    @State private var selectedTab = 0
    @State private var dashboardViewModel = DashboardViewModel()
    @State private var logPath = NavigationPath()
    @State private var plansPath = NavigationPath()
    @State private var settingsPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(viewModel: dashboardViewModel, switchToPlansTab: {
                selectedTab = 3
            })
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            PetListView()
                .tabItem { Label("Pets", systemImage: "pawprint") }
                .tag(1)

            NavigationStack(path: $logPath) {
                TrainingRecordListView()
                    .navigationTitle("Sessions")
            }
            .tabItem { Label("Log", systemImage: "list.bullet.clipboard") }
            .tag(2)

            NavigationStack(path: $plansPath) {
                GuardianPlanListView()
            }
            .tabItem { Label("Plans", systemImage: "list.bullet.clipboard") }
            .tag(3)

            NavigationStack(path: $settingsPath) {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(4)
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 0 { Task { await dashboardViewModel.load() } }
            logPath = NavigationPath()
            plansPath = NavigationPath()
            settingsPath = NavigationPath()
        }
    }
}

#Preview {
    GuardianTabView()
}
