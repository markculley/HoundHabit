import Foundation
import Supabase

struct StorageService {

    // MARK: - Pet Photos

    /// Uploads image data to the pet-photos bucket and returns the public URL string.
    func uploadPetPhoto(data: Data, guardianId: UUID, petId: UUID) async throws -> String {
        // Path must start with the guardian's user ID to satisfy storage RLS:
        // pet_photos_insert policy checks (storage.foldername(name))[1] = auth.uid()
        let path = "\(guardianId.uuidString.lowercased())/\(petId.uuidString.lowercased())/photo.jpg"
        try await supabase.storage
            .from("pet-photos")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        let url = try supabase.storage.from("pet-photos").getPublicURL(path: path)
        return url.absoluteString
    }
}
