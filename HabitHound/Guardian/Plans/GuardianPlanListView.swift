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
                            AssignedPlanRow(assignedPlan: assignedPlan)
                        }
                    }
                }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
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
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        GuardianPlanListView()
    }
}
