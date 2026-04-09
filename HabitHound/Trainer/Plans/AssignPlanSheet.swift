import SwiftUI

struct AssignPlanSheet: View {
    let plan: TrainingPlan
    let existingAssignments: [PlanAssignment]
    let onAssign: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AssignSheetViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Guardian") {
                    if viewModel.guardians.isEmpty {
                        Text("No linked guardians yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Select Guardian", selection: $viewModel.selectedGuardian) {
                            Text("Select…").tag(Optional<LinkedGuardian>.none)
                            ForEach(viewModel.guardians) { guardian in
                                Text(guardian.profile.fullName ?? "Guardian")
                                    .tag(Optional(guardian))
                            }
                        }
                        .onChange(of: viewModel.selectedGuardian) { _, guardian in
                            Task {
                                if let guardian {
                                    await viewModel.loadPets(for: guardian.guardianId)
                                } else {
                                    viewModel.pets = []
                                    viewModel.selectedPet = nil
                                }
                            }
                        }
                    }
                }

                if !viewModel.pets.isEmpty {
                    Section("Pet (Optional)") {
                        Picker("Select Pet", selection: $viewModel.selectedPet) {
                            Text("Any pet").tag(Optional<Pet>.none)
                            ForEach(viewModel.pets) { pet in
                                Text(pet.name).tag(Optional(pet))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Assign Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Assign") {
                        Task {
                            await viewModel.assign(plan: plan)
                            if viewModel.errorMessage == nil {
                                onAssign()
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.selectedGuardian == nil || viewModel.isAssigning)
                }
            }
            .task { await viewModel.loadGuardians(excluding: existingAssignments.map(\.guardianId)) }
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

// MARK: - ViewModel (collocated — only used here)

@Observable
private class AssignSheetViewModel {
    var guardians: [LinkedGuardian] = []
    var pets: [Pet] = []
    var selectedGuardian: LinkedGuardian? = nil
    var selectedPet: Pet? = nil
    var isAssigning = false
    var errorMessage: String?

    private let inviteService = InviteService()
    private let petService = PetService()
    private let planService = TrainingPlanService()

    func loadGuardians(excluding assignedGuardianIds: [UUID]) async {
        do {
            let all = try await inviteService.fetchLinkedGuardians()
            guardians = all.filter { !assignedGuardianIds.contains($0.guardianId) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadPets(for guardianId: UUID) async {
        selectedPet = nil
        do {
            pets = try await petService.fetchPets(guardianId: guardianId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func assign(plan: TrainingPlan) async {
        guard let guardian = selectedGuardian else { return }
        isAssigning = true
        defer { isAssigning = false }
        do {
            _ = try await planService.assignPlan(
                planId: plan.id,
                guardianId: guardian.guardianId,
                petId: selectedPet?.id
            )
        } catch {
            // Surface duplicate assignment as a friendlier message
            let msg = error.localizedDescription
            if msg.contains("duplicate") || msg.contains("unique") {
                errorMessage = "This guardian is already assigned to this plan."
            } else {
                errorMessage = msg
            }
        }
    }
}

#Preview {
    AssignPlanSheet(
        plan: TrainingPlan(
            id: UUID(), trainerId: UUID(),
            title: "Basic Recall", description: nil,
            createdAt: Date(), updatedAt: Date()
        ),
        existingAssignments: [],
        onAssign: {}
    )
}
