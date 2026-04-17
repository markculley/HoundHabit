import SwiftUI

struct TrainerPlanDetailView: View {
    let plan: TrainingPlan
    let viewModel: TrainerPlanViewModel
    var showAssignments: Bool = true

    @State private var showEditSheet = false
    @State private var showAddBehaviorSheet = false
    @State private var showAssignSheet = false

    private var behaviors: [Behavior] {
        viewModel.behaviors[plan.id] ?? []
    }

    private var assignments: [PlanAssignment] {
        viewModel.assignments[plan.id] ?? []
    }

    /// Nil means ready; non-nil is the reason the plan can't be assigned yet.
    private var assignBlockReason: String? {
        if behaviors.isEmpty {
            return "Add at least one behavior before assigning."
        }
        let allItems = viewModel.items[plan.id] ?? []
        let emptyBehaviors = behaviors.filter { b in !allItems.contains { $0.behaviorId == b.id } }
        if emptyBehaviors.count == 1 {
            return "\"\(emptyBehaviors[0].name)\" has no steps. Each behavior needs at least one step."
        } else if emptyBehaviors.count > 1 {
            return "\(emptyBehaviors.count) behaviors have no steps. Each behavior needs at least one step."
        }
        return nil
    }

    var body: some View {
        List {
            // Plan header — description + assignment
            Section {
                Label("Training Plan", systemImage: "list.bullet.clipboard")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let description = plan.description, !description.isEmpty {
                    Text(description)
                        .foregroundStyle(.secondary)
                }

                if showAssignments {
                    if !assignments.isEmpty {
                        ForEach(assignments) { assignment in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    LabeledContent("Guardian") {
                                        Text(viewModel.guardianName(for: assignment.guardianId))
                                    }
                                    LabeledContent("Pet") {
                                        Text(viewModel.petName(for: assignment.petId))
                                    }
                                }
                                Spacer()
                                PlanProgressBadge(progress: viewModel.planProgress(for: assignment))
                                    .padding(.top, 2)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteAssignment(assignment) }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                    if let reason = assignBlockReason {
                        Label(reason, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Assign to Guardian…") { showAssignSheet = true }
                    }
                }
            }

            // Behaviors list
            Section {
                if behaviors.isEmpty {
                    Text("No behaviors yet. Tap Add Behavior to begin.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(behaviors) { behavior in
                        NavigationLink(value: behavior) {
                            BehaviorRow(
                                behavior: behavior,
                                stepCount: (viewModel.items[plan.id] ?? [])
                                    .filter { $0.behaviorId == behavior.id }.count
                            )
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteBehavior(behavior) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { source, destination in
                        Task { await viewModel.moveBehaviors(in: plan.id, from: source, to: destination) }
                    }
                }
            } header: {
                Text("Behaviors")
            }
        }
        .navigationTitle(plan.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Behavior") { showAddBehaviorSheet = true }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit Plan", systemImage: "pencil")
                }
            }
        }
        .navigationDestination(for: Behavior.self) { behavior in
            TrainerBehaviorDetailView(behavior: behavior, viewModel: viewModel)
        }
        .task {
            async let b = viewModel.loadBehaviors(for: plan.id)
            async let a = viewModel.loadAssignments(for: plan.id)
            async let i = viewModel.loadItems(for: plan.id)
            _ = await (b, a, i)
        }
        .sheet(isPresented: $showEditSheet) {
            TrainerPlanFormView(mode: .edit(plan)) { updated, _ in
                if let idx = viewModel.plans.firstIndex(where: { $0.id == updated.id }) {
                    viewModel.plans[idx] = updated
                }
            }
        }
        .sheet(isPresented: $showAddBehaviorSheet) {
            TrainerBehaviorFormView(mode: .add) { name in
                Task { await viewModel.addBehavior(to: plan.id, name: name) }
            }
        }
        .sheet(isPresented: $showAssignSheet) {
            AssignPlanSheet(
                plan: plan,
                existingAssignments: assignments
            ) {
                Task { await viewModel.loadAssignments(for: plan.id) }
            }
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

// MARK: - BehaviorRow

private struct BehaviorRow: View {
    let behavior: Behavior
    let stepCount: Int

    var body: some View {
        HStack {
            Text(behavior.name)
                .font(.body)
            Spacer()
            Text(stepCount == 1 ? "1 step" : "\(stepCount) steps")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        TrainerPlanDetailView(
            plan: TrainingPlan(
                id: UUID(), trainerId: UUID(),
                title: "Basic Recall", description: "Foundation recall exercises",
                createdAt: Date(), updatedAt: Date()
            ),
            viewModel: TrainerPlanViewModel()
        )
    }
}
