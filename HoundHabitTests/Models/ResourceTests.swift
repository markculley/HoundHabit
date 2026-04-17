import Testing
import Foundation
@testable import HoundHabit

@Suite("Resource decoding")
struct ResourceDecodingTests {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func makeJSON(kind: String = "note") -> Data {
        """
        {
            "id":          "00000000-0000-0000-0000-000000000001",
            "owner_id":    "00000000-0000-0000-0000-000000000002",
            "added_by_id": "00000000-0000-0000-0000-000000000003",
            "guardian_id": "00000000-0000-0000-0000-000000000004",
            "kind":        "\(kind)",
            "url":         null,
            "body":        null,
            "title":       "Test resource",
            "created_at":  "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!
    }

    // MARK: CodingKeys

    @Test func decodesSnakeCaseKeys() throws {
        let resource = try decoder.decode(Resource.self, from: makeJSON())
        #expect(resource.ownerId    == UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        #expect(resource.addedById  == UUID(uuidString: "00000000-0000-0000-0000-000000000003"))
        #expect(resource.guardianId == UUID(uuidString: "00000000-0000-0000-0000-000000000004"))
        #expect(resource.title == "Test resource")
    }

    // MARK: ResourceKind raw values

    @Test func kindPhotoRawValue() throws {
        let resource = try decoder.decode(Resource.self, from: makeJSON(kind: "photo"))
        #expect(resource.kind == .photo)
    }

    @Test func kindURLRawValue() throws {
        let resource = try decoder.decode(Resource.self, from: makeJSON(kind: "url"))
        #expect(resource.kind == .url)
    }

    @Test func kindNoteRawValue() throws {
        let resource = try decoder.decode(Resource.self, from: makeJSON(kind: "note"))
        #expect(resource.kind == .note)
    }

    // MARK: Optional fields

    @Test func decodesNilUrlAndBody() throws {
        let resource = try decoder.decode(Resource.self, from: makeJSON())
        #expect(resource.url  == nil)
        #expect(resource.body == nil)
    }
}
