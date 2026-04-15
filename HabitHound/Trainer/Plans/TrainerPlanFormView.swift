import SwiftUI

enum PlanFormMode {
    case create
    case edit(TrainingPlan)
}

struct TrainerPlanFormView: View {
    let mode: PlanFormMode
    /// Pets to show in the picker when a Guardian is creating a plan.
    /// Leave empty (default) to hide the pet section.
    var pets: [Pet] = []
    let onSave: (TrainingPlan, UUID?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var selectedPetId: UUID? = nil
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let service = TrainingPlanService()

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan Title") {
                    TextField("e.g. First Steps", text: $title)
                }
                Section("Plan Description") {
                    TextField("Optional overview of the plan (steps are added after)…", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                if !pets.isEmpty && !isEditing {
                    Section("Assign to Pet") {
                        Picker("Pet", selection: $selectedPetId) {
                            Text("None").tag(UUID?.none)
                            ForEach(pets) { pet in
                                Text(pet.name).tag(UUID?.some(pet.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Plan" : "New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                }
            }
            .disabled(isSaving)
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear { populateIfEditing() }
        }
    }

    private func populateIfEditing() {
        if case .edit(let plan) = mode {
            title = plan.title
            description = plan.description ?? ""
        }
    }

    private func save() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaving = true
        defer { isSaving = false }
        do {
            let saved: TrainingPlan
            if case .edit(var plan) = mode {
                plan.title = trimmedTitle
                plan.description = trimmedDesc.isEmpty ? nil : trimmedDesc
                saved = try await service.updatePlan(plan)
            } else {
                saved = try await service.createPlan(
                    title: trimmedTitle,
                    description: trimmedDesc.isEmpty ? nil : trimmedDesc
                )
            }
            onSave(saved, selectedPetId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Create") {
    TrainerPlanFormView(mode: .create) { _, _ in }
}

#Preview("Edit") {
    TrainerPlanFormView(mode: .edit(TrainingPlan(
        id: UUID(), trainerId: UUID(),
        title: "Basic Recall", description: "Foundation exercises",
        createdAt: Date(), updatedAt: Date()
    ))) { _, _ in }
}
