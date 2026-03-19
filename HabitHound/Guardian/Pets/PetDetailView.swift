import SwiftUI

struct PetDetailView: View {
    let petId: UUID
    let viewModel: PetViewModel

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    private var pet: Pet? {
        viewModel.pets.first { $0.id == petId }
    }

    var body: some View {
        Group {
            if let pet {
                ScrollView {
                    VStack(spacing: 24) {
                        PetAvatarView(url: pet.photoUrl, size: 120)
                            .padding(.top, 16)

                        Text(pet.name)
                            .font(.largeTitle).bold()

                        if let breed = pet.breed, !breed.isEmpty {
                            Text(breed)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }

                        // Placeholder for future training history
                        ContentUnavailableView(
                            "No Sessions Yet",
                            systemImage: "list.bullet.clipboard",
                            description: Text("Training sessions for \(pet.name) will appear here.")
                        )
                        .padding(.top, 24)

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Text("Delete Pet")
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity)
                }
                .navigationTitle(pet.name)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") { showEditSheet = true }
                    }
                }
                .sheet(isPresented: $showEditSheet) {
                    PetFormView(mode: .edit(pet), viewModel: viewModel)
                }
                .confirmationDialog(
                    "Delete \(pet.name)?",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        Task { await viewModel.deletePet(pet) }
                    }
                } message: {
                    Text("This cannot be undone.")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        // If the pet was deleted from elsewhere, pop back automatically
        .onChange(of: pet == nil) { _, isGone in
            if isGone { dismiss() }
        }
    }
}
