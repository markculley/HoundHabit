import SwiftUI

struct DashboardView: View {
    var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.records.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.records.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "list.bullet.clipboard",
                        description: Text("Tap Log to record your first training session.")
                    )
                } else {
                    List {
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
                    .navigationDestination(for: TrainingRecord.self) { record in
                        TrainingRecordDetailView(record: record, petName: viewModel.petName(for: record.petId), viewModel: viewModel.recordViewModel)
                    }
                }
            }
            .navigationTitle("Home")
            .task { await viewModel.load() }
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

// MARK: - Row

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
