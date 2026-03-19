import SwiftUI
import PhotosUI

enum PetFormMode {
    case add
    case edit(Pet)
}

struct PetFormView: View {
    let mode: PetFormMode
    let viewModel: PetViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var breed = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var previewImage: Image?
    @State private var isSaving = false

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existingPhotoUrl: String? {
        if case .edit(let pet) = mode { return pet.photoUrl }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // Photo picker
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                if let preview = previewImage {
                                    preview
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } else {
                                    PetAvatarView(url: existingPhotoUrl, size: 100)
                                }
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.accentColor)
                                    .background(Color(.systemBackground), in: Circle())
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Breed (optional)", text: $breed)
                }
            }
            .navigationTitle(isEditing ? "Edit Pet" : "Add Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        Task { await save() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                Task { await loadPhoto(from: item) }
            }
            .onAppear {
                if case .edit(let pet) = mode {
                    name = pet.name
                    breed = pet.breed ?? ""
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving { ProgressView() }
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

    // MARK: - Helpers

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            photoData = data
            if let uiImage = UIImage(data: data) {
                previewImage = Image(uiImage: uiImage)
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedBreed = breed.trimmingCharacters(in: .whitespaces)
        let breedValue = trimmedBreed.isEmpty ? nil : trimmedBreed

        switch mode {
        case .add:
            await viewModel.createPet(name: trimmedName, breed: breedValue, photoData: photoData)
            // Dismiss if pet was created (photo upload failure is non-fatal; pet is in the list)
            let photoOnlyError = viewModel.errorMessage?.hasPrefix("Pet saved") ?? false
            if viewModel.errorMessage == nil || photoOnlyError {
                dismiss()
            }
        case .edit(let pet):
            var updated = pet
            updated.name = trimmedName
            updated.breed = breedValue
            await viewModel.updatePet(updated, photoData: photoData)
            if viewModel.errorMessage == nil {
                dismiss()
            }
        }
    }
}
