import SwiftUI

struct TrainingRecordListView: View {
    /// When set, only shows records for this pet.
    var petId: UUID? = nil
    /// Optional pre-selected pet ID for the log form.
    var preselectedPetId: UUID? = nil
    /// Pet name shown in the record detail view; nil when list spans multiple pets.
    var petName: String? = nil

    @State private var viewModel = TrainingRecordViewModel()
    @State private var showLogSheet = false
    @State private var recordToEdit: TrainingRecord? = nil

    var body: some View {
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
                            TrainingRecordRow(record: record)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                Task { await viewModel.toggleSharing(record) }
                            } label: {
                                Label(
                                    record.isShared ? "Unshare" : "Share",
                                    systemImage: record.isShared ? "person.2.slash" : "person.2.fill"
                                )
                            }
                            .tint(record.isShared ? .gray : .blue)
                        }
                    }
                    .onDelete { offsets in
                        Task {
                            for i in offsets {
                                await viewModel.deleteRecord(viewModel.records[i])
                            }
                        }
                    }
                }
                .navigationDestination(for: TrainingRecord.self) { record in
                    TrainingRecordDetailView(
                        record: record,
                        petName: petName ?? viewModel.petNames[record.petId] ?? "Unknown Pet",
                        viewModel: viewModel,
                        selfLoadComments: true
                    )
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showLogSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showLogSheet) {
            TrainingRecordFormView(preselectedPetId: preselectedPetId ?? petId) { newRecord in
                viewModel.records.insert(newRecord, at: 0)
            }
        }
        .task { await viewModel.loadRecords(petId: petId) }
        .onChange(of: showLogSheet) { _, isShowing in
            if !isShowing { Task { await viewModel.loadRecords(petId: petId) } }
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

#Preview {
    NavigationStack {
        TrainingRecordListView()
            .navigationTitle("Sessions")
    }
}

// MARK: - Row

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
