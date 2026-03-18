import SwiftUI

struct GuardianTabView: View {
    var body: some View {
        TabView {
            Text("Home")
                .tabItem { Label("Home", systemImage: "house") }
            Text("Pets")
                .tabItem { Label("Pets", systemImage: "pawprint") }
            Text("Log")
                .tabItem { Label("Log", systemImage: "plus.circle.fill") }
            Text("Materials")
                .tabItem { Label("Materials", systemImage: "folder") }
            Text("Settings")
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
