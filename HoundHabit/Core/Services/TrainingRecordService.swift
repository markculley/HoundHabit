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
        score: Int,
        distance: Distance,
        distraction: Distraction,
        duration: TrainingDuration,
        distanceCustomValue: String? = nil,
        durationCustomValue: String? = nil,
        distractionCustomValue: String? = nil,
        notes: String?,
        isShared: Bool,
        planItemId: UUID? = nil
    ) async throws -> TrainingRecord {
        let insert = TrainingRecordInsert(
            petId: petId,
            guardianId: guardianId,
            recordedAt: recordedAt,
            status: TrainingStatus.from(score: score),
            distance: distance,
            distraction: distraction,
            duration: duration,
            distanceCustomValue: distanceCustomValue,
            durationCustomValue: durationCustomValue,
            distractionCustomValue: distractionCustomValue,
            notes: notes,
            isShared: isShared,
            score: score,
            planItemId: planItemId
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
            status: TrainingStatus.from(score: record.score),
            distance: record.distance,
            distraction: record.distraction,
            duration: record.duration,
            distanceCustomValue: record.distanceCustomValue,
            durationCustomValue: record.durationCustomValue,
            distractionCustomValue: record.distractionCustomValue,
            notes: record.notes,
            isShared: record.isShared,
            score: record.score,
            planItemId: record.planItemId
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
    let distanceCustomValue: String?
    let durationCustomValue: String?
    let distractionCustomValue: String?
    let notes: String?
    let isShared: Bool
    let score: Int
    let planItemId: UUID?

    enum CodingKeys: String, CodingKey {
        case petId          = "pet_id"
        case guardianId     = "guardian_id"
        case recordedAt     = "recorded_at"
        case status, distance, distraction, duration, notes
        case distanceCustomValue    = "distance_custom"
        case durationCustomValue    = "duration_custom"
        case distractionCustomValue = "distraction_custom"
        case isShared       = "is_shared"
        case score
        case planItemId     = "plan_item_id"
    }
}

private struct TrainingRecordUpdate: Encodable {
    let recordedAt: Date
    let status: TrainingStatus
    let distance: Distance
    let distraction: Distraction
    let duration: TrainingDuration
    let distanceCustomValue: String?
    let durationCustomValue: String?
    let distractionCustomValue: String?
    let notes: String?
    let isShared: Bool
    let score: Int
    let planItemId: UUID?

    enum CodingKeys: String, CodingKey {
        case recordedAt     = "recorded_at"
        case status, distance, distraction, duration, notes
        case distanceCustomValue    = "distance_custom"
        case durationCustomValue    = "duration_custom"
        case distractionCustomValue = "distraction_custom"
        case isShared       = "is_shared"
        case score
        case planItemId     = "plan_item_id"
    }
}
