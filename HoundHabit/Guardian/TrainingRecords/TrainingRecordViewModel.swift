import Foundation
import Supabase

@Observable
class TrainingRecordViewModel {
    var records: [TrainingRecord] = []
    var petNames: [UUID: String] = [:]
    /// Step title for a record's `planItemId`. Resolved in `loadRecords`.
    var stepTitles: [UUID: String] = [:]
    /// Behavior name for a record's `planItemId`. Resolved in `loadRecords`.
    var behaviorNames: [UUID: String] = [:]
    var isLoading = false
    var errorMessage: String?

    private let service = TrainingRecordService()
    private let petService = PetService()
    private let planService = TrainingPlanService()

    // MARK: - Fetch

    func loadRecords(petId: UUID? = nil) async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let fetchedRecords = service.fetchRecords(guardianId: userId, petId: petId)
            async let fetchedPets = petService.fetchPets(guardianId: userId)
            let (r, pets) = try await (fetchedRecords, fetchedPets)
            records = r
            petNames = Dictionary(uniqueKeysWithValues: pets.map { ($0.id, $0.name) })
            await resolvePlanContext(for: r)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Populates `stepTitles` and `behaviorNames` (both keyed by `planItemId`) for
    /// the plan-linked records in `records`. Two bulk queries: plan items by id,
    /// then behaviors by id.
    private func resolvePlanContext(for records: [TrainingRecord]) async {
        let itemIds = Array(Set(records.compactMap { $0.planItemId }))
        guard !itemIds.isEmpty else {
            stepTitles = [:]
            behaviorNames = [:]
            return
        }
        do {
            let items = try await planService.fetchItems(ids: itemIds)
            let behaviorIds = Array(Set(items.compactMap { $0.behaviorId }))
            let behaviors = try await planService.fetchBehaviors(ids: behaviorIds)
            let behaviorNameById = Dictionary(uniqueKeysWithValues: behaviors.map { ($0.id, $0.name) })

            var titles: [UUID: String] = [:]
            var names: [UUID: String] = [:]
            for item in items {
                titles[item.id] = item.title
                if let behaviorId = item.behaviorId {
                    names[item.id] = behaviorNameById[behaviorId]
                }
            }
            stepTitles = titles
            behaviorNames = names
        } catch {
            // Non-fatal: rows just render without the resolved labels.
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Create

    func createRecord(
        petId: UUID,
        recordedAt: Date,
        score: Int,
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
                score: score,
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

    // MARK: - Toggle Sharing

    func toggleSharing(_ record: TrainingRecord) async {
        // Optimistic update — avoids isLoading re-render snapping the swipe closed
        guard let idx = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[idx].isShared = !record.isShared
        var updated = record
        updated.isShared = !record.isShared
        do {
            let saved = try await service.updateRecord(updated)
            records[idx] = saved
        } catch {
            records[idx] = record   // revert on failure
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
