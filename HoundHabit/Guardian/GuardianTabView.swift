import SwiftUI

struct GuardianTabView: View {
    @State private var selectedTab = 0
    @State private var dashboardViewModel = DashboardViewModel()
    @State private var plansPath = NavigationPath()
    @State private var resourcesPath = NavigationPath()
    @State private var settingsPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(viewModel: dashboardViewModel, switchToPlansTab: {
                selectedTab = 2
            })
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            PetListView()
                .tabItem { Label("Pets", systemImage: "pawprint") }
                .tag(1)

            NavigationStack(path: $plansPath) {
                GuardianPlanListView()
            }
            .tabItem { Label("Plans", systemImage: "list.bullet.clipboard") }
            .tag(2)

            NavigationStack(path: $resourcesPath) {
                ResourceListView()
                    .navigationTitle("Resources")
            }
            .tabItem { Label("Resources", systemImage: "folder") }
            .tag(3)

            NavigationStack(path: $settingsPath) {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(4)
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 0 { Task { await dashboardViewModel.load() } }
            plansPath = NavigationPath()
            resourcesPath = NavigationPath()
            settingsPath = NavigationPath()
        }
    }
}

#Preview {
    GuardianTabView()
}
