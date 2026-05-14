import SwiftUI

struct GuardianPlanDetailView: View {
    let assignedPlan: AssignedPlan
    let viewModel: GuardianPlanViewModel

    @State private var selectedPracticeItem: TrainingPlanItem? = nil
    @State private var isSharedWithTrainer: Bool

    init(assignedPlan: AssignedPlan, viewModel: GuardianPlanViewModel) {
        self.assignedPlan = assignedPlan
        self.viewModel = viewModel
        _isSharedWithTrainer = State(initialValue: assignedPlan.assignment.isShared)
    }

    /// True when the plan was assigned by a different user (a real trainer).
    private var isTrainerAssigned: Bool {
        assignedPlan.assignment.trainerId != assignedPlan.assignment.guardianId
    }

    private var planId: UUID { assignedPlan.plan.id }

    private var allItems: [TrainingPlanItem] {
        (viewModel.items[planId] ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var behaviors: [Behavior] {
        (viewModel.behaviors[planId] ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Items belonging to a specific behavior, in order.
    private func items(for behavior: Behavior) -> [TrainingPlanItem] {
        allItems.filter { $0.behaviorId == behavior.id }
    }

    /// Items with no behavior assignment (legacy data).
    private var unboundItems: [TrainingPlanItem] {
        allItems.filter { $0.behaviorId == nil }
    }

    var body: some View {
        List {
            // Plan header
            Section {
                Label("Training Plan", systemImage: "list.bullet.clipboard")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let description = assignedPlan.plan.description, !description.isEmpty {
                    LabeledContent("Description", value: description)
                }
                Text("Assigned \(assignedPlan.assignment.assignedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if isTrainerAssigned {
                    Toggle("Share sessions with trainer", isOn: $isSharedWithTrainer)
                        .onChange(of: isSharedWithTrainer) { _, newValue in
                            Task { await viewModel.updateSharing(for: assignedPlan, isShared: newValue) }
                        }
                }
            }

            if viewModel.items[planId] == nil {
                // Still loading
                Section {
                    ProgressView()
                }
            } else if allItems.isEmpty {
                Section {
                    Text("No steps have been added to this plan yet.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            } else if behaviors.isEmpty {
                // No behaviors yet — show flat steps list (legacy / pre-behavior plans)
                Section("Steps") {
                    stepRows(for: allItems)
                }
            } else {
                Section("Behaviors") {
                    ForEach(behaviors) { behavior in
                        let behaviorItems = items(for: behavior)
                        if !behaviorItems.isEmpty {
                            Text(behavior.type.label)
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                            stepRows(for: behaviorItems)
                        }
                    }
                    if !unboundItems.isEmpty {
                        Text("Other Steps")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        stepRows(for: unboundItems)
                    }
                }
            }
        }
        .navigationTitle(assignedPlan.plan.title)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadItems(for: planId)
            await viewModel.loadRecords()
        }
        // Every step is reachable — tapping one opens the consistent training
        // session view. TrainingSessionView is self-contained: it logs the
        // record and refreshes completion on its own.
        .sheet(item: $selectedPracticeItem) { item in
            TrainingSessionView(
                planItemId: item.id,
                assignedPlan: assignedPlan,
                isShared: isSharedWithTrainer,
                viewModel: viewModel
            )
        }
    }

    // MARK: - Step rows (shared between flat and grouped layouts)

    @ViewBuilder
    private func stepRows(for stepItems: [TrainingPlanItem]) -> some View {
        ForEach(stepItems) { item in
            let completion = viewModel.stepCompletion(planItemId: item.id)
            let locked = viewModel.isStepLocked(item)
            Button {
                if !locked { selectedPracticeItem = item }
            } label: {
                StepRow(
                    item: item,
                    isComplete: completion.isComplete,
                    bestStreak: completion.bestStreak,
                    isLocked: locked
                )
            }
            .buttonStyle(.plain)
            .disabled(locked)
        }
    }
}

// MARK: - StepRow

private struct StepRow: View {
    let item: TrainingPlanItem
    let isComplete: Bool
    /// Longest historical run of consecutive calendar days with a score-5
    /// session — 0...2 while incomplete (3+ means complete).
    let bestStreak: Int
    /// Locked until the previous step in the same behavior is complete.
    let isLocked: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isComplete ? Color.green : Color.secondary.opacity(0.15))
                    .frame(width: 28, height: 28)
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                } else {
                    Text("\(item.sortOrder + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body)
                HStack(spacing: 6) {
                    StepTag(item.distanceLabel)
                    StepTag(item.durationLabel)
                    StepTag(item.distractionLabel)
                }
                if isLocked {
                    Text("Complete the previous step first")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if !isComplete && bestStreak > 0 {
                    Text("\(bestStreak) / 3 days")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(isComplete ? .green : .secondary)
            }
        }
        .padding(.vertical, 2)
        .opacity(isLocked ? 0.55 : 1)
    }
}

// MARK: - StepTag

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
        guardianId: UUID(), petId: nil, assignedAt: Date(), currentItemId: nil, isShared: true
    )
    NavigationStack {
        GuardianPlanDetailView(
            assignedPlan: AssignedPlan(assignment: assignment, plan: plan),
            viewModel: GuardianPlanViewModel()
        )
    }
}
