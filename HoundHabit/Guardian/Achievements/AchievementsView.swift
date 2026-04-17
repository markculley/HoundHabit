import SwiftUI

struct AchievementsView: View {
    let earnedBadges: [Badge]

    @Environment(\.dismiss) private var dismiss

    private func isEarned(_ type: BadgeType) -> Bool {
        earnedBadges.contains { $0.badgeType == type }
    }

    private func earnedDate(_ type: BadgeType) -> Date? {
        earnedBadges.first { $0.badgeType == type }?.earnedAt
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(BadgeType.allCases) { type in
                    let earned = isEarned(type)
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(earned ? type.color.opacity(0.15) : Color(.systemFill))
                                .frame(width: 52, height: 52)
                            Image(systemName: type.systemImage)
                                .font(.title2)
                                .foregroundStyle(earned ? type.color : Color(.tertiaryLabel))
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(type.title)
                                .font(.headline)
                                .foregroundStyle(earned ? .primary : .secondary)
                            Text(type.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let date = earnedDate(type) {
                                Text("Earned \(date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(type.color)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AchievementsView(earnedBadges: [
        Badge(id: UUID(), userId: UUID(), badgeType: .firstSession, earnedAt: Date()),
        Badge(id: UUID(), userId: UUID(), badgeType: .firstGreen,   earnedAt: Date()),
    ])
}
