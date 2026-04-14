import SwiftUI

enum BehaviorFormMode {
    case add
    case edit(Behavior)
}

struct TrainerBehaviorFormView: View {
    let mode: BehaviorFormMode
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let suggestions = [
        "Sit", "Down", "Leave It", "Drop It", "Stand",
        "Wait/Stay", "Walk", "Touch", "Go to Mat", "Recall",
        "Off", "Attention"
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Name") {
                    TextField("e.g. Sit", text: $name)
                        .autocorrectionDisabled()
                }

                Section("Suggestions") {
                    ForEach(suggestions, id: \.self) { (suggestion: String) in
                        Button {
                            name = suggestion
                        } label: {
                            HStack {
                                Text(suggestion)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if name == suggestion {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                        .font(.caption.bold())
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Behavior" : "Add Behavior")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if case .edit(let behavior) = mode {
                    name = behavior.name
                }
            }
        }
    }
}

#Preview("Add") {
    TrainerBehaviorFormView(mode: .add) { _ in }
}

#Preview("Edit") {
    TrainerBehaviorFormView(
        mode: .edit(Behavior(
            id: UUID(), planId: UUID(),
            name: "Sit", sortOrder: 0, createdAt: Date()
        ))
    ) { _ in }
}
