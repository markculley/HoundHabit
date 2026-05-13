import SwiftUI

/// Shown after a guardian copies one of their own plans. Lets them pick a
/// pet (or "None") and creates the matching `plan_assignments` row so the
/// new plan appears in their assigned-plans list. Cancel is handled by the
/// parent view (which deletes the copy); this sheet only fires `onComplete`
/// when the user explicitly confirms.
struct CopyPlanPetPickerSheet: View {
    let plan: TrainingPlan
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pets: [Pet] = []
    @State private var selectedPet: Pet? = nil
    @State private var isLoading = true
    @State private var isAssigning = false
    @State private var errorMessage: String?

    private let petService = PetService()
    private let planService = TrainingPlanService()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Pick a pet for this plan, or choose \"None\" to keep it unlinked. Tap Cancel to discard the copy.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Pet (Optional)") {
                    if isLoading {
                        ProgressView()
                    } else if pets.isEmpty {
                        Text("No pets yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Select Pet", selection: $selectedPet) {
                            Text("None").tag(Optional<Pet>.none)
                            ForEach(pets) { pet in
                                Text(pet.name).tag(Optional(pet))
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
            }
            .navigationTitle("Assign \"\(plan.title)\"")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Cancel does not call onComplete. The parent view treats a
                    // non-confirmed dismissal as "throw away the copy."
                    Button("Cancel") { dismiss() }
                        .disabled(isAssigning)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isAssigning)
                }
            }
            .task {
                guard let userId = supabase.auth.currentUser?.id else {
                    isLoading = false
                    return
                }
                pets = (try? await petService.fetchPets(guardianId: userId)) ?? []
                isLoading = false
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() async {
        isAssigning = true
        defer { isAssigning = false }
        do {
            _ = try await planService.selfAssignPlan(planId: plan.id, petId: selectedPet?.id)
            onComplete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    CopyPlanPetPickerSheet(
        plan: TrainingPlan(
            id: UUID(), trainerId: UUID(),
            title: "Recall Basics (Copy)", description: nil,
            createdAt: Date(), updatedAt: Date()
        ),
        onComplete: {}
    )
}
