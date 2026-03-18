import SwiftUI

struct TrainerTabView: View {
    var body: some View {
        TabView {
            Text("Guardians")
                .tabItem { Label("Guardians", systemImage: "person.2") }
            Text("Plans")
                .tabItem { Label("Plans", systemImage: "list.bullet.clipboard") }
            Text("Invite")
                .tabItem { Label("Invite", systemImage: "envelope") }
            Text("Settings")
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
