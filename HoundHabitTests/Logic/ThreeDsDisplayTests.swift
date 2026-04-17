import Testing
import Foundation
@testable import HoundHabit

// MARK: - Distance.displayLabel

@Suite("Distance displayLabel")
struct DistanceDisplayTests {

    @Test("Custom case with value returns the custom string")
    func customCaseWithValueReturnsCustomString() {
        #expect(Distance.custom.displayLabel(customValue: "30 ft") == "30 ft")
    }

    @Test("Custom case with nil returns fallback 'Custom'")
    func customCaseWithNilReturnsFallback() {
        #expect(Distance.custom.displayLabel(customValue: nil) == "Custom")
    }

    @Test("Preset case returns its own label, ignoring custom value")
    func presetCaseIgnoresCustomValue() {
        #expect(Distance.armsLength.displayLabel(customValue: "ignored") == "Arm's length")
        #expect(Distance.sixFeet.displayLabel(customValue: "ignored") == "6 ft")
        #expect(Distance.twelveFeet.displayLabel(customValue: "ignored") == "12 ft")
    }
}

// MARK: - TrainingDuration.displayLabel

@Suite("TrainingDuration displayLabel")
struct TrainingDurationDisplayTests {

    @Test("Custom case with value returns the custom string")
    func customCaseWithValueReturnsCustomString() {
        #expect(TrainingDuration.custom.displayLabel(customValue: "10 seconds") == "10 seconds")
    }

    @Test("Custom case with nil returns fallback 'Custom'")
    func customCaseWithNilReturnsFallback() {
        #expect(TrainingDuration.custom.displayLabel(customValue: nil) == "Custom")
    }

    @Test("Preset case returns its own label, ignoring custom value")
    func presetCaseIgnoresCustomValue() {
        #expect(TrainingDuration.instant.displayLabel(customValue: "ignored") == "Instant")
        #expect(TrainingDuration.fiveSeconds.displayLabel(customValue: "ignored") == "5 sec")
    }
}

// MARK: - Distraction.displayLabel

@Suite("Distraction displayLabel")
struct DistractionDisplayTests {

    @Test("Custom case with value returns the custom string")
    func customCaseWithValueReturnsCustomString() {
        #expect(Distraction.custom.displayLabel(customValue: "dogs nearby") == "dogs nearby")
    }

    @Test("Custom case with nil returns fallback 'Custom'")
    func customCaseWithNilReturnsFallback() {
        #expect(Distraction.custom.displayLabel(customValue: nil) == "Custom")
    }

    @Test("Preset case returns its own label, ignoring custom value")
    func presetCaseIgnoresCustomValue() {
        #expect(Distraction.none.displayLabel(customValue: "ignored") == "None")
        #expect(Distraction.any.displayLabel(customValue: "ignored") == "Any")
    }
}

// MARK: - TrainingPlanItem label helpers

@Suite("TrainingPlanItem display label helpers")
struct TrainingPlanItemLabelTests {

    private func makeItem(
        distance: Distance, duration: TrainingDuration, distraction: Distraction,
        distanceCustom: String? = nil, durationCustom: String? = nil, distractionCustom: String? = nil
    ) -> TrainingPlanItem {
        TrainingPlanItem(
            id: UUID(), planId: UUID(), behaviorId: nil, sortOrder: 0,
            title: "Test step",
            distance: distance, duration: duration, distraction: distraction,
            distanceCustomValue: distanceCustom,
            durationCustomValue: durationCustom,
            distractionCustomValue: distractionCustom
        )
    }

    @Test("distanceLabel uses custom value when .custom is set")
    func distanceLabelUsesCustomValue() {
        let item = makeItem(distance: .custom, duration: .instant, distraction: .none, distanceCustom: "50 ft")
        #expect(item.distanceLabel == "50 ft")
    }

    @Test("distanceLabel returns preset label for preset enum")
    func distanceLabelReturnsPresetLabel() {
        let item = makeItem(distance: .armsLength, duration: .instant, distraction: .none)
        #expect(item.distanceLabel == "Arm's length")
    }

    @Test("durationLabel uses custom value when .custom is set")
    func durationLabelUsesCustomValue() {
        let item = makeItem(distance: .armsLength, duration: .custom, distraction: .none, durationCustom: "2 minutes")
        #expect(item.durationLabel == "2 minutes")
    }

    @Test("durationLabel returns preset label for preset enum")
    func durationLabelReturnsPresetLabel() {
        let item = makeItem(distance: .armsLength, duration: .fiveSeconds, distraction: .none)
        #expect(item.durationLabel == "5 sec")
    }

    @Test("distractionLabel uses custom value when .custom is set")
    func distractionLabelUsesCustomValue() {
        let item = makeItem(distance: .armsLength, duration: .instant, distraction: .custom, distractionCustom: "loud music")
        #expect(item.distractionLabel == "loud music")
    }

    @Test("distractionLabel returns preset label for preset enum")
    func distractionLabelReturnsPresetLabel() {
        let item = makeItem(distance: .armsLength, duration: .instant, distraction: .any)
        #expect(item.distractionLabel == "Any")
    }

    @Test("custom case with nil custom value falls back to 'Custom'")
    func customCaseWithNilCustomValueFallsBack() {
        let item = makeItem(distance: .custom, duration: .custom, distraction: .custom)
        #expect(item.distanceLabel == "Custom")
        #expect(item.durationLabel == "Custom")
        #expect(item.distractionLabel == "Custom")
    }
}
