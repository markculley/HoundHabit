# Phase 9 / 9b: Training Plans

## Overview

Trainers create reusable training plans composed of ordered steps, where each step defines specific values for the Three D's (Distance, Duration, Distraction). Plans are assigned to linked guardians. Guardians practice the current step of each plan, enter a 0–5 rep score, and the app automatically advances, holds, or drops back their position in the plan based on the Traffic Light system. The guardian's position is persisted so they always resume exactly where they left off.

---

## UC-9.1: Trainer Creates a Plan

**Actor:** Trainer  
**Precondition:** Trainer is authenticated.

### Flow

```
Trainer                   App                        Supabase
  │                         │                            │
  │  Tap "+" on Plans tab   │                            │
  │────────────────────────▶│                            │
  │  TrainerPlanFormView     │                            │
  │  (sheet)                │                            │
  │                         │                            │
  │  Enter title +          │                            │
  │  description, tap Create│                            │
  │────────────────────────▶│                            │
  │                         │  createPlan(title, desc)   │
  │                         │───────────────────────────▶│
  │                         │  INSERT training_plans     │
  │                         │◀───────────────────────────│
  │  Plan appears in list   │                            │
  │◀────────────────────────│                            │
```

### Key Code

**`TrainerPlanFormView`** uses `PlanFormMode` (`.create` / `.edit(TrainingPlan)`) to handle both create and edit in one view. The description field is a high-level overview — the Three D's are set per-step after creation.

---

## UC-9.2: Trainer Adds and Reorders Steps

**Actor:** Trainer  
**Precondition:** Trainer is viewing a plan in `TrainerPlanDetailView`.

Each step encodes the exact Distance, Duration, and Distraction the guardian should practise. Only one of the Three D's should differ between consecutive steps (the "One Change" rule).

### Flow

```
Trainer                   App                        Supabase
  │                         │                            │
  │  Tap "Add Step"         │                            │
  │────────────────────────▶│                            │
  │  TrainerPlanItemFormView │                            │
  │  (sheet)                │                            │
  │                         │                            │
  │  Enter step name,       │                            │
  │  pick Distance /        │                            │
  │  Duration / Distraction │                            │
  │  tap Add                │                            │
  │────────────────────────▶│                            │
  │                         │  createItem(planId,        │
  │                         │    title, distance,        │
  │                         │    duration, distraction,  │
  │                         │    sortOrder)              │
  │                         │───────────────────────────▶│
  │                         │  INSERT training_plan_items│
  │                         │◀───────────────────────────│
  │  Step appears in list   │                            │
  │  (capsule tags show     │                            │
  │  Three D's values)      │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Long-press ≡ handle,   │                            │
  │  drag to new position   │                            │
  │────────────────────────▶│                            │
  │                         │  moveItems(from:to:)        │
  │                         │  ── immediate local reorder│
  │                         │  reorderItems(items)       │
  │                         │───────────────────────────▶│
  │                         │  DELETE + INSERT items     │
  │                         │  with new sort_order values│
  │                         │◀───────────────────────────│
  │  List reflects new order│                            │
  │◀────────────────────────│                            │
```

### Step Form

`TrainerPlanItemFormView` presents:
- **Step Name** — free-text field (e.g. "Sit at arm's length")
- **Three D's** — three segmented pickers (Distance / Duration / Distraction)

Step rows in `TrainerPlanDetailView` show the Three D's as small capsule tags beneath the step title.

### Reorder Implementation

Drag reorder uses `.onMove` on the `ForEach` — always active, no `EditButton` mode toggle needed. A `≡` drag handle icon on each row signals draggability.

`moveItems` does an optimistic in-memory reorder before the async call, preventing the list from snapping back during the network round-trip. On failure it reloads from Supabase to recover consistent state.

`reorderItems` in the service uses delete + re-insert (not per-row UPDATE) to keep `sort_order` values contiguous:

```swift
func moveItems(in planId: UUID, from source: IndexSet, to destination: Int) async {
    items[planId, default: []].move(fromOffsets: source, toOffset: destination)
    for idx in items[planId, default: []].indices {
        items[planId]![idx].sortOrder = idx
    }
    do {
        try await service.reorderItems(items[planId, default: []])
    } catch {
        errorMessage = error.localizedDescription
        await loadItems(for: planId)
    }
}
```

---

## UC-9.3: Trainer Assigns a Plan to a Guardian

**Actor:** Trainer  
**Precondition:** At least one active trainer-guardian link exists.

### Flow

```
Trainer                   App                        Supabase
  │                         │                            │
  │  Tap "Assign"           │                            │
  │────────────────────────▶│                            │
  │  AssignPlanSheet (sheet │                            │
  │  with NavigationStack)  │                            │
  │                         │  fetchLinkedGuardians()    │
  │                         │───────────────────────────▶│
  │                         │◀───────────────────────────│
  │  Guardian picker shown  │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Select guardian        │                            │
  │────────────────────────▶│                            │
  │                         │  fetchPets(guardianId)     │
  │                         │───────────────────────────▶│
  │                         │◀───────────────────────────│
  │  Pet picker shown       │                            │
  │  (optional)             │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Tap "Assign"           │                            │
  │────────────────────────▶│                            │
  │                         │  assignPlan(planId,        │
  │                         │    guardianId, petId)      │
  │                         │───────────────────────────▶│
  │                         │  INSERT plan_assignments   │
  │                         │  (current_item_id = NULL)  │
  │                         │◀───────────────────────────│
  │  "Assigned To" section  │                            │
  │  shows guardian + date  │                            │
  │◀────────────────────────│                            │
```

`current_item_id` starts as `NULL` — the guardian begins at the first step on their first practice session.

### RLS

`plan_assignments` INSERT policy checks both that the plan belongs to the trainer (`trainer_id = auth.uid()`) and that an active `trainer_guardian_links` row exists. The `trainer_id` column is stored directly on `plan_assignments` to avoid a recursive RLS subquery back to `training_plans`.

### Duplicate Assignment

The `UNIQUE(plan_id, guardian_id)` constraint prevents assigning the same plan twice. `AssignSheetViewModel` catches the Postgres error and surfaces: *"This guardian is already assigned to this plan."*

---

## UC-9.4: Guardian Views Assigned Plans

**Actor:** Guardian  
**Precondition:** At least one plan has been assigned to the guardian.

### Flow

```
Guardian                  App                        Supabase
  │                         │                            │
  │  Tap "Plans" tab        │                            │
  │────────────────────────▶│                            │
  │                         │  fetchAssignedPlans()      │
  │                         │───────────────────────────▶│
  │                         │  SELECT plan_assignments   │
  │                         │  WHERE guardian_id=?       │
  │                         │  + SELECT training_plans   │
  │                         │  WHERE id IN (planIds)     │
  │                         │◀───────────────────────────│
  │  Plan list shown        │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Tap a plan             │                            │
  │────────────────────────▶│                            │
  │                         │  fetchAssignedPlanItems    │
  │                         │    (planId)                │
  │                         │───────────────────────────▶│
  │                         │  SELECT training_plan_items│
  │                         │  WHERE plan_id=?           │
  │                         │  ORDER BY sort_order ASC   │
  │                         │◀───────────────────────────│
  │  Steps shown; current   │                            │
  │  step highlighted green │                            │
  │  "Practice This Step"   │                            │
  │  button shown           │                            │
  │◀────────────────────────│                            │
```

`GuardianPlanDetailView` resolves the current step via `GuardianPlanViewModel.currentItem(for:in:)`:
- If `currentItemId` is set → show that step as current
- If `currentItemId` is `nil` (first visit) → default to the first step (`sort_order == 0`)

### Dashboard Integration

`DashboardViewModel.load()` fetches `fetchAssignedPlans().count` alongside badges and trainer info. The dashboard "Training Plans" section shows:
- A tappable `"X plans assigned"` button that switches to the Plans tab (tag 3) via a `switchToPlansTab` closure passed from `GuardianTabView`
- `"No plans assigned yet."` when count is zero

---

## UC-9.5: Guardian Practises a Step (Traffic Light Flow)

**Actor:** Guardian  
**Precondition:** Guardian is viewing a plan detail with a current step.

This is the core loop described in the Training Prototype. The guardian performs 5 repetitions, enters how many succeeded (0–5), and the app computes the Traffic Light status and automatically advances their position in the plan.

### Flow

```
Guardian                  App                        Supabase
  │                         │                            │
  │  Tap "Practice Step N"  │                            │
  │────────────────────────▶│                            │
  │  TrainingRecordFormView  │                            │
  │  (sheet, plan context)  │                            │
  │  Three D's pre-filled   │                            │
  │  and locked from step   │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Adjust score 0–5       │                            │
  │  (status shown live)    │                            │
  │  Add optional notes     │                            │
  │  Tap "Log"              │                            │
  │────────────────────────▶│                            │
  │                         │  createRecord(             │
  │                         │    score, plan_item_id,    │
  │                         │    distance, duration,     │
  │                         │    distraction, ...)       │
  │                         │  status = from(score:)     │
  │                         │───────────────────────────▶│
  │                         │  INSERT training_records   │
  │                         │◀───────────────────────────│
  │                         │                            │
  │                         │  advanceCurrentStep(       │
  │                         │    assignment, score,      │
  │                         │    items)                  │
  │                         │  ── compute new step       │
  │                         │  updateCurrentItem(        │
  │                         │    assignmentId, itemId)   │
  │                         │───────────────────────────▶│
  │                         │  UPDATE plan_assignments   │
  │                         │  SET current_item_id=?     │
  │                         │◀───────────────────────────│
  │  Advancement alert      │                            │
  │  shown with message     │                            │
  │◀────────────────────────│                            │
  │  Plan detail refreshed  │                            │
  │  with new current step  │                            │
  │◀────────────────────────│                            │
```

### Traffic Light — Score to Status Mapping

| Score | Status | Action |
|-------|--------|--------|
| 5 / 5 | Green  | Advance to next step |
| 3–4 / 5 | Yellow | Stay on current step |
| 2 / 5 | Orange | Stay on current step |
| 0–1 / 5 | Red  | Drop back to previous step |

```swift
static func from(score: Int) -> TrainingStatus {
    switch score {
    case 5:     return .green
    case 3, 4:  return .yellow
    case 2:     return .orange
    default:    return .red
    }
}
```

### Advancement Logic

```swift
// In GuardianPlanViewModel.advanceCurrentStep(assignedPlan:score:planItems:)
if score == 5 {
    newIdx = min(currentIdx + 1, sorted.count - 1)  // advance; clamp at last step
} else if score <= 1 {
    newIdx = max(currentIdx - 1, 0)                  // drop back; clamp at first step
} else {
    newIdx = currentIdx                              // stay
}
```

`current_item_id` on `plan_assignments` is always written after a plan-linked session — even on "stay" — so that a first-session guardian (where `currentItemId` was `nil`) gets pinned to step 1 immediately.

### Score UX in TrainingRecordFormView

For plan-linked sessions (`planItem` is provided):
- The Three D's section is **read-only** (values locked from the step)
- The "Reps out of 5" `Stepper` replaces the old manual status picker
- The derived status (coloured circle + label) updates live as the score changes
- A footer line explains what will happen: *"Green — ready to advance to the next step."*

For standalone sessions (`planItem` is nil):
- The Three D's section is **editable**
- The same score stepper is shown (status derived the same way)

### Advancement Feedback Messages

| Situation | Message |
|-----------|---------|
| Score 5, not at last step | *"Great work! Moving to step N: [title]."* |
| Score 5, already at last step | *"Amazing — you've mastered all the steps in this plan!"* |
| Score 2–4 | *"Good progress! Keep practicing step N: [title]."* |
| Score 0–1, not at first step | *"Let's build some confidence on step N: [title]."* |
| Score 0–1, already at first step | *"Keep working on step N. You've got this!"* |

---

## Data Model

```swift
struct TrainingPlan: Codable, Identifiable, Hashable {
    let id: UUID
    let trainerId: UUID      // "trainer_id"
    var title: String
    var description: String?
    let createdAt: Date      // "created_at"
    let updatedAt: Date      // "updated_at"
}

struct TrainingPlanItem: Codable, Identifiable, Hashable {
    let id: UUID
    let planId: UUID             // "plan_id"
    var sortOrder: Int           // "sort_order"
    var title: String
    var distance: Distance       // "distance"
    var duration: TrainingDuration  // "duration"
    var distraction: Distraction // "distraction"
}

struct PlanAssignment: Codable, Identifiable, Hashable {
    let id: UUID
    let planId: UUID         // "plan_id"
    let trainerId: UUID      // "trainer_id" — stored to avoid recursive RLS
    let guardianId: UUID     // "guardian_id"
    let petId: UUID?         // "pet_id" — nullable
    let assignedAt: Date     // "assigned_at"
    var currentItemId: UUID? // "current_item_id" — the Memory Bank pointer; nil = not yet started
}

// training_records gains two new fields:
// var score: Int           — 0–5 rep count; status is derived, not manually set
// var planItemId: UUID?    // "plan_item_id" — nil for standalone sessions
```

`AssignedPlan` is a join result (not a DB row) computed by `TrainingPlanService`:

```swift
struct AssignedPlan: Identifiable, Hashable {
    var id: UUID { assignment.id }
    var assignment: PlanAssignment   // var — updated in-memory after step advancement
    let plan: TrainingPlan
}
```

---

## Architecture Notes

| Concern | Decision |
|---------|----------|
| Trainer vs Guardian ViewModels | Separate — `TrainerPlanViewModel` and `GuardianPlanViewModel`. Different mutation surface, different fetch logic. |
| `AssignedPlan` placement | Lives in `TrainingPlanService.swift`, not `Core/Models/` — it's a join result, not a direct DB row. Follows `LinkedGuardian` pattern in `InviteService.swift`. |
| Assign sheet navigation | Presented as `.sheet` with own `NavigationStack` — avoids mixing `navigationDestination` styles in the trainer's nav stack. |
| Reorder atomicity | Delete + re-insert is not transactional. On failure the app reloads from Supabase. Acceptable for MVP. |
| `trainer_id` on `plan_assignments` | Added to avoid infinite RLS recursion: `training_plans` policy checked `plan_assignments`, which checked back to `training_plans`. |
| Status derivation | `TrainingStatus.from(score:)` is the single source of truth — called by both `TrainingRecordService` (on write) and `TrainingRecordFormView` (for live preview). Manual status selection has been removed entirely. |
| In-memory advancement | After `updateCurrentItem` succeeds, `GuardianPlanViewModel` mutates `assignedPlans[idx].assignment.currentItemId` directly so `GuardianPlanDetailView` re-renders without a full reload. |
| `currentItemId` always written | Even a "stay" outcome after the first session sets `currentItemId` (from nil → step 0), ensuring the Memory Bank is initialised on the very first practice. |

---

## RLS Summary

| Table | Policy | Rule |
|-------|--------|------|
| `training_plans` | Trainer manages own | `trainer_id = auth.uid()` |
| `training_plans` | Guardian reads assigned | Assignment row exists for guardian |
| `training_plan_items` | Trainer manages own | Plan's `trainer_id = auth.uid()` |
| `training_plan_items` | Guardian reads assigned | Assignment row exists for guardian |
| `plan_assignments` | Trainer reads/deletes | `trainer_id = auth.uid()` (direct — no subquery) |
| `plan_assignments` | Trainer inserts | `trainer_id = auth.uid()` + active link to guardian |
| `plan_assignments` | Guardian reads own | `guardian_id = auth.uid()` |
| `plan_assignments` | Guardian updates `current_item_id` | `guardian_id = auth.uid()` |

---

## Edge Cases

| Scenario | Behaviour |
|----------|-----------|
| Plan assigned twice to same guardian | Postgres `UNIQUE` constraint throws; app shows "already assigned" message |
| Guardian unlinked after assignment | Plan remains visible (assignment row persists); trainer can delete assignment manually |
| Plan deleted by trainer | `ON DELETE CASCADE` removes all items and assignments |
| Guardian has no plans | "No plans assigned yet." in both Plans tab and dashboard |
| Reorder network failure | In-memory state reverted by reloading items from Supabase |
| Guardian at last step scores green | `min(currentIdx + 1, sorted.count - 1)` clamps — stays at last step, shows "mastered all steps" message |
| Guardian at first step scores red | `max(currentIdx - 1, 0)` clamps — stays at first step, shows encouragement message |
| `currentItemId` references a deleted item | `ON DELETE SET NULL` resets pointer to nil; `currentItem(for:in:)` falls back to the first step |
| Standalone session (no plan context) | `planItemId` is nil, Three D's are editable, no advancement logic runs |

---

## Test Flows

1. **Create plan**: Sign in as trainer → Plans → "+" → enter title and description → Create → plan appears in list.
2. **Add steps with Three D's**: Tap plan → Add Step → enter step name → set Distance/Duration/Distraction via segmented pickers → Add → step appears with capsule tags showing the Three D's values.
3. **Edit step**: Swipe left on a step → Edit → change a D's value → Save → capsule tags update in list.
4. **Reorder steps**: Long-press `≡` handle on a row → drag to new position → navigate away and back → order persists in Supabase.
5. **Assign plan**: Tap "Assign" → select guardian → optionally select pet → tap Assign → "Assigned To" section shows guardian name and date.
6. **Duplicate assignment**: Assign same plan to same guardian again → "already assigned" error shown.
7. **Guardian views plan**: Sign in as guardian → Plans tab → plan listed → tap plan → steps shown with Three D's tags; first step highlighted green as current.
8. **Practice step — green**: Tap "Practice Step 1" → score stepper shows 5/5 → footer reads "Green — ready to advance" → tap Log → advancement alert: "Moving to step 2" → plan detail now highlights step 2.
9. **Practice step — stay**: Score 3/5 → footer reads "Yellow — keep practicing" → tap Log → step unchanged → advancement alert confirms staying on same step.
10. **Practice step — red**: Score 1/5 → footer reads "Red — we'll drop back" → tap Log → advancement alert: "Let's build confidence on step 1" → plan detail drops back to step 1.
11. **Clamp at last step**: Advance to last step, score 5 again → alert: "Amazing — you've mastered all the steps!" → step unchanged.
12. **Memory bank**: Log a session, close the app, reopen → Plans tab → plan detail → same step is still highlighted as current.
13. **Standalone session**: Guardian logs a session from the Log tab (not via a plan) → score stepper shown → Three D's editable → `plan_item_id` is null in Supabase.
14. **Dashboard count**: Guardian home screen → "Training Plans" section shows "1 plan assigned" → tap → switches to Plans tab.
