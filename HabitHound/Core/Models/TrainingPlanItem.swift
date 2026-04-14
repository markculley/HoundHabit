import Foundation

struct TrainingPlanItem: Codable, Identifiable, Hashable {
    let id: UUID
    let planId: UUID
    var behaviorId: UUID?
    var sortOrder: Int
    var title: String
    var distance: Distance
    var duration: TrainingDuration
    var distraction: Distraction
    var distanceCustomValue: String?
    var durationCustomValue: String?
    var distractionCustomValue: String?

    enum CodingKeys: String, CodingKey {
        case id
        case planId                 = "plan_id"
        case behaviorId             = "behavior_id"
        case sortOrder              = "sort_order"
        case title
        case distance
        case duration
        case distraction
        case distanceCustomValue    = "distance_custom"
        case durationCustomValue    = "duration_custom"
        case distractionCustomValue = "distraction_custom"
    }
}

// MARK: - Display labels (resolves .custom to the stored free-text value)

extension TrainingPlanItem {
    var distanceLabel: String    { distance.displayLabel(customValue: distanceCustomValue) }
    var durationLabel: String    { duration.displayLabel(customValue: durationCustomValue) }
    var distractionLabel: String { distraction.displayLabel(customValue: distractionCustomValue) }
}
