import SwiftUI

enum ItemFormMode {
    case add
    case edit(TrainingPlanItem)
}

struct TrainerPlanItemFormView: View {
    let mode: ItemFormMode
    let onSave: (String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""

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
                Section("Step Title") {
                    TextField("e.g. Sit at arm's length", text: $title)
                }
                Section("Instructions") {
                    TextField("Optional details…", text: $description, axis: .vertical)
                        .lineLimit(3...6)
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
                        let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(trimmedTitle, trimmedDesc.isEmpty ? nil : trimmedDesc)
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
            title = item.title
            description = item.description ?? ""
        }
    }
}

#Preview("Add") {
    TrainerPlanItemFormView(mode: .add) { _, _ in }
}

#Preview("Edit") {
    TrainerPlanItemFormView(mode: .edit(TrainingPlanItem(
        id: UUID(), planId: UUID(), sortOrder: 0,
        title: "Sit at arm's length", description: "Use a hand signal"
    ))) { _, _ in }
}
