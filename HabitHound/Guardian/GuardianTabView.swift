import SwiftUI

struct GuardianTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house") }
            PetListView()
                .tabItem { Label("Pets", systemImage: "pawprint") }
            Text("Log")
                .tabItem { Label("Log", systemImage: "plus.circle.fill") }
            Text("Resources")
                .tabItem { Label("Resources", systemImage: "folder") }
            Text("Settings")
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
