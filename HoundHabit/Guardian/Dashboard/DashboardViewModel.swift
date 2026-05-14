import Foundation

@Observable
class DashboardViewModel {
    /// Shared with TrainingRecordDetailView so edits/deletes propagate back.
    var recordViewModel = TrainingRecordViewModel()
    var pets: [Pet] = []
    var isLoading = false
    var errorMessage: String?

    var linkedTrainer: LinkedTrainer?
    var planCount: Int = 0

    private let petService = PetService()
    private let inviteService = InviteService()
    private let planService = TrainingPlanService()

    var records: [TrainingRecord] { recordViewModel.records }

    func load() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let fetchedPets    = petService.fetchPets(guardianId: userId)
            async let fetchedTrainer = inviteService.fetchLinkedTrainer()
            async let fetchedPlans   = planService.fetchAssignedPlans()
            await recordViewModel.loadRecords()
            pets          = try await fetchedPets
            linkedTrainer = try? await fetchedTrainer
            planCount     = (try? await fetchedPlans)?.count ?? 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func petName(for petId: UUID) -> String {
        pets.first { $0.id == petId }?.name ?? "Unknown Pet"
    }
}
