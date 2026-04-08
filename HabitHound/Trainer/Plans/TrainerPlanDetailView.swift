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
            TrainerPlanItemFormView(mode: .add) { title, description in
                Task { await viewModel.addItem(to: plan.id, title: title, description: description) }
            }
        }
        .sheet(item: $itemToEdit) { item in
            TrainerPlanItemFormView(mode: .edit(item)) { title, description in
                var updated = item
                updated.title = title
                updated.description = description
                Task { await viewModel.updateItem(updated) }
            }
        }
        .sheet(isPresented: $showAssignSheet) {
            AssignPlanSheet(plan: plan) {
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
        }
        .padding(.vertical, 2)
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
