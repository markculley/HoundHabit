import Testing
import Foundation
@testable import HabitHound

@Suite("Training plan models")
struct TrainingPlanTests {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - TrainingPlan

    @Test("TrainingPlan decodes snake_case keys from Supabase JSON")
    func trainingPlanDecodesSnakeCaseKeys() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "trainer_id": "22222222-2222-2222-2222-222222222222",
            "title": "Basic Recall",
            "description": "Foundation recall exercises",
            "created_at": "2025-01-15T10:00:00Z",
            "updated_at": "2025-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let plan = try decoder.decode(TrainingPlan.self, from: json)

        #expect(plan.id == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(plan.trainerId == UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        #expect(plan.title == "Basic Recall")
        #expect(plan.description == "Foundation recall exercises")
    }

    @Test("TrainingPlan decodes nil description")
    func trainingPlanDecodesNilDescription() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "trainer_id": "22222222-2222-2222-2222-222222222222",
            "title": "Basic Recall",
            "description": null,
            "created_at": "2025-01-15T10:00:00Z",
            "updated_at": "2025-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let plan = try decoder.decode(TrainingPlan.self, from: json)
        #expect(plan.description == nil)
    }

    // MARK: - TrainingPlanItem

    @Test("TrainingPlanItem decodes snake_case keys including sort_order")
    func trainingPlanItemDecodesSnakeCaseKeys() throws {
        let json = """
        {
            "id": "33333333-3333-3333-3333-333333333333",
            "plan_id": "44444444-4444-4444-4444-444444444444",
            "sort_order": 2,
            "title": "Step 3: Add distance",
            "description": "Move 6 feet away before cuing"
        }
        """.data(using: .utf8)!

        let item = try decoder.decode(TrainingPlanItem.self, from: json)

        #expect(item.id == UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        #expect(item.planId == UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        #expect(item.sortOrder == 2)
        #expect(item.title == "Step 3: Add distance")
    }

    // MARK: - PlanAssignment

    @Test("PlanAssignment decodes snake_case keys with non-null pet_id")
    func planAssignmentDecodesWithPetId() throws {
        let json = """
        {
            "id": "55555555-5555-5555-5555-555555555555",
            "plan_id": "66666666-6666-6666-6666-666666666666",
            "guardian_id": "77777777-7777-7777-7777-777777777777",
            "pet_id": "88888888-8888-8888-8888-888888888888",
            "assigned_at": "2025-03-01T09:00:00Z"
        }
        """.data(using: .utf8)!

        let assignment = try decoder.decode(PlanAssignment.self, from: json)

        #expect(assignment.planId == UUID(uuidString: "66666666-6666-6666-6666-666666666666"))
        #expect(assignment.guardianId == UUID(uuidString: "77777777-7777-7777-7777-777777777777"))
        #expect(assignment.petId == UUID(uuidString: "88888888-8888-8888-8888-888888888888"))
    }

    @Test("PlanAssignment decodes null pet_id as nil")
    func planAssignmentDecodesNullPetId() throws {
        let json = """
        {
            "id": "55555555-5555-5555-5555-555555555555",
            "plan_id": "66666666-6666-6666-6666-666666666666",
            "guardian_id": "77777777-7777-7777-7777-777777777777",
            "pet_id": null,
            "assigned_at": "2025-03-01T09:00:00Z"
        }
        """.data(using: .utf8)!

        let assignment = try decoder.decode(PlanAssignment.self, from: json)
        #expect(assignment.petId == nil)
    }
}
