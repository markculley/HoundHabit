import SwiftUI

struct GuardianPlanDetailView: View {
    let assignedPlan: AssignedPlan
    let viewModel: GuardianPlanViewModel

    private var items: [TrainingPlanItem] {
        viewModel.items[assignedPlan.plan.id] ?? []
    }

    var body: some View {
        List {
            // Plan type label + description
            Section {
                Label("Training Plan", systemImage: "list.bullet.clipboard")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let description = assignedPlan.plan.description, !description.isEmpty {
                    Text(description)
                        .foregroundStyle(.secondary)
                }
                Text("Assigned \(assignedPlan.assignment.assignedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Steps
            Section("Steps") {
                if items.isEmpty {
                    ProgressView()
                } else {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("\(item.sortOrder + 1).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(item.title)
                                    .font(.body)
                            }
                            if let description = item.description, !description.isEmpty {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 16)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(assignedPlan.plan.title)
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.loadItems(for: assignedPlan.plan.id) }
    }
}

#Preview {
    let plan = TrainingPlan(
        id: UUID(), trainerId: UUID(),
        title: "Basic Recall", description: "Foundation recall exercises",
        createdAt: Date(), updatedAt: Date()
    )
    let assignment = PlanAssignment(
        id: UUID(), planId: plan.id, trainerId: UUID(),
        guardianId: UUID(), petId: nil, assignedAt: Date()
    )
    NavigationStack {
        GuardianPlanDetailView(
            assignedPlan: AssignedPlan(assignment: assignment, plan: plan),
            viewModel: GuardianPlanViewModel()
        )
    }
}
