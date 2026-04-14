import SwiftUI

// MARK: - Result type

struct ItemFormResult {
    var title: String
    var distance: Distance
    var duration: TrainingDuration
    var distraction: Distraction
    var distanceCustomValue: String?
    var durationCustomValue: String?
    var distractionCustomValue: String?
}

// MARK: - Mode

enum ItemFormMode {
    case add
    case edit(TrainingPlanItem)
}

// MARK: - View

struct TrainerPlanItemFormView: View {
    let mode: ItemFormMode
    let onSave: (ItemFormResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var distance: Distance = .armsLength
    @State private var duration: TrainingDuration = .instant
    @State private var distraction: Distraction = .none
    @State private var distanceCustomValue = ""
    @State private var durationCustomValue = ""
    @State private var distractionCustomValue = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if distance == .custom && distanceCustomValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if duration == .custom && durationCustomValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if distraction == .custom && distractionCustomValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Step Name") {
                    TextField("e.g. Sit at arm's length", text: $title)
                }

                Section("Three D's") {
                    VStack(alignment: .leading, spacing: 12) {
                        DPicker(label: "Distance", selection: $distance) {
                            ForEach(Distance.allCases, id: \.self) { d in
                                Text(d.label).tag(d)
                            }
                        }
                        if distance == .custom {
                            TextField("Enter distance…", text: $distanceCustomValue)
                                .textFieldStyle(.roundedBorder)
                                .padding(.top, 4)
                        }
                        Divider()
                        DPicker(label: "Duration", selection: $duration) {
                            ForEach(TrainingDuration.allCases, id: \.self) { d in
                                Text(d.label).tag(d)
                            }
                        }
                        if duration == .custom {
                            TextField("Enter duration…", text: $durationCustomValue)
                                .textFieldStyle(.roundedBorder)
                                .padding(.top, 4)
                        }
                        Divider()
                        DPicker(label: "Distraction", selection: $distraction) {
                            ForEach(Distraction.allCases, id: \.self) { d in
                                Text(d.label).tag(d)
                            }
                        }
                        if distraction == .custom {
                            TextField("Enter distraction…", text: $distractionCustomValue)
                                .textFieldStyle(.roundedBorder)
                                .padding(.top, 4)
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
                        let result = ItemFormResult(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            distance: distance,
                            duration: duration,
                            distraction: distraction,
                            distanceCustomValue: distance == .custom ? distanceCustomValue.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                            durationCustomValue: duration == .custom ? durationCustomValue.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                            distractionCustomValue: distraction == .custom ? distractionCustomValue.trimmingCharacters(in: .whitespacesAndNewlines) : nil
                        )
                        onSave(result)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    private func populateIfEditing() {
        guard case .edit(let item) = mode else { return }
        title                 = item.title
        distance              = item.distance
        duration              = item.duration
        distraction           = item.distraction
        distanceCustomValue   = item.distanceCustomValue ?? ""
        durationCustomValue   = item.durationCustomValue ?? ""
        distractionCustomValue = item.distractionCustomValue ?? ""
    }
}

// MARK: - DPicker helper

private struct DPicker<T: Hashable, Content: View>: View {
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
    TrainerPlanItemFormView(mode: .add) { _ in }
}

#Preview("Edit") {
    TrainerPlanItemFormView(mode: .edit(TrainingPlanItem(
        id: UUID(), planId: UUID(), behaviorId: nil, sortOrder: 0,
        title: "Sit at arm's length",
        distance: .armsLength, duration: .instant, distraction: .none,
        distanceCustomValue: nil, durationCustomValue: nil, distractionCustomValue: nil
    ))) { _ in }
}
