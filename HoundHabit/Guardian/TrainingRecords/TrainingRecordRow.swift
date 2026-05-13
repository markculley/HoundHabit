import SwiftUI

struct TrainingRecordRow: View {
    let record: TrainingRecord

    var body: some View {
        HStack(spacing: 12) {
            StatusBadgeView(status: record.status, size: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.recordedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
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
            Spacer()
            if record.isShared {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    List {
        TrainingRecordRow(record: TrainingRecord(
            id: UUID(),
            petId: UUID(),
            guardianId: UUID(),
            recordedAt: Date(),
            status: .green,
            distance: .armsLength,
            distraction: .none,
            duration: .instant,
            distanceCustomValue: nil,
            durationCustomValue: nil,
            distractionCustomValue: nil,
            notes: nil,
            isShared: true,
            score: 5,
            planItemId: nil,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
}
