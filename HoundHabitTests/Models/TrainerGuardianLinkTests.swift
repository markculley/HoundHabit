import Testing
import Foundation
@testable import HoundHabit

@Suite("TrainerGuardianLink decoding")
struct TrainerGuardianLinkDecodingTests {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func makeJSON(status: String = "active") -> Data {
        """
        {
            "id":          "00000000-0000-0000-0000-000000000001",
            "trainer_id":  "00000000-0000-0000-0000-000000000002",
            "guardian_id": "00000000-0000-0000-0000-000000000003",
            "status":      "\(status)",
            "linked_at":   "2026-03-22T10:00:00Z"
        }
        """.data(using: .utf8)!
    }

    // MARK: CodingKeys

    @Test func decodesSnakeCaseKeys() throws {
        let link = try decoder.decode(TrainerGuardianLink.self, from: makeJSON())
        #expect(link.trainerId  == UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        #expect(link.guardianId == UUID(uuidString: "00000000-0000-0000-0000-000000000003"))
    }

    // MARK: LinkStatus raw values

    @Test func statusActiveRawValue() throws {
        let link = try decoder.decode(TrainerGuardianLink.self, from: makeJSON(status: "active"))
        #expect(link.status == .active)
    }

    @Test func statusInactiveRawValue() throws {
        let link = try decoder.decode(TrainerGuardianLink.self, from: makeJSON(status: "inactive"))
        #expect(link.status == .inactive)
    }
}
