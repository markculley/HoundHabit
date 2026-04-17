import SwiftUI

struct GuardianPlanListView: View {
    @State private var viewModel = GuardianPlanViewModel()
    @State private var petViewModel = PetViewModel()
    @State private var showCreateSheet = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.assignedPlans.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.assignedPlans) { assignedPlan in
                        let isOwn = viewModel.isOwnPlan(assignedPlan)
                        if isOwn {
                            NavigationLink(value: assignedPlan.plan) {
                                AssignedPlanRow(
                                    assignedPlan: assignedPlan,
                                    progress: viewModel.planProgress(for: assignedPlan)
                                )
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteOwnPlan(assignedPlan.plan) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        } else {
                            NavigationLink(value: assignedPlan) {
                                AssignedPlanRow(
                                    assignedPlan: assignedPlan,
                                    progress: viewModel.planProgress(for: assignedPlan)
                                )
                            }
                        }
                    }
                }
                .overlay {
                    if viewModel.assignedPlans.isEmpty {
                        ContentUnavailableView(
                            "No Plans Yet",
                            systemImage: "list.bullet.clipboard",
                            description: Text("Tap + to create your own plan, or ask your trainer to assign one.")
                        )
                    }
                }
                .refreshable { await viewModel.load() }
                .navigationDestination(for: AssignedPlan.self) { assignedPlan in
                    GuardianPlanDetailView(assignedPlan: assignedPlan, viewModel: viewModel)
                }
                .navigationDestination(for: TrainingPlan.self) { plan in
                    OwnedPlanDetailView(plan: plan)
                }
            }
        }
        .navigationTitle("Plans")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreateSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await viewModel.load()
            await petViewModel.loadPets()
        }
        .sheet(isPresented: $showCreateSheet) {
            TrainerPlanFormView(mode: .create, pets: petViewModel.pets) { saved, petId in
                Task { await viewModel.adoptCreatedPlan(saved, petId: petId) }
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

// MARK: - OwnedPlanDetailView wrapper

/// Hosts a TrainerPlanDetailView with its own ViewModel so the guardian can
/// build out a plan they created themselves.
struct OwnedPlanDetailView: View {
    let plan: TrainingPlan
    @State private var trainerVM = TrainerPlanViewModel()

    var body: some View {
        TrainerPlanDetailView(plan: plan, viewModel: trainerVM, showAssignments: false)
    }
}

// MARK: - Row

private struct AssignedPlanRow: View {
    let assignedPlan: AssignedPlan
    let progress: PlanProgress

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(assignedPlan.plan.title)
                    .font(.headline)
                if let description = assignedPlan.plan.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text("Assigned \(assignedPlan.assignment.assignedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            PlanProgressBadge(progress: progress)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Badge

struct PlanProgressBadge: View {
    let progress: PlanProgress

    var body: some View {
        Text(progress.label)
            .font(.caption2.weight(.medium))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor, in: Capsule())
    }

    private var foregroundColor: Color {
        switch progress {
        case .todo:       return .secondary
        case .inProgress: return .orange
        case .done:       return .green
        }
    }

    private var backgroundColor: Color {
        switch progress {
        case .todo:       return Color(.systemGray5)
        case .inProgress: return .orange.opacity(0.15)
        case .done:       return .green.opacity(0.15)
        }
    }
}


#Preview {
    NavigationStack {
        GuardianPlanListView()
    }
}
