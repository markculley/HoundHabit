import SwiftUI

struct TrainerPlanListView: View {
    @State private var viewModel = TrainerPlanViewModel()
    @State private var showCreateSheet = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.plans.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.plans.isEmpty {
                ContentUnavailableView(
                    "No Plans Yet",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Tap + to create your first training plan.")
                )
            } else {
                List {
                    ForEach(viewModel.plans) { plan in
                        NavigationLink(value: plan) {
                            PlanRow(plan: plan)
                        }
                    }
                    .onDelete { offsets in
                        Task {
                            for i in offsets {
                                await viewModel.deletePlan(viewModel.plans[i])
                            }
                        }
                    }
                }
                .navigationDestination(for: TrainingPlan.self) { plan in
                    TrainerPlanDetailView(plan: plan, viewModel: viewModel)
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
        .sheet(isPresented: $showCreateSheet) {
            TrainerPlanFormView(mode: .create) { plan, _ in
                viewModel.plans.insert(plan, at: 0)
            }
        }
        .task { await viewModel.loadPlans() }
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

private struct PlanRow: View {
    let plan: TrainingPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(plan.title)
                .font(.headline)
            if let description = plan.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        TrainerPlanListView()
    }
}
