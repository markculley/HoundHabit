import SwiftUI

struct GuardianPlanDetailView: View {
    let assignedPlan: AssignedPlan
    let viewModel: GuardianPlanViewModel

    @State private var selectedPracticeItem: TrainingPlanItem? = nil
    @State private var selectedInfoItem: TrainingPlanItem? = nil
    @State private var showAdvancementAlert = false

    private var planId: UUID { assignedPlan.plan.id }

    private var allItems: [TrainingPlanItem] {
        (viewModel.items[planId] ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var behaviors: [Behavior] {
        (viewModel.behaviors[planId] ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var currentItem: TrainingPlanItem? {
        viewModel.currentItem(for: assignedPlan, in: allItems)
    }

    /// Items belonging to a specific behavior, in order.
    private func items(for behavior: Behavior) -> [TrainingPlanItem] {
        allItems.filter { $0.behaviorId == behavior.id }
    }

    /// Items with no behavior assignment (legacy data).
    private var unboundItems: [TrainingPlanItem] {
        allItems.filter { $0.behaviorId == nil }
    }

    /// Items in true plan order: behaviors by their sortOrder, then items within
    /// each behavior by their sortOrder. This is the sequence the guardian progresses through.
    private var orderedItems: [TrainingPlanItem] {
        var result: [TrainingPlanItem] = []
        for behavior in behaviors {
            result.append(contentsOf: items(for: behavior))
        }
        result.append(contentsOf: unboundItems)
        return result
    }

    /// Whether a step is ahead of the guardian's current position (not yet reachable).
    private func isLocked(_ item: TrainingPlanItem) -> Bool {
        let currentIdx = orderedItems.firstIndex(where: { $0.id == currentItem?.id }) ?? 0
        let itemIdx    = orderedItems.firstIndex(where: { $0.id == item.id }) ?? 0
        return itemIdx > currentIdx
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
                // Behaviors as sections
                ForEach(behaviors) { behavior in
                    let behaviorItems = items(for: behavior)
                    if !behaviorItems.isEmpty {
                        Section(behavior.name) {
                            stepRows(for: behaviorItems)
                        }
                    }
                }
                // Unbound items fallback
                if !unboundItems.isEmpty {
                    Section("Other Steps") {
                        stepRows(for: unboundItems)
                    }
                }
            }
        }
        .navigationTitle(assignedPlan.plan.title)
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.loadItems(for: planId) }
        // Practice sheet — any reachable step
        .sheet(item: $selectedPracticeItem) { item in
            let behaviorName = behaviors.first { $0.id == item.behaviorId }?.name
            let isCurrentStep = item.id == currentItem?.id
            TrainingRecordFormView(
                lockedPetId: assignedPlan.assignment.petId,
                planItem: item,
                behaviorName: behaviorName
            ) { savedRecord in
                // Only advance/regress position when practicing the current step
                if isCurrentStep {
                    Task {
                        await viewModel.advanceCurrentStep(
                            assignedPlan: assignedPlan,
                            score: savedRecord.score,
                            planItems: allItems
                        )
                        showAdvancementAlert = true
                    }
                }
            }
        }
        // Info sheet — non-current steps
        .sheet(item: $selectedInfoItem) { item in
            let behaviorName = behaviors.first { $0.id == item.behaviorId }?.name
            StepInfoSheet(item: item, behaviorName: behaviorName)
        }
        .alert("Session Logged", isPresented: $showAdvancementAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.lastAdvancementMessage ?? "")
        }
    }

    // MARK: - Step rows (shared between flat and grouped layouts)

    @ViewBuilder
    private func stepRows(for stepItems: [TrainingPlanItem]) -> some View {
        ForEach(stepItems) { item in
            let isCurrent = item.id == currentItem?.id
            let locked = isLocked(item)
            Button {
                if locked {
                    selectedInfoItem = item
                } else {
                    selectedPracticeItem = item
                }
            } label: {
                StepRow(item: item, isCurrent: isCurrent, isLocked: locked)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - StepRow

private struct StepRow: View {
    let item: TrainingPlanItem
    let isCurrent: Bool
    let isLocked: Bool

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
                    .foregroundStyle(isLocked ? .secondary : .primary)
                HStack(spacing: 6) {
                    StepTag(item.distanceLabel)
                    StepTag(item.durationLabel)
                    StepTag(item.distractionLabel)
                }
            }
            Spacer()
            if isLocked {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary.opacity(0.5))
            } else {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(isCurrent ? .green : .secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - StepInfoSheet

private struct StepInfoSheet: View {
    let item: TrainingPlanItem
    let behaviorName: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let behaviorName {
                    Section {
                        LabeledContent("Behavior", value: behaviorName)
                    }
                }

                Section {
                    LabeledContent("Distance",    value: item.distanceLabel)
                    LabeledContent("Duration",    value: item.durationLabel)
                    LabeledContent("Distraction", value: item.distractionLabel)
                } header: {
                    Text("Three D's")
                }

                Section {
                    Text("This isn't your current step yet. Complete your current step to progress here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Step \(item.sortOrder + 1): \(item.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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
        guardianId: UUID(), petId: nil, assignedAt: Date(), currentItemId: nil
    )
    NavigationStack {
        GuardianPlanDetailView(
            assignedPlan: AssignedPlan(assignment: assignment, plan: plan),
            viewModel: GuardianPlanViewModel()
        )
    }
}
