import SwiftUI

enum ItemFormMode {
    case add
    case edit(TrainingPlanItem)
}

struct TrainerPlanItemFormView: View {
    let mode: ItemFormMode
    let onSave: (String, Distance, TrainingDuration, Distraction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var distance: Distance = .armsLength
    @State private var duration: TrainingDuration = .instant
    @State private var distraction: Distraction = .none

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Step Name") {
                    TextField("e.g. Sit at arm's length", text: $title)
                }

                Section("Three D's") {
                    VStack(alignment: .leading, spacing: 12) {
                        StepPicker(label: "Distance", selection: $distance) {
                            ForEach(Distance.allCases, id: \.self) { d in
                                Text(d.label).tag(d)
                            }
                        }
                        Divider()
                        StepPicker(label: "Duration", selection: $duration) {
                            ForEach(TrainingDuration.allCases, id: \.self) { d in
                                Text(d.label).tag(d)
                            }
                        }
                        Divider()
                        StepPicker(label: "Distraction", selection: $distraction) {
                            ForEach(Distraction.allCases, id: \.self) { d in
                                Text(d.label).tag(d)
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Step" : "Add Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(trimmedTitle, distance, duration, distraction)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    private func populateIfEditing() {
        if case .edit(let item) = mode {
            title       = item.title
            distance    = item.distance
            duration    = item.duration
            distraction = item.distraction
        }
    }
}

// MARK: - StepPicker helper

private struct StepPicker<T: Hashable, Content: View>: View {
    let label: String
    @Binding var selection: T
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(label, selection: $selection) {
                content()
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

#Preview("Add") {
    TrainerPlanItemFormView(mode: .add) { _, _, _, _ in }
}

#Preview("Edit") {
    TrainerPlanItemFormView(mode: .edit(TrainingPlanItem(
        id: UUID(), planId: UUID(), sortOrder: 0,
        title: "Sit at arm's length",
        distance: .armsLength, duration: .instant, distraction: .none
    ))) { _, _, _, _ in }
}
