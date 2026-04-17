import SwiftUI

struct PetListView: View {
    @State private var viewModel = PetViewModel()
    @State private var showAddPet = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.pets.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.pets.isEmpty {
                    ContentUnavailableView(
                        "No Pets Yet",
                        systemImage: "pawprint.circle",
                        description: Text("Add your first pet to get started.")
                    )
                } else {
                    List {
                        ForEach(viewModel.pets) { pet in
                            NavigationLink(value: pet.id) {
                                PetRow(pet: pet)
                            }
                        }
                        .onDelete { offsets in
                            Task {
                                for i in offsets {
                                    await viewModel.deletePet(viewModel.pets[i])
                                }
                            }
                        }
                    }
                    .navigationDestination(for: UUID.self) { petId in
                        PetDetailView(petId: petId, viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("My Pets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddPet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddPet) {
                PetFormView(mode: .add, viewModel: viewModel)
            }
            .task { await viewModel.loadPets() }
            .onChange(of: showAddPet) { _, isShowing in
                if !isShowing { Task { await viewModel.loadPets() } }
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
}

// MARK: - Row

#Preview {
    PetListView()
}

private struct PetRow: View {
    let pet: Pet

    var body: some View {
        HStack(spacing: 12) {
            PetAvatarView(url: pet.photoUrl.map { "\($0)?t=\(Int(pet.updatedAt.timeIntervalSince1970))" }, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(pet.name).font(.headline)
                if let breed = pet.breed, !breed.isEmpty {
                    Text(breed).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
