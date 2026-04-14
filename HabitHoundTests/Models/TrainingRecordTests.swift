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
        let pairs = fields.map { k, v -> String in
            if v == "false" || v == "true" || Int(v) != nil {
                return "\"\(k)\": \(v)"      // booleans and integers unquoted
            }
            return "\"\(k)\": \"\(v)\""      // everything else as a JSON string
        }
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
            ("20_plus_feet",  .twentyPlusFeet),
            ("custom",        .custom)
        ]
        for (raw, expected) in cases {
            let record = try decoder.decode(TrainingRecord.self, from: makeJSON(overrides: ["distance": raw]))
            #expect(record.distance == expected, "Expected \(expected) for raw value '\(raw)'")
        }
    }

    // MARK: Distraction raw values

    @Test func distractionRawValues() throws {
        let cases: [(String, Distraction)] = [
            ("none",   .none),
            ("any",    .any),
            ("custom", .custom)
        ]
        for (raw, expected) in cases {
            let record = try decoder.decode(TrainingRecord.self, from: makeJSON(overrides: ["distraction": raw]))
            #expect(record.distraction == expected)
        }
    }

    // MARK: Duration raw values

    @Test func durationRawValues() throws {
        let cases: [(String, TrainingDuration)] = [
            ("instant",        .instant),
            ("5_seconds",      .fiveSeconds),
            ("5_plus_seconds", .fivePlusSeconds),
            ("custom",         .custom)
        ]
        for (raw, expected) in cases {
            let record = try decoder.decode(TrainingRecord.self, from: makeJSON(overrides: ["duration": raw]))
            #expect(record.duration == expected, "Expected \(expected) for raw value '\(raw)'")
        }
    }

    // MARK: Custom Three D's values

    @Test("TrainingRecord decodes custom Three D's column values")
    func decodesCustomThreeDsValues() throws {
        let json = """
        {
            "id":             "00000000-0000-0000-0000-000000000001",
            "pet_id":         "00000000-0000-0000-0000-000000000002",
            "guardian_id":    "00000000-0000-0000-0000-000000000003",
            "recorded_at":    "2024-01-15T10:00:00Z",
            "status":         "green",
            "distance":       "custom",
            "distraction":    "custom",
            "duration":       "custom",
            "distance_custom":    "30 ft",
            "duration_custom":    "10 seconds",
            "distraction_custom": "dogs nearby",
            "is_shared":      false,
            "score":          5,
            "created_at":     "2024-01-15T10:00:00Z",
            "updated_at":     "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let record = try decoder.decode(TrainingRecord.self, from: json)

        #expect(record.distance == .custom)
        #expect(record.distanceCustomValue == "30 ft")
        #expect(record.duration == .custom)
        #expect(record.durationCustomValue == "10 seconds")
        #expect(record.distraction == .custom)
        #expect(record.distractionCustomValue == "dogs nearby")
    }

    @Test("TrainingRecord decodes null custom Three D's columns as nil")
    func decodesNullCustomThreeDsValues() throws {
        let json = """
        {
            "id":             "00000000-0000-0000-0000-000000000001",
            "pet_id":         "00000000-0000-0000-0000-000000000002",
            "guardian_id":    "00000000-0000-0000-0000-000000000003",
            "recorded_at":    "2024-01-15T10:00:00Z",
            "status":         "green",
            "distance":       "arms_length",
            "distraction":    "none",
            "duration":       "instant",
            "distance_custom":    null,
            "duration_custom":    null,
            "distraction_custom": null,
            "is_shared":      false,
            "score":          5,
            "created_at":     "2024-01-15T10:00:00Z",
            "updated_at":     "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let record = try decoder.decode(TrainingRecord.self, from: json)

        #expect(record.distanceCustomValue == nil)
        #expect(record.durationCustomValue == nil)
        #expect(record.distractionCustomValue == nil)
    }

    // MARK: Optional notes

    @Test func decodesNilNotes() throws {
        let record = try decoder.decode(TrainingRecord.self, from: makeJSON())
        #expect(record.notes == nil)
    }
}
