import SwiftUI

struct TrainingRecordDetailView: View {
    let record: TrainingRecord
    let petName: String
    let viewModel: TrainingRecordViewModel

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    private var current: TrainingRecord? {
        viewModel.records.first { $0.id == record.id }
    }

    var body: some View {
        Group {
            if let r = current {
                List {
                    Section("Pet") {
                        Text(petName)
                    }

                    Section("Status") {
                        HStack(spacing: 12) {
                            StatusBadgeView(status: r.status, size: 24)
                            Text(r.status.label)
                                .font(.headline)
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Date & Time") {
                        Text(r.recordedAt.formatted(date: .long, time: .shortened))
                    }

                    Section("Three D's") {
                        LabeledContent("Distance",    value: r.distance.label)
                        LabeledContent("Distraction", value: r.distraction.label)
                        LabeledContent("Duration",    value: r.duration.label)
                    }

                    if let notes = r.notes, !notes.isEmpty {
                        Section("Notes") {
                            Text(notes)
                                .foregroundStyle(.primary)
                        }
                    }

                    Section {
                        LabeledContent("Shared with Trainer", value: r.isShared ? "Yes" : "No")
                    }

                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Text("Delete Session")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
                .navigationTitle(r.recordedAt.formatted(date: .abbreviated, time: .omitted))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") { showEditSheet = true }
                    }
                }
                .sheet(isPresented: $showEditSheet) {
                    TrainingRecordFormView(existingRecord: r, petName: petName) { updated in
                        Task { await viewModel.updateRecord(updated) }
                    }
                }
                .confirmationDialog(
                    "Delete this session?",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        Task {
                            await viewModel.deleteRecord(r)
                            dismiss()
                        }
                    }
                } message: {
                    Text("This cannot be undone.")
                }
            }
        }
        .onChange(of: current == nil) { _, isGone in
            if isGone { dismiss() }
        }
    }
}

#Preview {
    let vm = TrainingRecordViewModel()
    let record = TrainingRecord(
        id: UUID(),
        petId: UUID(),
        guardianId: UUID(),
        recordedAt: Date(),
        status: .green,
        distance: .sixFeet,
        distraction: .none,
        duration: .fiveSeconds,
        notes: "Great focus today!",
        isShared: true,
        createdAt: Date(),
        updatedAt: Date()
    )
    vm.records = [record]
    return NavigationStack {
        TrainingRecordDetailView(record: record, petName: "Ozzie", viewModel: vm)
    }
}
