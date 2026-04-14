import Testing
import Foundation
@testable import HabitHound

// MARK: - CodingKeys / snake_case mapping

@Suite("TrainingRecord decoding")
struct TrainingRecordDecodingTests {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func makeJSON(overrides: [String: String] = [:]) -> Data {
        var fields: [String: String] = [
            "id":           "00000000-0000-0000-0000-000000000001",
            "pet_id":       "00000000-0000-0000-0000-000000000002",
            "guardian_id":  "00000000-0000-0000-0000-000000000003",
            "recorded_at":  "2024-01-15T10:00:00Z",
            "status":       "green",
            "distance":     "arms_length",
            "distraction":  "none",
            "duration":     "instant",
            "is_shared":    "false",
            "score":        "5",
            "created_at":   "2024-01-15T10:00:00Z",
            "updated_at":   "2024-01-15T10:00:00Z"
        ]
        fields.merge(overrides) { _, new in new }
        let pairs = fields.map { "\"\($0.key)\": \($0.value == "false" || $0.value == "true" ? $0.value : "\"\($0.value)\"")" }
        return Data("{ \(pairs.joined(separator: ", ")) }".utf8)
    }

    @Test func decodesSnakeCaseKeys() throws {
        let record = try decoder.decode(TrainingRecord.self, from: makeJSON())
        #expect(record.petId      == UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        #expect(record.guardianId == UUID(uuidString: "00000000-0000-0000-0000-000000000003"))
        #expect(record.isShared   == false)
    }

    // MARK: TrainingStatus raw values

    @Test func statusRawValues() throws {
        for (raw, expected): (String, TrainingStatus) in [
            ("red", .red), ("orange", .orange), ("yellow", .yellow), ("green", .green)
        ] {
            let record = try decoder.decode(TrainingRecord.self, from: makeJSON(overrides: ["status": raw]))
            #expect(record.status == expected, "Expected \(expected) for raw value '\(raw)'")
        }
    }

    // MARK: Distance raw values

    @Test func distanceRawValues() throws {
        let cases: [(String, Distance)] = [
            ("arms_length",   .armsLength),
            ("6_feet",        .sixFeet),
            ("12_feet",       .twelveFeet),
            ("20_feet",       .twentyFeet),
            ("20_plus_feet",  .twentyPlusFeet)
        ]
        for (raw, expected) in cases {
            let record = try decoder.decode(TrainingRecord.self, from: makeJSON(overrides: ["distance": raw]))
            #expect(record.distance == expected, "Expected \(expected) for raw value '\(raw)'")
        }
    }

    // MARK: Distraction raw values

    @Test func distractionRawValues() throws {
        for (raw, expected): (String, Distraction) in [("none", .none), ("any", .any)] {
            let record = try decoder.decode(TrainingRecord.self, from: makeJSON(overrides: ["distraction": raw]))
            #expect(record.distraction == expected)
        }
    }

    // MARK: Duration raw values

    @Test func durationRawValues() throws {
        let cases: [(String, TrainingDuration)] = [
            ("instant",        .instant),
            ("5_seconds",      .fiveSeconds),
            ("5_plus_seconds", .fivePlusSeconds)
        ]
        for (raw, expected) in cases {
            let record = try decoder.decode(TrainingRecord.self, from: makeJSON(overrides: ["duration": raw]))
            #expect(record.duration == expected, "Expected \(expected) for raw value '\(raw)'")
        }
    }

    // MARK: Optional notes

    @Test func decodesNilNotes() throws {
        let record = try decoder.decode(TrainingRecord.self, from: makeJSON())
        #expect(record.notes == nil)
    }
}
