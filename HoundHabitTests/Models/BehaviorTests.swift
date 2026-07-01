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
        #expect(behavior.type == .standard(.sit))
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
        #expect(behavior.type == .standard(.recall))
    }
}

@Suite("BehaviorType enum")
struct BehaviorTypeTests {

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    /// Every standard label maps to the matching `.standard` case and labels
    /// round-trip.
    @Test("Each standard raw value maps to the correct case")
    func standardValuesMapToCases() {
        let expected: [String: StandardBehavior] = [
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
        for (raw, standard) in expected {
            #expect(BehaviorType(rawValue: raw) == .standard(standard))
            #expect(BehaviorType(rawValue: raw).label == raw)
        }
    }

    @Test("StandardBehavior covers exactly the 12 presets")
    func standardCount() {
        #expect(StandardBehavior.allCases.count == 12)
    }

    @Test("An unknown raw value becomes a custom behavior")
    func unknownRawValueIsCustom() {
        #expect(BehaviorType(rawValue: "Spin") == .custom("Spin"))
        #expect(BehaviorType(rawValue: "Heel").isCustom)
        #expect(BehaviorType(rawValue: "Heel").label == "Heel")
    }

    @Test("A custom value matching a standard label collapses to standard")
    func customMatchingStandardCollapses() {
        #expect(BehaviorType(rawValue: "Sit") == .standard(.sit))
        #expect(BehaviorType(rawValue: "Sit").isCustom == false)
    }

    @Test("BehaviorType decodes from a bare JSON string")
    func decodesFromBareString() throws {
        #expect(try decoder.decode(BehaviorType.self, from: Data("\"Sit\"".utf8)) == .standard(.sit))
        #expect(try decoder.decode(BehaviorType.self, from: Data("\"Heel\"".utf8)) == .custom("Heel"))
    }

    @Test("A custom behavior encodes back to its bare name string")
    func customEncodesToBareString() throws {
        let json = String(data: try encoder.encode(BehaviorType.custom("Heel")), encoding: .utf8)
        #expect(json == "\"Heel\"")
    }
}
