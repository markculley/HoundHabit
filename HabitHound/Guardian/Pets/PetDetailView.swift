import SwiftUI

struct PetDetailView: View {
    let petId: UUID
    let viewModel: PetViewModel

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showTrainingSessions = false
    @Environment(\.dismiss) private var dismiss

    private var pet: Pet? {
        viewModel.pets.first { $0.id == petId }
    }

    var body: some View {
        Group {
            if let pet {
                ScrollView {
                    VStack(spacing: 24) {
                        PetAvatarView(url: pet.photoUrl.map { "\($0)?t=\(Int(pet.updatedAt.timeIntervalSince1970))" }, size: 120)
                            .padding(.top, 16)

                        Text(pet.name)
                            .font(.largeTitle).bold()

                        if let breed = pet.breed, !breed.isEmpty {
                            Text(breed)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }

                        // Training Records for this pet
                        Button {
                            showTrainingSessions = true
                        } label: {
                            Label("Training Sessions", systemImage: "list.bullet.clipboard")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .padding(.top, 8)

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
                // Sheet + its own NavigationStack rather than navigationDestination(isPresented:).
                // Mixing isPresented-based and value-based navigation in the same stack causes
                // NavigationLink(value:) taps to silently pop back instead of pushing. Giving
                // TrainingRecordListView its own stack inside a sheet avoids the conflict.
                .sheet(isPresented: $showTrainingSessions) {
                    NavigationStack {
                        TrainingRecordListView(petId: pet.id, preselectedPetId: pet.id, petName: pet.name)
                            .navigationTitle("\(pet.name)'s Sessions")
                    }
                }
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

#Preview {
    let vm = PetViewModel()
    let pet = Pet(
        id: UUID(),
        guardianId: UUID(),
        name: "Ozzie",
        breed: "Goldendoodle",
        photoUrl: nil,
        createdAt: Date(),
        updatedAt: Date()
    )
    vm.pets = [pet]
    return NavigationStack {
        PetDetailView(petId: pet.id, viewModel: vm)
    }
}
