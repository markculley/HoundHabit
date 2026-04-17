import Foundation
import Supabase

struct InviteService {

    // MARK: - Trainer

    /// Creates an invite for the given email, inserts it into Supabase, and
    /// fires a best-effort email via the send-invite-email Edge Function.
    func createInvite(email: String, trainerName: String?) async throws -> Invite {
        guard let trainerId = supabase.auth.currentUser?.id else {
            throw InviteError.notAuthenticated
        }
        let code = generateCode()
        let insert = InviteInsert(trainerId: trainerId, email: email, code: code)
        let invite: Invite = try await supabase
            .from("invites")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        // Fire-and-forget: email failure must not block invite creation.
        Task {
            try? await supabase.functions.invoke(
                "send-invite-email",
                options: .init(body: [
                    "email":       email,
                    "code":        code,
                    "trainerName": trainerName ?? "Your trainer"
                ])
            )
        }

        return invite
    }

    /// Returns all invites created by the current trainer, newest first.
    func fetchInvites() async throws -> [Invite] {
        guard let trainerId = supabase.auth.currentUser?.id else { return [] }
        return try await supabase
            .from("invites")
            .select()
            .eq("trainer_id", value: trainerId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Returns all active linked guardian profiles for the current trainer.
    func fetchLinkedGuardians() async throws -> [LinkedGuardian] {
        guard let trainerId = supabase.auth.currentUser?.id else { return [] }
        return try await supabase
            .from("trainer_guardian_links")
            .select("*, profiles!trainer_guardian_links_guardian_id_fkey(*)")
            .eq("trainer_id", value: trainerId)
            .eq("status", value: "active")
            .execute()
            .value
    }

    // MARK: - Guardian

    /// Returns the active linked trainer for the current guardian, or nil if none.
    func fetchLinkedTrainer() async throws -> LinkedTrainer? {
        guard let guardianId = supabase.auth.currentUser?.id else { return nil }
        let results: [LinkedTrainer] = try await supabase
            .from("trainer_guardian_links")
            .select("*, profiles!trainer_guardian_links_trainer_id_fkey(*)")
            .eq("guardian_id", value: guardianId)
            .eq("status", value: "active")
            .execute()
            .value
        return results.first
    }

    /// Looks up a pending, non-expired invite by code.
    /// Throws `InviteError.invalidCode`, `.expired`, or `.alreadyUsed` on bad codes.
    func fetchInviteByCode(_ code: String) async throws -> Invite {
        let results: [Invite] = try await supabase
            .from("invites")
            .select()
            .eq("code", value: code.uppercased())
            .execute()
            .value

        guard let invite = results.first else {
            throw InviteError.invalidCode
        }

        switch invite.status {
        case .expired:  throw InviteError.expired
        case .accepted: throw InviteError.alreadyUsed
        case .pending:  break
        }

        if invite.expiresAt < Date() {
            throw InviteError.expired
        }

        return invite
    }

    /// Accepts the invite: creates a trainer_guardian_links row and marks the invite accepted.
    func acceptInvite(_ invite: Invite) async throws -> TrainerGuardianLink {
        guard let guardianId = supabase.auth.currentUser?.id else {
            throw InviteError.notAuthenticated
        }

        let linkInsert = TrainerGuardianLinkInsert(
            trainerId: invite.trainerId,
            guardianId: guardianId
        )
        let link: TrainerGuardianLink = try await supabase
            .from("trainer_guardian_links")
            .insert(linkInsert)
            .select()
            .single()
            .execute()
            .value

        // Mark invite accepted.
        try await supabase
            .from("invites")
            .update(["status": InviteStatus.accepted.rawValue])
            .eq("id", value: invite.id)
            .execute()

        return link
    }

    // MARK: - Helpers

    private func generateCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // omit O, 0, I, 1 for readability
        return String((0..<8).map { _ in chars.randomElement()! })
    }
}

// MARK: - Linked trainer (join result, guardian's perspective)

struct LinkedTrainer: Identifiable, Decodable, Hashable {
    static func == (lhs: LinkedTrainer, rhs: LinkedTrainer) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: UUID           // trainer_guardian_links.id
    let trainerId: UUID
    let guardianId: UUID
    let status: LinkStatus
    let linkedAt: Date
    let profile: Profile   // trainer's profile

    enum CodingKeys: String, CodingKey {
        case id
        case trainerId  = "trainer_id"
        case guardianId = "guardian_id"
        case status
        case linkedAt   = "linked_at"
        case profile    = "profiles"
    }
}

// MARK: - Linked guardian (join result)

struct LinkedGuardian: Identifiable, Decodable, Hashable {
    static func == (lhs: LinkedGuardian, rhs: LinkedGuardian) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: UUID           // trainer_guardian_links.id
    let trainerId: UUID
    let guardianId: UUID
    let status: LinkStatus
    let linkedAt: Date
    let profile: Profile

    enum CodingKeys: String, CodingKey {
        case id
        case trainerId  = "trainer_id"
        case guardianId = "guardian_id"
        case status
        case linkedAt   = "linked_at"
        case profile    = "profiles"
    }
}

// MARK: - Errors

enum InviteError: LocalizedError {
    case invalidCode
    case expired
    case alreadyUsed
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidCode:       return "Invalid code. Please check and try again."
        case .expired:           return "This code has expired."
        case .alreadyUsed:       return "This code has already been used."
        case .notAuthenticated:  return "You must be signed in to perform this action."
        }
    }
}

// MARK: - Encodable helpers

private struct InviteInsert: Encodable {
    let trainerId: UUID
    let email: String
    let code: String

    enum CodingKeys: String, CodingKey {
        case trainerId = "trainer_id"
        case email, code
    }
}

private struct TrainerGuardianLinkInsert: Encodable {
    let trainerId: UUID
    let guardianId: UUID

    enum CodingKeys: String, CodingKey {
        case trainerId  = "trainer_id"
        case guardianId = "guardian_id"
    }
}
