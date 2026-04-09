import SwiftUI

struct GuardianTabView: View {
    @State private var selectedTab = 0
    @State private var dashboardViewModel = DashboardViewModel()

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

            NavigationStack {
                TrainingRecordListView()
                    .navigationTitle("Sessions")
            }
            .tabItem { Label("Log", systemImage: "list.bullet.clipboard") }
            .tag(2)

            NavigationStack {
                GuardianPlanListView()
            }
            .tabItem { Label("Plans", systemImage: "list.bullet.clipboard") }
            .tag(3)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(4)
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 0 { Task { await dashboardViewModel.load() } }
        }
    }
}

#Preview {
    GuardianTabView()
}
