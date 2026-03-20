import SwiftUI

struct DashboardView: View {
    var viewModel: DashboardViewModel

    @State private var showAchievements = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: Streak
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "flame.fill")
                            .font(.title)
                            .foregroundStyle(viewModel.currentStreak > 0 ? .orange : Color(.tertiaryLabel))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.currentStreak == 1
                                 ? "1-day streak"
                                 : "\(viewModel.currentStreak)-day streak")
                                .font(.headline)
                            Text(viewModel.currentStreak == 0
                                 ? "Log a session to start your streak!"
                                 : "Keep it up!")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: Achievements
                Section {
                    if viewModel.badges.isEmpty {
                        Text("Log your first session to earn a badge!")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.recentBadges) { badge in
                                    BadgeChipView(badge: badge)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }
                } header: {
                    HStack {
                        Text("Achievements")
                        Spacer()
                        Button("See All") { showAchievements = true }
                            .font(.caption)
                    }
                }

                // MARK: From Your Trainer (Phase 8)
                Section("From Your Trainer") {
                    Text("Nothing from your trainer yet.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                // MARK: Your Trainer (Phase 7)
                Section("Your Trainer") {
                    Text("No trainer linked yet.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            .navigationTitle("Home")
            .task { await viewModel.load() }
            .sheet(isPresented: $showAchievements) {
                AchievementsView(earnedBadges: viewModel.badges)
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

#Preview {
    DashboardView(viewModel: DashboardViewModel())
}

// MARK: - Badge chip (horizontal scroll)

private struct BadgeChipView: View {
    let badge: Badge

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(badge.badgeType.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: badge.badgeType.systemImage)
                    .foregroundStyle(badge.badgeType.color)
            }
            Text(badge.badgeType.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 60)
    }
}

