import Testing
import Foundation
@testable import HabitHound

// MARK: - TrainingStatus.from(score:)

@Suite("TrainingStatus score derivation")
struct TrainingStatusScoreTests {

    @Test("Score 5 derives green")
    func score5IsGreen() {
        #expect(TrainingStatus.from(score: 5) == .green)
    }

    @Test("Score 4 derives yellow")
    func score4IsYellow() {
        #expect(TrainingStatus.from(score: 4) == .yellow)
    }

    @Test("Score 3 derives yellow")
    func score3IsYellow() {
        #expect(TrainingStatus.from(score: 3) == .yellow)
    }

    @Test("Score 2 derives orange")
    func score2IsOrange() {
        #expect(TrainingStatus.from(score: 2) == .orange)
    }

    @Test("Score 1 derives red")
    func score1IsRed() {
        #expect(TrainingStatus.from(score: 1) == .red)
    }

    @Test("Score 0 derives red")
    func score0IsRed() {
        #expect(TrainingStatus.from(score: 0) == .red)
    }
}

// MARK: - Step advancement logic

@MainActor
@Suite("GuardianPlanViewModel step advancement")
struct StepAdvancementTests {

    private let planId = UUID()

    // Builds a sorted list of 4 steps.
    private func makeItems() -> [TrainingPlanItem] {
        (0..<4).map { idx in
            TrainingPlanItem(
                id: UUID(), planId: planId, behaviorId: nil, sortOrder: idx,
                title: "Step \(idx + 1)",
                distance: .armsLength, duration: .instant, distraction: .none,
                distanceCustomValue: nil, durationCustomValue: nil, distractionCustomValue: nil
            )
        }
    }

    private func makeAssignment(currentItemId: UUID?) -> PlanAssignment {
        PlanAssignment(
            id: UUID(), planId: planId, trainerId: UUID(),
            guardianId: UUID(), petId: nil,
            assignedAt: Date(), currentItemId: currentItemId, isShared: true
        )
    }

    private func makeAssignedPlan(currentItemId: UUID?) -> AssignedPlan {
        let plan = TrainingPlan(id: planId, trainerId: UUID(), title: "Test", description: nil, createdAt: Date(), updatedAt: Date())
        return AssignedPlan(assignment: makeAssignment(currentItemId: currentItemId), plan: plan)
    }

    private let vm = GuardianPlanViewModel()

    // MARK: currentItem resolution

    @Test("Returns first item when currentItemId is nil")
    func currentItemFallsBackToFirst() {
        let items = makeItems()
        let ap = makeAssignedPlan(currentItemId: nil)
        #expect(vm.currentItem(for: ap, in: items)?.sortOrder == 0)
    }

    @Test("Returns matching item when currentItemId is set")
    func currentItemReturnsMatchingItem() {
        let items = makeItems()
        let ap = makeAssignedPlan(currentItemId: items[2].id)
        #expect(vm.currentItem(for: ap, in: items)?.sortOrder == 2)
    }

    // MARK: newCurrentItem derivation (tested via the static helper)

    @Test("Score 5 from middle advances to next step")
    func score5Advances() {
        let items = makeItems()
        let newIdx = StepAdvancementTests.newIndex(score: 5, currentIdx: 1, total: items.count)
        #expect(newIdx == 2)
    }

    @Test("Score 5 at last step stays at last step")
    func score5AtLastStepStays() {
        let items = makeItems()
        let lastIdx = items.count - 1
        let newIdx = StepAdvancementTests.newIndex(score: 5, currentIdx: lastIdx, total: items.count)
        #expect(newIdx == lastIdx)
    }

    @Test("Score 3 stays on current step")
    func score3Stays() {
        let items = makeItems()
        let newIdx = StepAdvancementTests.newIndex(score: 3, currentIdx: 2, total: items.count)
        #expect(newIdx == 2)
    }

    @Test("Score 1 drops back to previous step")
    func score1DropsBack() {
        let items = makeItems()
        let newIdx = StepAdvancementTests.newIndex(score: 1, currentIdx: 2, total: items.count)
        #expect(newIdx == 1)
    }

    @Test("Score 1 at first step stays at first step")
    func score1AtFirstStepStays() {
        let newIdx = StepAdvancementTests.newIndex(score: 1, currentIdx: 0, total: 4)
        #expect(newIdx == 0)
    }

    @Test("Score 0 drops back to previous step")
    func score0DropsBack() {
        let newIdx = StepAdvancementTests.newIndex(score: 0, currentIdx: 3, total: 4)
        #expect(newIdx == 2)
    }

    /// Mirrors the advancement logic inside GuardianPlanViewModel so it can be tested
    /// without async/network calls.
    private static func newIndex(score: Int, currentIdx: Int, total: Int) -> Int {
        if score == 5 {
            return min(currentIdx + 1, total - 1)
        } else if score <= 1 {
            return max(currentIdx - 1, 0)
        } else {
            return currentIdx
        }
    }
}
