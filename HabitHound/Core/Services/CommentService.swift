import Foundation
import Supabase

struct CommentService {

    func fetchComments(recordId: UUID) async throws -> [Comment] {
        try await supabase
            .from("comments")
            .select()
            .eq("training_record_id", value: recordId)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func addComment(recordId: UUID, body: String) async throws -> Comment {
        guard let authorId = supabase.auth.currentUser?.id else {
            throw CommentError.notAuthenticated
        }
        let insert = CommentInsert(trainingRecordId: recordId, authorId: authorId, body: body)
        return try await supabase
            .from("comments")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteComment(id: UUID) async throws {
        try await supabase
            .from("comments")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

// MARK: - Errors

enum CommentError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        "You must be signed in to post a comment."
    }
}

// MARK: - Encodable helpers

private struct CommentInsert: Encodable {
    let trainingRecordId: UUID
    let authorId: UUID
    let body: String

    enum CodingKeys: String, CodingKey {
        case trainingRecordId = "training_record_id"
        case authorId         = "author_id"
        case body
    }
}
