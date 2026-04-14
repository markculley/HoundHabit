import SwiftUI

struct TrainerTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                GuardianListView()
            }
            .tabItem { Label("Guardians", systemImage: "person.2") }

            NavigationStack {
                TrainerPlanListView()
            }
            .tabItem { Label("Plans", systemImage: "list.bullet.clipboard") }

            NavigationStack {
                InviteView()
            }
            .tabItem { Label("Invite", systemImage: "envelope") }

            NavigationStack {
                SettingsView(isTrainer: true)
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    TrainerTabView()
}
