import Foundation
import Supabase

@Observable
class PetViewModel {
    var pets: [Pet] = []
    var isLoading = false
    var errorMessage: String?

    private let petService = PetService()
    private let storageService = StorageService()

    // MARK: - Fetch

    func loadPets() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            pets = try await petService.fetchPets(guardianId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Create

    func createPet(name: String, breed: String?, photoData: Data?) async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            var pet = try await petService.createPet(name: name, breed: breed, photoUrl: nil, guardianId: userId)

            if let data = photoData {
                do {
                    let url = try await storageService.uploadPetPhoto(data: data, guardianId: userId, petId: pet.id)
                    pet.photoUrl = url
                    pet = try await petService.updatePet(pet)
                } catch {
                    // Pet was created — still add it; caller can retry the photo via edit
                    errorMessage = "Pet saved, but photo upload failed: \(error.localizedDescription)"
                }
            }

            pets.append(pet)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Update

    func updatePet(_ pet: Pet, photoData: Data?) async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            var updated = pet
            if let data = photoData {
                updated.photoUrl = try await storageService.uploadPetPhoto(data: data, guardianId: userId, petId: pet.id)
            }
            updated = try await petService.updatePet(updated)
            if let idx = pets.firstIndex(where: { $0.id == pet.id }) {
                pets[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete

    func deletePet(_ pet: Pet) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await petService.deletePet(id: pet.id)
            pets.removeAll { $0.id == pet.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
