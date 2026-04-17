import Foundation
import Supabase

struct PetService {

    func fetchPets(guardianId: UUID) async throws -> [Pet] {
        try await supabase
            .from("pets")
            .select()
            .eq("guardian_id", value: guardianId)
            .order("created_at")
            .execute()
            .value
    }

    func createPet(name: String, breed: String?, photoUrl: String?, guardianId: UUID) async throws -> Pet {
        let insert = PetInsert(guardianId: guardianId, name: name, breed: breed, photoUrl: photoUrl)
        return try await supabase
            .from("pets")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    func updatePet(_ pet: Pet) async throws -> Pet {
        let update = PetUpdate(name: pet.name, breed: pet.breed, photoUrl: pet.photoUrl)
        return try await supabase
            .from("pets")
            .update(update)
            .eq("id", value: pet.id)
            .select()
            .single()
            .execute()
            .value
    }

    func deletePet(id: UUID) async throws {
        try await supabase
            .from("pets")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

// MARK: - Encodable helpers

private struct PetInsert: Encodable {
    let guardianId: UUID
    let name: String
    let breed: String?
    let photoUrl: String?

    enum CodingKeys: String, CodingKey {
        case guardianId = "guardian_id"
        case name
        case breed
        case photoUrl = "photo_url"
    }
}

private struct PetUpdate: Encodable {
    let name: String
    let breed: String?
    let photoUrl: String?

    enum CodingKeys: String, CodingKey {
        case name
        case breed
        case photoUrl = "photo_url"
    }
}
