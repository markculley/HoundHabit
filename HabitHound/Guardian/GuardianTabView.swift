import SwiftUI

struct GuardianTabView: View {
    @State private var selectedTab = 0
    @State private var showLogSheet = false
    @State private var dashboardViewModel = DashboardViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(viewModel: dashboardViewModel)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            PetListView()
                .tabItem { Label("Pets", systemImage: "pawprint") }
                .tag(1)

            // Log tab acts as a floating action — tapping bounces back and shows the form
            Color.clear
                .tabItem { Label("Log", systemImage: "plus.circle.fill") }
                .tag(2)

            Text("Resources")
                .tabItem { Label("Resources", systemImage: "folder") }
                .tag(3)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(4)
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            if newTab == 2 {
                selectedTab = oldTab
                showLogSheet = true
            }
        }
        .sheet(isPresented: $showLogSheet) {
            TrainingRecordFormView()
        }
        .onChange(of: showLogSheet) { _, isShowing in
            if !isShowing { Task { await dashboardViewModel.load() } }
        }
    }
}

#Preview {
    GuardianTabView()
}
