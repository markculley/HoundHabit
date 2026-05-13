import SwiftUI

struct GuardianPlanListView: View {
    @State private var viewModel = GuardianPlanViewModel()
    @State private var petViewModel = PetViewModel()
    @State private var showCreateSheet = false

    private var ownPlans: [AssignedPlan] {
        viewModel.assignedPlans.filter { viewModel.isOwnPlan($0) }
    }

    private var trainerPlans: [AssignedPlan] {
        viewModel.assignedPlans.filter { !viewModel.isOwnPlan($0) }
    }

    private func pet(for assignedPlan: AssignedPlan) -> Pet? {
        guard let petId = assignedPlan.assignment.petId else { return nil }
        return petViewModel.pets.first(where: { $0.id == petId })
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.assignedPlans.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !ownPlans.isEmpty {
                        Section("My Plans") {
                            ForEach(ownPlans) { assignedPlan in
                                NavigationLink(value: assignedPlan.plan) {
                                    AssignedPlanRow(
                                        assignedPlan: assignedPlan,
                                        progress: viewModel.planProgress(for: assignedPlan),
                                        pet: pet(for: assignedPlan)
                                    )
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteOwnPlan(assignedPlan.plan) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    if !trainerPlans.isEmpty {
                        Section("From My Trainer") {
                            ForEach(trainerPlans) { assignedPlan in
                                NavigationLink(value: assignedPlan) {
                                    AssignedPlanRow(
                                        assignedPlan: assignedPlan,
                                        progress: viewModel.planProgress(for: assignedPlan),
                                        pet: pet(for: assignedPlan)
                                    )
                                }
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
    let pet: Pet?

    private var captionLine: String {
        let date = assignedPlan.assignment.assignedAt.formatted(date: .abbreviated, time: .omitted)
        if let name = pet?.name, !name.isEmpty {
            return "Assigned \(date) • \(name)"
        }
        return "Assigned \(date)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            PetAvatarView(url: pet?.photoUrl, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(assignedPlan.plan.title)
                    .font(.headline)
                if let description = assignedPlan.plan.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(captionLine)
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
