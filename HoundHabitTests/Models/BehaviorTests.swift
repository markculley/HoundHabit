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
        #expect(behavior.type == .sit)
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
        #expect(behavior.type == .recall)
    }
}

@Suite("BehaviorType enum")
struct BehaviorTypeTests {

    /// Every raw string the `behaviors.name` column can hold (the DB CHECK
    /// constraint) must decode to the matching `BehaviorType` case.
    @Test("Each stored raw value maps to the correct case")
    func rawValuesMapToCases() {
        let expected: [String: BehaviorType] = [
            "Sit": .sit,
            "Down": .down,
            "Leave It": .leaveIt,
            "Drop It": .dropIt,
            "Stand": .stand,
            "Wait/Stay": .waitStay,
            "Walk": .walk,
            "Touch": .touch,
            "Go to Mat": .goToMat,
            "Recall": .recall,
            "Off": .off,
            "Attention": .attention,
        ]
        for (raw, type) in expected {
            #expect(BehaviorType(rawValue: raw) == type)
            #expect(type.label == raw)
        }
    }

    @Test("allCases covers exactly the 12 standard behaviors")
    func allCasesCount() {
        #expect(BehaviorType.allCases.count == 12)
    }

    @Test("An unknown raw value does not decode")
    func unknownRawValueFails() {
        #expect(BehaviorType(rawValue: "Spin") == nil)
        #expect(BehaviorType(rawValue: "Walk 1") == nil)
    }
}
