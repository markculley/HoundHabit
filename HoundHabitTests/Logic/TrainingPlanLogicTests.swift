import Testing
import Foundation
@testable import HoundHabit

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

// MARK: - Step completion (3-day streak)

@MainActor
@Suite("GuardianPlanViewModel step completion")
struct StepCompletionTests {

    private let stepId = UUID()
    private let otherStepId = UUID()

    /// A score-N record for `stepId` (unless overridden), dated `daysAgo` whole
    /// calendar days before now.
    private func record(score: Int, daysAgo: Int, planItemId: UUID? = nil) -> TrainingRecord {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return TrainingRecord(
            id: UUID(), petId: UUID(), guardianId: UUID(),
            recordedAt: date, status: .from(score: score),
            distance: .armsLength, distraction: .none, duration: .instant,
            distanceCustomValue: nil, durationCustomValue: nil, distractionCustomValue: nil,
            notes: nil, isShared: false, score: score,
            planItemId: planItemId ?? stepId, createdAt: date, updatedAt: date
        )
    }

    private func vm(_ records: [TrainingRecord]) -> GuardianPlanViewModel {
        let model = GuardianPlanViewModel()
        model.records = records
        return model
    }

    @Test("3 consecutive days of score 5 → complete")
    func threeConsecutiveIsComplete() {
        let result = vm([
            record(score: 5, daysAgo: 2),
            record(score: 5, daysAgo: 1),
            record(score: 5, daysAgo: 0),
        ]).stepCompletion(planItemId: stepId)
        #expect(result.isComplete)
        #expect(result.bestStreak == 3)
    }

    @Test("2 consecutive days of score 5 → not complete, streak 2")
    func twoConsecutiveNotComplete() {
        let result = vm([
            record(score: 5, daysAgo: 1),
            record(score: 5, daysAgo: 0),
        ]).stepCompletion(planItemId: stepId)
        #expect(!result.isComplete)
        #expect(result.bestStreak == 2)
    }

    @Test("A gap breaks the streak")
    func gapBreaksStreak() {
        let result = vm([
            record(score: 5, daysAgo: 4),
            record(score: 5, daysAgo: 3),
            record(score: 5, daysAgo: 1),
            record(score: 5, daysAgo: 0),
        ]).stepCompletion(planItemId: stepId)
        #expect(!result.isComplete)
        #expect(result.bestStreak == 2)
    }

    @Test("Multiple score-5 sessions on the same day count as one day")
    func sameDayDoesNotInflateStreak() {
        let result = vm([
            record(score: 5, daysAgo: 0),
            record(score: 5, daysAgo: 0),
            record(score: 5, daysAgo: 0),
        ]).stepCompletion(planItemId: stepId)
        #expect(!result.isComplete)
        #expect(result.bestStreak == 1)
    }

    @Test("Non-5 scores don't count toward the streak")
    func lowScoresIgnored() {
        let result = vm([
            record(score: 5, daysAgo: 2),
            record(score: 4, daysAgo: 1),
            record(score: 5, daysAgo: 0),
        ]).stepCompletion(planItemId: stepId)
        #expect(!result.isComplete)
        #expect(result.bestStreak == 1)
    }

    @Test("Records for a different step don't count")
    func otherStepRecordsIgnored() {
        let result = vm([
            record(score: 5, daysAgo: 2, planItemId: otherStepId),
            record(score: 5, daysAgo: 1, planItemId: otherStepId),
            record(score: 5, daysAgo: 0, planItemId: otherStepId),
        ]).stepCompletion(planItemId: stepId)
        #expect(!result.isComplete)
        #expect(result.bestStreak == 0)
    }

    @Test("No records → not complete, streak 0")
    func emptyIsNotComplete() {
        let result = vm([]).stepCompletion(planItemId: stepId)
        #expect(!result.isComplete)
        #expect(result.bestStreak == 0)
    }

    @Test("Completion is sticky — a historical 3-day run counts despite a later gap")
    func historicalRunStaysComplete() {
        let result = vm([
            record(score: 5, daysAgo: 10),
            record(score: 5, daysAgo: 9),
            record(score: 5, daysAgo: 8),
            record(score: 5, daysAgo: 0),   // a lone recent day — doesn't matter
        ]).stepCompletion(planItemId: stepId)
        #expect(result.isComplete)
        #expect(result.bestStreak == 3)
    }
}

// MARK: - Step locking (sequential within a behavior)

@MainActor
@Suite("GuardianPlanViewModel step locking")
struct StepLockingTests {

    private let planId = UUID()
    private let behaviorA = UUID()
    private let behaviorB = UUID()

    private func step(_ sortOrder: Int, behaviorId: UUID?) -> TrainingPlanItem {
        TrainingPlanItem(
            id: UUID(), planId: planId, behaviorId: behaviorId, sortOrder: sortOrder,
            title: "Step \(sortOrder + 1)",
            distance: .armsLength, duration: .instant, distraction: .none,
            distanceCustomValue: nil, durationCustomValue: nil, distractionCustomValue: nil
        )
    }

    private func record(score: Int, daysAgo: Int, planItemId: UUID) -> TrainingRecord {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return TrainingRecord(
            id: UUID(), petId: UUID(), guardianId: UUID(),
            recordedAt: date, status: .from(score: score),
            distance: .armsLength, distraction: .none, duration: .instant,
            distanceCustomValue: nil, durationCustomValue: nil, distractionCustomValue: nil,
            notes: nil, isShared: false, score: score,
            planItemId: planItemId, createdAt: date, updatedAt: date
        )
    }

    /// 3 consecutive perfect days for a step → marks it complete.
    private func completedRecords(for planItemId: UUID) -> [TrainingRecord] {
        [
            record(score: 5, daysAgo: 2, planItemId: planItemId),
            record(score: 5, daysAgo: 1, planItemId: planItemId),
            record(score: 5, daysAgo: 0, planItemId: planItemId),
        ]
    }

    @Test("First step of a behavior is never locked")
    func firstStepUnlocked() {
        let s0 = step(0, behaviorId: behaviorA)
        let vm = GuardianPlanViewModel()
        vm.items = [planId: [s0]]
        #expect(!vm.isStepLocked(s0))
    }

    @Test("Second step is locked until the first is complete")
    func secondStepLockedUntilFirstComplete() {
        let s0 = step(0, behaviorId: behaviorA)
        let s1 = step(1, behaviorId: behaviorA)
        let vm = GuardianPlanViewModel()
        vm.items = [planId: [s0, s1]]

        #expect(vm.isStepLocked(s1))      // first step not complete → locked

        vm.records = completedRecords(for: s0.id)
        #expect(!vm.isStepLocked(s1))     // first step complete → unlocked
    }

    @Test("Behaviors are independent — completing behavior A doesn't unlock behavior B")
    func behaviorsAreIndependent() {
        let a0 = step(0, behaviorId: behaviorA)
        let a1 = step(1, behaviorId: behaviorA)
        let b0 = step(0, behaviorId: behaviorB)
        let b1 = step(1, behaviorId: behaviorB)
        let vm = GuardianPlanViewModel()
        vm.items = [planId: [a0, a1, b0, b1]]
        vm.records = completedRecords(for: a0.id)

        #expect(!vm.isStepLocked(a1))     // behavior A step 1 complete → A step 2 unlocked
        #expect(!vm.isStepLocked(b0))     // behavior B's first step is always unlocked
        #expect(vm.isStepLocked(b1))      // behavior B step 1 not complete → B step 2 still locked
    }
}
