import SwiftUI

struct TrainerBehaviorDetailView: View {
    let behavior: Behavior
    let viewModel: TrainerPlanViewModel

    @State private var showAddItemSheet = false
    @State private var itemToEdit: TrainingPlanItem? = nil

    private var items: [TrainingPlanItem] {
        (viewModel.items[behavior.planId] ?? [])
            .filter { $0.behaviorId == behavior.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        List {
            Section {
                if !items.isEmpty {
                    ForEach(items) { item in
                        Button {
                            itemToEdit = item
                        } label: {
                            BehaviorItemRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteItem(item) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { source, destination in
                        Task { await viewModel.moveItems(in: behavior.planId, behaviorId: behavior.id, from: source, to: destination) }
                    }
                }
                // Inline add row — replaces the toolbar Add Step button.
                Button {
                    showAddItemSheet = true
                } label: {
                    Label("Add Step", systemImage: "plus.circle")
                        .foregroundStyle(.tint)
                }
            } header: {
                Text("Steps")
            } footer: {
                if items.isEmpty {
                    Text("No steps yet. Tap + Add Step above to begin.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(behavior.type.label)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadItems(for: behavior)
        }
        .sheet(isPresented: $showAddItemSheet) {
            TrainerPlanItemFormView(
                mode: .add,
                onSave: { result in
                    Task {
                        await viewModel.addItem(
                            to: behavior.planId,
                            behaviorId: behavior.id,
                            title: result.title,
                            distance: result.distance,
                            duration: result.duration,
                            distraction: result.distraction,
                            distanceCustomValue: result.distanceCustomValue,
                            durationCustomValue: result.durationCustomValue,
                            distractionCustomValue: result.distractionCustomValue
                        )
                    }
                }
            )
        }
        .sheet(item: $itemToEdit) { item in
            TrainerPlanItemFormView(
                mode: .edit(item),
                onCommit: { result in
                    var updated = item
                    updated.title                 = result.title
                    updated.distance              = result.distance
                    updated.duration              = result.duration
                    updated.distraction           = result.distraction
                    updated.distanceCustomValue   = result.distanceCustomValue
                    updated.durationCustomValue   = result.durationCustomValue
                    updated.distractionCustomValue = result.distractionCustomValue
                    Task { await viewModel.updateItem(updated) }
                }
            )
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

private struct BehaviorItemRow: View {
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
                    ThreeDTag(item.distanceLabel)
                    ThreeDTag(item.durationLabel)
                    ThreeDTag(item.distractionLabel)
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
        TrainerBehaviorDetailView(
            behavior: Behavior(
                id: UUID(), planId: UUID(),
                type: .standard(.sit), sortOrder: 0, createdAt: Date()
            ),
            viewModel: TrainerPlanViewModel()
        )
    }
}
