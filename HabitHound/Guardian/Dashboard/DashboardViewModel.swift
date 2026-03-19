import Foundation

@Observable
class DashboardViewModel {
    /// Shared with TrainingRecordDetailView so edits/deletes propagate back to the feed.
    var recordViewModel = TrainingRecordViewModel()
    var pets: [Pet] = []
    var isLoading = false
    var errorMessage: String?

    private let petService = PetService()

    var records: [TrainingRecord] { recordViewModel.records }

    func load() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let fetchedPets = petService.fetchPets(guardianId: userId)
            await recordViewModel.loadRecords()
            pets = try await fetchedPets
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func petName(for petId: UUID) -> String {
        pets.first { $0.id == petId }?.name ?? "Unknown Pet"
    }
}
