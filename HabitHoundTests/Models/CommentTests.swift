import Testing
import Foundation
@testable import HabitHound

@Suite("Comment model")
struct CommentTests {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @Test("Decodes snake_case keys from Supabase JSON")
    func decodesSnakeCaseKeys() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "training_record_id": "22222222-2222-2222-2222-222222222222",
            "author_id": "33333333-3333-3333-3333-333333333333",
            "body": "Great session today!",
            "created_at": "2025-01-15T10:30:00Z",
            "updated_at": "2025-01-15T10:30:00Z"
        }
        """.data(using: .utf8)!

        let comment = try decoder.decode(HabitHound.Comment.self, from: json)

        #expect(comment.id == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(comment.trainingRecordId == UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        #expect(comment.authorId == UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        #expect(comment.body == "Great session today!")
    }

    @Test("Identifiable id is stable")
    func identifiableId() throws {
        let json = """
        {
            "id": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
            "training_record_id": "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
            "author_id": "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC",
            "body": "Looking good",
            "created_at": "2025-06-01T08:00:00Z",
            "updated_at": "2025-06-01T08:00:00Z"
        }
        """.data(using: .utf8)!

        let comment = try decoder.decode(HabitHound.Comment.self, from: json)
        #expect(comment.id == comment.id)
    }
}
