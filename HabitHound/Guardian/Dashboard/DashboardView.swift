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
                if !viewModel.badges.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.badges) { badge in
                                    BadgeChipView(badge: badge)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    } header: {
                        HStack {
                            Text("Achievements")
                            Spacer()
                            Button("See All") { showAchievements = true }
                                .font(.caption)
                        }
                    }
                }

                // MARK: Recent Sessions
                Section("Recent Sessions") {
                    if viewModel.isLoading && viewModel.records.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                    } else if viewModel.records.isEmpty {
                        Text("No sessions yet — tap Log to get started.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(viewModel.records) { record in
                            NavigationLink(value: record) {
                                DashboardSessionRow(
                                    record: record,
                                    petName: viewModel.petName(for: record.petId)
                                )
                            }
                        }
                        .onDelete { offsets in
                            Task {
                                for i in offsets {
                                    await viewModel.recordViewModel.deleteRecord(viewModel.records[i])
                                }
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: TrainingRecord.self) { record in
                TrainingRecordDetailView(
                    record: record,
                    petName: viewModel.petName(for: record.petId),
                    viewModel: viewModel.recordViewModel
                )
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

// MARK: - Session row

private struct DashboardSessionRow: View {
    let record: TrainingRecord
    let petName: String

    var body: some View {
        HStack(spacing: 12) {
            StatusBadgeView(status: record.status, size: 16)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(petName)
                        .font(.headline)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(record.recordedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text(record.distance.label)
                    Text("·")
                    Text(record.distraction.label)
                    Text("·")
                    Text(record.duration.label)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
