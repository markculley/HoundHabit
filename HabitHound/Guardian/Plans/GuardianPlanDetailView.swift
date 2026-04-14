import SwiftUI

struct GuardianPlanDetailView: View {
    let assignedPlan: AssignedPlan
    let viewModel: GuardianPlanViewModel

    @State private var showPracticeSheet = false
    @State private var showAdvancementAlert = false

    private var items: [TrainingPlanItem] {
        (viewModel.items[assignedPlan.plan.id] ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var currentItem: TrainingPlanItem? {
        viewModel.currentItem(for: assignedPlan, in: items)
    }

    var body: some View {
        List {
            // Plan header
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
                        let isCurrent = item.id == currentItem?.id
                        StepRow(item: item, isCurrent: isCurrent)
                    }
                }
            }

            // Practice current step
            if let current = currentItem {
                Section {
                    Button {
                        showPracticeSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Practice Step \(current.sortOrder + 1)")
                                    .font(.headline)
                                Text(current.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(assignedPlan.plan.title)
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.loadItems(for: assignedPlan.plan.id) }
        .sheet(isPresented: $showPracticeSheet) {
            if let current = currentItem {
                TrainingRecordFormView(
                    preselectedPetId: assignedPlan.assignment.petId,
                    planItem: current
                ) { savedRecord in
                    Task {
                        await viewModel.advanceCurrentStep(
                            assignedPlan: assignedPlan,
                            score: savedRecord.score,
                            planItems: items
                        )
                        showAdvancementAlert = true
                    }
                }
            }
        }
        .alert("Session Logged", isPresented: $showAdvancementAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.lastAdvancementMessage ?? "")
        }
    }
}

// MARK: - StepRow

private struct StepRow: View {
    let item: TrainingPlanItem
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isCurrent ? Color.green : Color.secondary.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text("\(item.sortOrder + 1)")
                    .font(.caption.bold())
                    .foregroundStyle(isCurrent ? .white : .secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body)
                    .foregroundStyle(isCurrent ? .primary : .secondary)
                HStack(spacing: 6) {
                    StepTag(item.distance.label)
                    StepTag(item.duration.label)
                    StepTag(item.distraction.label)
                }
            }
            if isCurrent {
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.green.opacity(0.7))
            }
        }
        .padding(.vertical, 2)
    }
}

private struct StepTag: View {
    let label: String
    init(_ label: String) { self.label = label }
    var body: some View {
        Text(label)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.12), in: Capsule())
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
        guardianId: UUID(), petId: nil, assignedAt: Date(), currentItemId: nil
    )
    NavigationStack {
        GuardianPlanDetailView(
            assignedPlan: AssignedPlan(assignment: assignment, plan: plan),
            viewModel: GuardianPlanViewModel()
        )
    }
}
