import SwiftUI

struct GuardianPlanListView: View {
    @State private var viewModel = GuardianPlanViewModel()
    @State private var petViewModel = PetViewModel()

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
                    ForEach(viewModel.assignedPlans) { assignedPlan in
                        NavigationLink(value: assignedPlan) {
                            AssignedPlanRow(
                                assignedPlan: assignedPlan,
                                progress: viewModel.planProgress(for: assignedPlan),
                                pet: pet(for: assignedPlan)
                            )
                        }
                    }
                }
                .overlay {
                    if viewModel.assignedPlans.isEmpty {
                        ContentUnavailableView(
                            "No Plans Yet",
                            systemImage: "list.bullet.clipboard",
                            description: Text("Ask your trainer to assign a training plan.")
                        )
                    }
                }
                .refreshable { await viewModel.load() }
                .navigationDestination(for: AssignedPlan.self) { assignedPlan in
                    GuardianPlanDetailView(assignedPlan: assignedPlan, viewModel: viewModel)
                }
            }
        }
        .navigationTitle("Plans")
        .task {
            await viewModel.load()
            await petViewModel.loadPets()
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
