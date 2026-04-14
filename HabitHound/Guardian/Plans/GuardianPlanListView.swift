import SwiftUI

struct GuardianPlanListView: View {
    @State private var viewModel = GuardianPlanViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.assignedPlans.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.assignedPlans.isEmpty {
                ContentUnavailableView(
                    "No Plans Yet",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Your trainer will assign plans here.")
                )
            } else {
                List {
                    ForEach(viewModel.assignedPlans) { assignedPlan in
                        NavigationLink(value: assignedPlan) {
                            AssignedPlanRow(
                                assignedPlan: assignedPlan,
                                progress: viewModel.planProgress(for: assignedPlan)
                            )
                        }
                    }
                }
                .refreshable { await viewModel.load() }
                .navigationDestination(for: AssignedPlan.self) { assignedPlan in
                    GuardianPlanDetailView(assignedPlan: assignedPlan, viewModel: viewModel)
                }
            }
        }
        .navigationTitle("Plans")
        .task { await viewModel.load() }
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

private struct PlanProgressBadge: View {
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
