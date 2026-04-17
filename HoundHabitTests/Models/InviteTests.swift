import Testing
import Foundation
@testable import HoundHabit

@Suite("Invite decoding")
struct InviteDecodingTests {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func makeJSON(status: String = "pending") -> Data {
        """
        {
            "id":         "00000000-0000-0000-0000-000000000001",
            "trainer_id": "00000000-0000-0000-0000-000000000002",
            "email":      "guardian@example.com",
            "code":       "A1B2C3D4",
            "status":     "\(status)",
            "created_at": "2026-03-22T10:00:00Z",
            "expires_at": "2026-03-29T10:00:00Z"
        }
        """.data(using: .utf8)!
    }

    // MARK: CodingKeys

    @Test func decodesSnakeCaseKeys() throws {
        let invite = try decoder.decode(Invite.self, from: makeJSON())
        #expect(invite.trainerId == UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        #expect(invite.email == "guardian@example.com")
        #expect(invite.code == "A1B2C3D4")
    }

    // MARK: InviteStatus raw values

    @Test func statusPendingRawValue() throws {
        let invite = try decoder.decode(Invite.self, from: makeJSON(status: "pending"))
        #expect(invite.status == .pending)
    }

    @Test func statusAcceptedRawValue() throws {
        let invite = try decoder.decode(Invite.self, from: makeJSON(status: "accepted"))
        #expect(invite.status == .accepted)
    }

    @Test func statusExpiredRawValue() throws {
        let invite = try decoder.decode(Invite.self, from: makeJSON(status: "expired"))
        #expect(invite.status == .expired)
    }
}
