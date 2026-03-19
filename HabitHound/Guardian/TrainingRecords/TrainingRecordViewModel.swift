import Foundation
import Supabase

@Observable
class TrainingRecordViewModel {
    var records: [TrainingRecord] = []
    var isLoading = false
    var errorMessage: String?

    private let service = TrainingRecordService()

    // MARK: - Fetch

    func loadRecords(petId: UUID? = nil) async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            records = try await service.fetchRecords(guardianId: userId, petId: petId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Create

    func createRecord(
        petId: UUID,
        recordedAt: Date,
        status: TrainingStatus,
        distance: Distance,
        distraction: Distraction,
        duration: TrainingDuration,
        notes: String?,
        isShared: Bool
    ) async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let record = try await service.createRecord(
                petId: petId,
                guardianId: userId,
                recordedAt: recordedAt,
                status: status,
                distance: distance,
                distraction: distraction,
                duration: duration,
                notes: notes.flatMap { $0.isEmpty ? nil : $0 },
                isShared: isShared
            )
            records.insert(record, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Update

    func updateRecord(_ record: TrainingRecord) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let updated = try await service.updateRecord(record)
            if let idx = records.firstIndex(where: { $0.id == record.id }) {
                records[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete

    func deleteRecord(_ record: TrainingRecord) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await service.deleteRecord(id: record.id)
            records.removeAll { $0.id == record.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
