import Foundation
import Supabase

struct TrainingRecordService {

    func fetchRecords(guardianId: UUID, petId: UUID? = nil) async throws -> [TrainingRecord] {
        var query = supabase
            .from("training_records")
            .select()
            .eq("guardian_id", value: guardianId)
        if let petId {
            query = query.eq("pet_id", value: petId)
        }
        return try await query
            .order("recorded_at", ascending: false)
            .execute()
            .value
    }

    func createRecord(
        petId: UUID,
        guardianId: UUID,
        recordedAt: Date,
        status: TrainingStatus,
        distance: Distance,
        distraction: Distraction,
        duration: TrainingDuration,
        notes: String?,
        isShared: Bool
    ) async throws -> TrainingRecord {
        let insert = TrainingRecordInsert(
            petId: petId,
            guardianId: guardianId,
            recordedAt: recordedAt,
            status: status,
            distance: distance,
            distraction: distraction,
            duration: duration,
            notes: notes,
            isShared: isShared
        )
        return try await supabase
            .from("training_records")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    func updateRecord(_ record: TrainingRecord) async throws -> TrainingRecord {
        let update = TrainingRecordUpdate(
            recordedAt: record.recordedAt,
            status: record.status,
            distance: record.distance,
            distraction: record.distraction,
            duration: record.duration,
            notes: record.notes,
            isShared: record.isShared
        )
        return try await supabase
            .from("training_records")
            .update(update)
            .eq("id", value: record.id)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteRecord(id: UUID) async throws {
        try await supabase
            .from("training_records")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

// MARK: - Encodable helpers

private struct TrainingRecordInsert: Encodable {
    let petId: UUID
    let guardianId: UUID
    let recordedAt: Date
    let status: TrainingStatus
    let distance: Distance
    let distraction: Distraction
    let duration: TrainingDuration
    let notes: String?
    let isShared: Bool

    enum CodingKeys: String, CodingKey {
        case petId = "pet_id"
        case guardianId = "guardian_id"
        case recordedAt = "recorded_at"
        case status, distance, distraction, duration, notes
        case isShared = "is_shared"
    }
}

private struct TrainingRecordUpdate: Encodable {
    let recordedAt: Date
    let status: TrainingStatus
    let distance: Distance
    let distraction: Distraction
    let duration: TrainingDuration
    let notes: String?
    let isShared: Bool

    enum CodingKeys: String, CodingKey {
        case recordedAt = "recorded_at"
        case status, distance, distraction, duration, notes
        case isShared = "is_shared"
    }
}
