import SwiftUI

@Observable
class ResourceViewModel {
    var resources: [Resource] = []
    var selectedKind: ResourceKind? = nil
    var isLoading = false
    var errorMessage: String?

    private let service = ResourceService()

    var filteredResources: [Resource] {
        guard let kind = selectedKind else { return resources }
        return resources.filter { $0.kind == kind }
    }

    func load() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            resources = try await service.fetchResources(guardianId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ resource: Resource) async {
        do {
            try await service.deleteResource(id: resource.id)
            resources.removeAll { $0.id == resource.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - List View

struct ResourceListView: View {
    @State private var viewModel = ResourceViewModel()
    @State private var showAddSheet = false
    @State private var safariURL: IdentifiableURL?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.resources.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    Picker("Kind", selection: $viewModel.selectedKind) {
                        Text("All").tag(Optional<ResourceKind>.none)
                        ForEach(ResourceKind.allCases) { kind in
                            Text(kind.label).tag(Optional(kind))
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    if viewModel.filteredResources.isEmpty {
                        ContentUnavailableView(
                            "No Resources",
                            systemImage: "folder",
                            description: Text(
                                viewModel.selectedKind == nil
                                    ? "Tap + to add your first resource."
                                    : "No \(viewModel.selectedKind!.label.lowercased()) resources yet."
                            )
                        )
                        .frame(maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(viewModel.filteredResources) { resource in
                                if resource.kind == .url {
                                    Button {
                                        if let str = resource.url, let url = URL(string: str) {
                                            safariURL = IdentifiableURL(url: url)
                                        }
                                    } label: {
                                        ResourceRow(resource: resource)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    NavigationLink(value: resource) {
                                        ResourceRow(resource: resource)
                                    }
                                }
                            }
                            .onDelete { offsets in
                                Task {
                                    for i in offsets {
                                        await viewModel.delete(viewModel.filteredResources[i])
                                    }
                                }
                            }
                        }
                        .navigationDestination(for: Resource.self) { resource in
                            ResourceDetailView(resource: resource)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            ResourceFormView { newResource in
                viewModel.resources.insert(newResource, at: 0)
            }
        }
        .sheet(item: $safariURL) { item in
            SafariView(url: item.url)
        }
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

private struct ResourceRow: View {
    let resource: Resource

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: resource.kind.systemImage)
                .frame(width: 28)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(resource.title)
                    .font(.headline)
                if let subtitle = resource.url ?? resource.body {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Helpers

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

#Preview {
    NavigationStack {
        ResourceListView()
            .navigationTitle("Resources")
    }
}
