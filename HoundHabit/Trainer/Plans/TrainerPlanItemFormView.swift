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

/// Form for adding or editing a step (`training_plan_items` row).
///
/// In **add mode** the form keeps an explicit Save button — the row doesn't
/// exist yet and validation gates insertion.
///
/// In **edit mode** the form auto-saves on every change:
/// - `TextField` commits with a ~500ms debounce after the last keystroke.
/// - `Picker` and toggle changes commit immediately.
/// - An empty title shows an inline error and does NOT auto-revert; the user
///   is mid-edit. Commits resume once the title becomes non-empty again.
/// - Swipe-to-dismiss flushes any pending debounced commit.
struct TrainerPlanItemFormView: View {
    let mode: ItemFormMode
    /// Called once when the user taps Save (create flow only).
    var onSave: ((ItemFormResult) -> Void)? = nil
    /// Called every time a field commits (edit flow only — debounced for text,
    /// immediate for pickers).
    var onCommit: ((ItemFormResult) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var distance: Distance = .armsLength
    @State private var duration: TrainingDuration = .instant
    @State private var distraction: Distraction = .none
    @State private var distanceCustomValue = ""
    @State private var durationCustomValue = ""
    @State private var distractionCustomValue = ""

    @State private var commitTask: Task<Void, Never>? = nil
    @State private var hasPopulated = false

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var titleError: String? {
        isEditing && trimmedTitle.isEmpty ? "Title can't be empty" : nil
    }

    private var canSave: Bool {
        guard !trimmedTitle.isEmpty else { return false }
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
                        .onSubmit { commitIfEditing(immediate: true) }
                    if let titleError {
                        Text(titleError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
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
                    Button(isEditing ? "Done" : "Cancel") {
                        if isEditing { commitIfEditing(immediate: true) }
                        dismiss()
                    }
                }
                if !isEditing {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            onSave?(makeResult())
                            dismiss()
                        }
                        .disabled(!canSave)
                    }
                }
            }
            .onAppear {
                if !hasPopulated {
                    populateIfEditing()
                    hasPopulated = true
                }
            }
            .onDisappear {
                // Flush any pending debounced commit so a swipe-down doesn't lose the latest edit.
                if isEditing { commitIfEditing(immediate: true) }
            }
            // Auto-save wiring — only fires in edit mode.
            .onChange(of: title) { _, _ in scheduleDebouncedCommit() }
            .onChange(of: distanceCustomValue) { _, _ in scheduleDebouncedCommit() }
            .onChange(of: durationCustomValue) { _, _ in scheduleDebouncedCommit() }
            .onChange(of: distractionCustomValue) { _, _ in scheduleDebouncedCommit() }
            .onChange(of: distance) { _, _ in commitIfEditing(immediate: true) }
            .onChange(of: duration) { _, _ in commitIfEditing(immediate: true) }
            .onChange(of: distraction) { _, _ in commitIfEditing(immediate: true) }
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

    private func makeResult() -> ItemFormResult {
        ItemFormResult(
            title: trimmedTitle,
            distance: distance,
            duration: duration,
            distraction: distraction,
            distanceCustomValue: distance == .custom ? distanceCustomValue.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            durationCustomValue: duration == .custom ? durationCustomValue.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            distractionCustomValue: distraction == .custom ? distractionCustomValue.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        )
    }

    private func scheduleDebouncedCommit() {
        guard isEditing, hasPopulated else { return }
        commitTask?.cancel()
        commitTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            commitIfEditing()
        }
    }

    private func commitIfEditing(immediate: Bool = false) {
        guard isEditing, hasPopulated else { return }
        if immediate { commitTask?.cancel() }
        // Don't commit invalid state: skip the call entirely, surface the
        // titleError view above. Once title becomes non-empty, the next
        // .onChange fires another commit cycle.
        guard canSave else { return }
        onCommit?(makeResult())
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
    TrainerPlanItemFormView(mode: .add, onSave: { _ in })
}

#Preview("Edit") {
    TrainerPlanItemFormView(
        mode: .edit(TrainingPlanItem(
            id: UUID(), planId: UUID(), behaviorId: nil, sortOrder: 0,
            title: "Sit at arm's length",
            distance: .armsLength, duration: .instant, distraction: .none,
            distanceCustomValue: nil, durationCustomValue: nil, distractionCustomValue: nil
        )),
        onCommit: { _ in }
    )
}
