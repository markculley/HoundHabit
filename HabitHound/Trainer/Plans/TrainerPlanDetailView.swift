import SwiftUI

struct TrainerPlanDetailView: View {
    let plan: TrainingPlan
    let viewModel: TrainerPlanViewModel

    @State private var showEditSheet = false
    @State private var showAddItemSheet = false
    @State private var showAssignSheet = false
    @State private var itemToEdit: TrainingPlanItem? = nil

    private var items: [TrainingPlanItem] {
        viewModel.items[plan.id] ?? []
    }

    var body: some View {
        List {
            // Plan type label + description
            Section {
                Label("Training Plan", systemImage: "list.bullet.clipboard")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let description = plan.description, !description.isEmpty {
                    Text(description)
                        .foregroundStyle(.secondary)
                }
            }

            // Steps
            Section {
                if items.isEmpty {
                    Text("No steps yet. Tap Add Step to begin.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(items) { item in
                        PlanItemRow(item: item)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteItem(item) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    itemToEdit = item
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                    .onMove { source, destination in
                        Task { await viewModel.moveItems(in: plan.id, from: source, to: destination) }
                    }
                }
            } header: {
                HStack {
                    Text("Steps")
                    Spacer()
                    Button("Add Step") { showAddItemSheet = true }
                        .font(.caption)
                }
            }

            // Assigned To
            Section("Assigned To") {
                let planAssignments = viewModel.assignments[plan.id] ?? []
                if planAssignments.isEmpty {
                    Text("Not assigned to anyone yet.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(planAssignments) { assignment in
                        HStack {
                            Text(viewModel.guardianName(for: assignment.guardianId))
                            Spacer()
                            Text(assignment.assignedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        let list = viewModel.assignments[plan.id] ?? []
                        Task {
                            for i in offsets {
                                await viewModel.deleteAssignment(list[i])
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(plan.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Assign") { showAssignSheet = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .task {
            async let items = viewModel.loadItems(for: plan.id)
            async let assignments = viewModel.loadAssignments(for: plan.id)
            _ = await (items, assignments)
        }
        .sheet(isPresented: $showEditSheet) {
            TrainerPlanFormView(mode: .edit(plan)) { updated in
                if let idx = viewModel.plans.firstIndex(where: { $0.id == updated.id }) {
                    viewModel.plans[idx] = updated
                }
            }
        }
        .sheet(isPresented: $showAddItemSheet) {
            TrainerPlanItemFormView(mode: .add) { title, distance, duration, distraction in
                Task { await viewModel.addItem(to: plan.id, title: title, distance: distance, duration: duration, distraction: distraction) }
            }
        }
        .sheet(item: $itemToEdit) { item in
            TrainerPlanItemFormView(mode: .edit(item)) { title, distance, duration, distraction in
                var updated = item
                updated.title       = title
                updated.distance    = distance
                updated.duration    = duration
                updated.distraction = distraction
                Task { await viewModel.updateItem(updated) }
            }
        }
        .sheet(isPresented: $showAssignSheet) {
            AssignPlanSheet(
                plan: plan,
                existingAssignments: viewModel.assignments[plan.id] ?? []
            ) {
                Task { await viewModel.loadAssignments(for: plan.id) }
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

// MARK: - Row

private struct PlanItemRow: View {
    let item: TrainingPlanItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(item.sortOrder + 1).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.title)
                        .font(.body)
                }
                HStack(spacing: 8) {
                    ThreeDTag(item.distance.label)
                    ThreeDTag(item.duration.label)
                    ThreeDTag(item.distraction.label)
                }
                .padding(.leading, 16)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ThreeDTag: View {
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
    NavigationStack {
        TrainerPlanDetailView(
            plan: TrainingPlan(
                id: UUID(), trainerId: UUID(),
                title: "Basic Recall", description: "Foundation recall exercises",
                createdAt: Date(), updatedAt: Date()
            ),
            viewModel: TrainerPlanViewModel()
        )
    }
}
