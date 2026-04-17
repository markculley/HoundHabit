import Testing
import Foundation
@testable import HoundHabit

@Suite("Behavior model")
struct BehaviorTests {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @Test("Behavior decodes all snake_case keys from Supabase JSON")
    func behaviorDecodesSnakeCaseKeys() throws {
        let json = """
        {
            "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            "plan_id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
            "name": "Sit",
            "sort_order": 2,
            "created_at": "2026-01-01T12:00:00Z"
        }
        """.data(using: .utf8)!

        let behavior = try decoder.decode(Behavior.self, from: json)

        #expect(behavior.id == UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"))
        #expect(behavior.planId == UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"))
        #expect(behavior.name == "Sit")
        #expect(behavior.sortOrder == 2)
    }

    @Test("Behavior decodes sort_order 0 as first in plan")
    func behaviorDecodesSortOrderZero() throws {
        let json = """
        {
            "id": "cccccccc-cccc-cccc-cccc-cccccccccccc",
            "plan_id": "dddddddd-dddd-dddd-dddd-dddddddddddd",
            "name": "Recall",
            "sort_order": 0,
            "created_at": "2026-01-01T12:00:00Z"
        }
        """.data(using: .utf8)!

        let behavior = try decoder.decode(Behavior.self, from: json)

        #expect(behavior.sortOrder == 0)
        #expect(behavior.name == "Recall")
    }
}
