import Foundation

@Observable
class GuardianPlanViewModel {
    var assignedPlans: [AssignedPlan] = []
    var items: [UUID: [TrainingPlanItem]] = [:]   // keyed by plan.id
    var isLoading = false
    var errorMessage: String?

    private let service = TrainingPlanService()

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            assignedPlans = try await service.fetchAssignedPlans()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadItems(for planId: UUID) async {
        do {
            items[planId] = try await service.fetchAssignedPlanItems(planId: planId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
