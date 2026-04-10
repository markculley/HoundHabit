import Foundation
import Supabase

struct ResourceService {

    func fetchResources(guardianId: UUID) async throws -> [Resource] {
        try await supabase
            .from("resources")
            .select()
            .eq("guardian_id", value: guardianId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func createResource(
        id: UUID = UUID(),
        guardianId: UUID,
        kind: ResourceKind,
        title: String,
        url: String?,
        body: String?
    ) async throws -> Resource {
        let insert = ResourceInsert(
            id: id,
            ownerId: guardianId,
            addedById: guardianId,
            guardianId: guardianId,
            kind: kind,
            url: url,
            body: body,
            title: title
        )
        return try await supabase
            .from("resources")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    func createResourceForGuardian(
        id: UUID = UUID(),
        guardianId: UUID,
        addedById: UUID,
        kind: ResourceKind,
        title: String,
        url: String?,
        body: String?
    ) async throws -> Resource {
        let insert = ResourceInsert(
            id: id,
            ownerId: guardianId,
            addedById: addedById,
            guardianId: guardianId,
            kind: kind,
            url: url,
            body: body,
            title: title
        )
        return try await supabase
            .from("resources")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteResource(id: UUID) async throws {
        try await supabase
            .from("resources")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

// MARK: - Encodable helpers

private struct ResourceInsert: Encodable {
    let id: UUID
    let ownerId: UUID
    let addedById: UUID
    let guardianId: UUID
    let kind: ResourceKind
    let url: String?
    let body: String?
    let title: String

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId    = "owner_id"
        case addedById  = "added_by_id"
        case guardianId = "guardian_id"
        case kind, url, body, title
    }
}
