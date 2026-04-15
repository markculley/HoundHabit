# Phase 9 / 12a: Training Plans

## Overview

Trainers create reusable training plans composed of **Behaviors**, where each Behavior contains an ordered list of **Steps**. Each step defines specific values for the Three D's (Distance, Duration, Distraction) — with optional free-text custom values for each D. Plans are assigned to linked guardians. Guardians practice the current step of each plan, enter a 0–5 rep score, and the app automatically advances, holds, or drops back their position in the plan based on the Traffic Light system. The guardian's position is persisted so they always resume exactly where they left off.

### Object Hierarchy

```
TrainingPlan
  └── Behavior  (e.g. "Sit", "Recall")
        └── Step (TrainingPlanItem)  — title + Three D's values
```

A plan must have at least one Behavior, and each Behavior must have at least one Step, before the plan can be assigned to a guardian.

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

**`TrainerPlanFormView`** uses `PlanFormMode` (`.create` / `.edit(TrainingPlan)`) to handle both create and edit in one view. The description field is a high-level overview — Behaviors and their Three D's steps are added after creation.

---

## UC-9.2: Trainer Adds Behaviors to a Plan

**Actor:** Trainer  
**Precondition:** Trainer is viewing a plan in `TrainerPlanDetailView`.

Behaviors are the top-level groupings within a plan — one per skill the guardian will train (e.g. "Sit", "Down", "Recall"). Each Behavior acts as its own progression sequence with its own ordered steps.

### Flow

```
Trainer                   App                        Supabase
  │                         │                            │
  │  Tap "Add Behavior"     │                            │
  │────────────────────────▶│                            │
  │  TrainerBehaviorFormView │                            │
  │  (sheet)                │                            │
  │  Name field + 12        │                            │
  │  suggested names shown  │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Type name or tap a     │                            │
  │  suggestion, tap Add    │                            │
  │────────────────────────▶│                            │
  │                         │  createBehavior(planId,    │
  │                         │    name, sortOrder)        │
  │                         │───────────────────────────▶│
  │                         │  INSERT behaviors          │
  │                         │◀───────────────────────────│
  │  Behavior appears in    │                            │
  │  Behaviors list         │                            │
  │◀────────────────────────│                            │
```

### Behavior Name Suggestions

`TrainerBehaviorFormView` surfaces 12 common dog training behaviors. Tapping one fills the field; the trainer can also type a custom name.

| Suggestion | | | |
|---|---|---|---|
| Sit | Down | Leave It | Drop It |
| Stand | Wait/Stay | Walk | Touch |
| Go to Mat | Recall | Off | Attention |

Selecting a suggestion highlights it with a checkmark. The "Add" button stays disabled until the field is non-empty.

### Reorder / Delete

Behaviors in `TrainerPlanDetailView` support drag-to-reorder (`.onMove`) and swipe-to-delete. Deleting a behavior **cascades** to all its steps via the DB `ON DELETE CASCADE` on `training_plan_items.behavior_id`.

---

## UC-9.3: Trainer Adds Steps to a Behavior

**Actor:** Trainer  
**Precondition:** Trainer is viewing a behavior in `TrainerBehaviorDetailView`.

Each step encodes the exact Distance, Duration, and Distraction the guardian should practise. Only one of the Three D's should differ between consecutive steps (the "One Change" rule).

### Flow

```
Trainer                   App                        Supabase
  │                         │                            │
  │  Tap behavior in list   │                            │
  │────────────────────────▶│                            │
  │  TrainerBehaviorDetailView│                           │
  │  (NavigationLink push)  │                            │
  │                         │  loadItems(for: behavior)  │
  │                         │───────────────────────────▶│
  │                         │  SELECT training_plan_items│
  │                         │  WHERE behavior_id=?       │
  │                         │◀───────────────────────────│
  │  Steps list shown       │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Tap "Add Step"         │                            │
  │────────────────────────▶│                            │
  │  TrainerPlanItemFormView │                            │
  │  (sheet)                │                            │
  │                         │                            │
  │  Enter step name,       │                            │
  │  pick Distance /        │                            │
  │  Duration / Distraction │                            │
  │  (optionally choose     │                            │
  │  "Custom" and type a    │                            │
  │  free-text value)       │                            │
  │  tap Add                │                            │
  │────────────────────────▶│                            │
  │                         │  createItem(planId,        │
  │                         │    behaviorId,             │
  │                         │    title, distance,        │
  │                         │    duration, distraction,  │
  │                         │    distanceCustomValue?,   │
  │                         │    durationCustomValue?,   │
  │                         │    distractionCustomValue?,│
  │                         │    sortOrder)              │
  │                         │───────────────────────────▶│
  │                         │  INSERT training_plan_items│
  │                         │◀───────────────────────────│
  │  Step appears in list   │                            │
  │  (capsule tags show     │                            │
  │  Three D's values)      │                            │
  │◀────────────────────────│                            │
```

### Step Form

`TrainerPlanItemFormView` presents:
- **Step Name** — free-text field (e.g. "Sit at arm's length")
- **Three D's** — three segmented pickers with a **Custom** option on each:

| Dimension | Preset values | Custom |
|-----------|--------------|--------|
| Distance | Arm's length · 6 ft · 12 ft · 20 ft · 20+ ft | `.custom` |
| Duration | Instant · 5 sec · 5+ sec | `.custom` |
| Distraction | None · Any | `.custom` |

When `.custom` is selected on a picker, a free-text `TextField` slides in below it. The "Add"/"Save" button stays disabled until the custom field is non-empty.

Custom values are stored in dedicated columns (`distance_custom`, `duration_custom`, `distraction_custom`); the preset enum value is stored as `"custom"` in the main column. Display resolves via:

```swift
func displayLabel(customValue: String?) -> String {
    self == .custom ? (customValue ?? "Custom") : label
}
```

Step rows in `TrainerBehaviorDetailView` show the Three D's as small capsule tags beneath the step title. Step `sortOrder` is scoped **within its Behavior** (0, 1, 2… per behavior, not plan-global).

### Reorder Implementation

Drag reorder uses `.onMove` on the `ForEach` — always active, no `EditButton` mode toggle needed. A `≡` drag handle icon on each row signals draggability.

`moveItems(in:behaviorId:from:to:)` does an optimistic in-memory reorder before the async call. The ViewModel merges the reordered behavior-scoped list back into the plan-level `items[planId]` dictionary on completion.

`reorderItems` in the service uses delete + re-insert (not per-row UPDATE) to keep `sort_order` values contiguous:

```swift
func moveItems(in planId: UUID, behaviorId: UUID?, from source: IndexSet, to destination: Int) async {
    var behaviorItems = items[planId, default: []].filter { $0.behaviorId == behaviorId }
    behaviorItems.move(fromOffsets: source, toOffset: destination)
    for idx in behaviorItems.indices { behaviorItems[idx].sortOrder = idx }
    var allItems = items[planId, default: []].filter { $0.behaviorId != behaviorId }
    allItems.append(contentsOf: behaviorItems)
    items[planId] = allItems
    do {
        try await service.reorderItems(behaviorItems)
    } catch {
        errorMessage = error.localizedDescription
        await loadItems(for: planId)
    }
}
```

---

## UC-9.4: Trainer Assigns a Plan to a Guardian

**Actor:** Trainer  
**Precondition:** At least one active trainer-guardian link exists.

### Assignment Guard

`TrainerPlanDetailView` blocks the "Assign" button and shows a warning if the plan isn't ready:

| Condition | Message shown |
|-----------|--------------|
| No behaviors | "Add at least one behavior before assigning." |
| One behavior has no steps | `"[BehaviorName]" has no steps. Each behavior needs at least one step.` |
| Multiple behaviors have no steps | "N behaviors have no steps. Each behavior needs at least one step." |

### Flow

```
Trainer                   App                        Supabase
  │                         │                            │
  │  Tap "Assign to         │                            │
  │  Guardian…"             │                            │
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

`current_item_id` starts as `NULL` — the guardian begins at the first step of the first behavior on their first practice session.

### RLS

`plan_assignments` INSERT policy checks both that the plan belongs to the trainer (`trainer_id = auth.uid()`) and that an active `trainer_guardian_links` row exists. The `trainer_id` column is stored directly on `plan_assignments` to avoid a recursive RLS subquery back to `training_plans`.

### Duplicate Assignment

The `UNIQUE(plan_id, guardian_id)` constraint prevents assigning the same plan twice. `AssignSheetViewModel` catches the Postgres error and surfaces: *"This guardian is already assigned to this plan."*

---

## UC-9.5: Guardian Views Assigned Plans

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
  │                         │    (planId) [parallel]     │
  │                         │  fetchBehaviors(planId)    │
  │                         │    [parallel]              │
  │                         │───────────────────────────▶│
  │                         │  SELECT training_plan_items│
  │                         │  WHERE plan_id=?           │
  │                         │  SELECT behaviors          │
  │                         │  WHERE plan_id=?           │
  │                         │◀───────────────────────────│
  │  Steps shown, grouped   │                            │
  │  by Behavior sections;  │                            │
  │  current step           │                            │
  │  highlighted green      │                            │
  │◀────────────────────────│                            │
```

### Behavior-Grouped Layout

`GuardianPlanDetailView` renders one `List` section per Behavior. Steps within each section are shown in their `sortOrder` sequence. The current step (green dot + play icon) may appear in any behavior's section.

```
┌─ Basic Recall ──────────────────────────────────┐
│ ●  1. Sit at arm's length  Arm's length · Instant · None   ▶│
│ ○  2. Sit at 6 feet        6 ft · Instant · None           ℹ│
└─────────────────────────────────────────────────┘
┌─ Down ──────────────────────────────────────────┐
│ ○  1. Down at arm's length  Arm's length · 5 sec · None    ℹ│
└─────────────────────────────────────────────────┘
```

**Legacy / unbound items** (steps with no `behavior_id`) appear in an "Other Steps" section as a backward-compatibility fallback.

### Current Step Resolution

`GuardianPlanViewModel.currentItem(for:in:)` resolves across the full flat `items` list regardless of behavior grouping:
- If `currentItemId` is set → show that step as current
- If `currentItemId` is `nil` (first visit) → default to the first step by `sort_order` across all behaviors

### Dashboard Integration

`DashboardViewModel.load()` fetches `fetchAssignedPlans().count` alongside badges and trainer info. The dashboard "Training Plans" section shows:
- A tappable `"X plans assigned"` button that switches to the Plans tab (tag 3) via a `switchToPlansTab` closure passed from `GuardianTabView`
- `"No plans assigned yet."` when count is zero

---

## UC-9.6: Guardian Practises a Step (Traffic Light Flow)

**Actor:** Guardian  
**Precondition:** Guardian is viewing a plan detail with a current step.

This is the core loop described in the Training Prototype. The guardian performs 5 repetitions, enters how many succeeded (0–5), and the app computes the Traffic Light status and automatically advances their position in the plan.

### Flow

```
Guardian                  App                        Supabase
  │                         │                            │
  │  Tap current step       │                            │
  │  (green ▶ button)       │                            │
  │────────────────────────▶│                            │
  │  TrainingRecordFormView  │                            │
  │  (sheet, plan context)  │                            │
  │  Three D's pre-filled   │                            │
  │  and locked from step   │                            │
  │  (custom values shown   │                            │
  │  as free text if set)   │                            │
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
  │                         │    distraction,            │
  │                         │    distanceCustomValue?,   │
  │                         │    durationCustomValue?,   │
  │                         │    distractionCustomValue?,│
  │                         │    ...)                    │
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

Step advancement is global across all behaviors — `items` is a flat sorted list. A guardian progresses from the last step of Behavior A into the first step of Behavior B.

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
- The Three D's section is **read-only** (values locked from the step; custom values shown as their free-text strings)
- The "Reps out of 5" `Stepper` replaces the old manual status picker
- The derived status (coloured circle + label) updates live as the score changes
- A footer line explains what will happen: *"Green — ready to advance to the next step."*

For standalone sessions (`planItem` is nil):
- The Three D's section is **editable** (all pickers including `.custom`)
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

struct Behavior: Codable, Identifiable, Hashable {
    let id: UUID
    let planId: UUID         // "plan_id" — FK → training_plans ON DELETE CASCADE
    var name: String
    var sortOrder: Int       // "sort_order" — scoped within the plan
    let createdAt: Date      // "created_at"
}

struct TrainingPlanItem: Codable, Identifiable, Hashable {
    let id: UUID
    let planId: UUID             // "plan_id"
    var behaviorId: UUID?        // "behavior_id" — nil = legacy/unbound step
    var sortOrder: Int           // "sort_order" — scoped within the behavior
    var title: String
    var distance: Distance       // preset or .custom
    var duration: TrainingDuration
    var distraction: Distraction
    var distanceCustomValue: String?    // "distance_custom" — non-nil when distance == .custom
    var durationCustomValue: String?    // "duration_custom"
    var distractionCustomValue: String? // "distraction_custom"
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
```

`AssignedPlan` is a join result (not a DB row) computed by `TrainingPlanService`:

```swift
struct AssignedPlan: Identifiable, Hashable {
    var id: UUID { assignment.id }
    var assignment: PlanAssignment   // var — updated in-memory after step advancement
    let plan: TrainingPlan
}
```

`TrainingRecord` stores the Three D's values (including `.custom`) and custom free-text values when a session is plan-linked:

```swift
// training_records fields added for plan + custom D support:
var score: Int                         // 0–5 rep count; status is derived, not manually set
var planItemId: UUID?                   // "plan_item_id" — nil for standalone sessions
var distanceCustomValue: String?        // "distance_custom"
var durationCustomValue: String?        // "duration_custom"
var distractionCustomValue: String?     // "distraction_custom"
```

### Three D's Custom Case

Each dimension enum gains a `.custom` case:

```swift
enum Distance: String, Codable, CaseIterable {
    case armsLength = "arms_length", sixFeet = "6_feet", twelveFeet = "12_feet",
         twentyFeet = "20_feet", twentyPlusFeet = "20_plus_feet", custom = "custom"

    func displayLabel(customValue: String?) -> String {
        self == .custom ? (customValue ?? "Custom") : label
    }
}
// Same pattern for TrainingDuration and Distraction
```

---

## Architecture Notes

| Concern | Decision |
|---------|----------|
| Trainer vs Guardian ViewModels | Separate — `TrainerPlanViewModel` and `GuardianPlanViewModel`. Different mutation surface, different fetch logic. |
| Behavior as intermediate layer | `Behavior` lives in `Core/Models/Behavior.swift`. Items carry a nullable `behaviorId` so old data without behaviors still works. |
| `AssignedPlan` placement | Lives in `TrainingPlanService.swift`, not `Core/Models/` — it's a join result, not a direct DB row. Follows `LinkedGuardian` pattern in `InviteService.swift`. |
| Step `sortOrder` scope | Scoped **per behavior**, not per plan. `TrainerBehaviorDetailView` shows steps 0…N within that behavior; guardian detail resolves current step from a flat sorted union of all steps. |
| Guardian step advancement | Global across all behaviors: the flat sorted list spans all behaviors in plan order. A guardian naturally progresses from Behavior A's last step into Behavior B's first step without special casing. |
| Custom Three D values | Stored as dedicated nullable columns; the enum column stores `"custom"` as the raw value. Display resolves at read time via `displayLabel(customValue:)`. Never stored on non-custom rows. |
| Assignment block | Computed in `TrainerPlanDetailView.assignBlockReason` — no network call, uses already-loaded `behaviors` and `items` dictionaries. |
| Assign sheet navigation | Presented as `.sheet` with own `NavigationStack` — avoids mixing `navigationDestination` styles in the trainer's nav stack. |
| Reorder atomicity | Delete + re-insert is not transactional. On failure the app reloads from Supabase to recover consistent state. Acceptable for MVP. |
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
| `behaviors` | Trainer full access | Plan's `trainer_id = auth.uid()` |
| `behaviors` | Guardian reads assigned | Assignment row exists for guardian |
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
| Assign attempted with empty behaviors | `assignBlockReason` returns a message; "Assign" button replaced by a warning label |
| Assign attempted with behaviorless step | `assignBlockReason` names the offending behavior(s); button stays blocked |
| Guardian unlinked after assignment | Plan remains visible (assignment row persists); trainer can delete assignment manually |
| Plan deleted by trainer | `ON DELETE CASCADE` removes all behaviors, items, and assignments |
| Behavior deleted by trainer | `ON DELETE CASCADE` removes all steps in that behavior; guardian's `currentItemId` may be orphaned → `ON DELETE SET NULL` on `plan_assignments.current_item_id` resets to nil, falling back to first step |
| Guardian has no plans | "No plans assigned yet." in both Plans tab and dashboard |
| Reorder network failure | In-memory state reverted by reloading items from Supabase |
| Guardian at last step scores green | `min(currentIdx + 1, sorted.count - 1)` clamps — stays at last step, shows "mastered all steps" message |
| Guardian at first step scores red | `max(currentIdx - 1, 0)` clamps — stays at first step, shows encouragement message |
| `currentItemId` references a deleted item | `ON DELETE SET NULL` resets pointer to nil; `currentItem(for:in:)` falls back to the first step |
| Standalone session (no plan context) | `planItemId` is nil, Three D's are editable including `.custom`, no advancement logic runs |
| Step with `.custom` distance but empty string in DB | `displayLabel(customValue:)` falls back to `"Custom"` — shown to guardian but never occurs when form validation is respected |
| Legacy plan with no behaviors | Guardian detail shows a flat "Steps" section; no "Other Steps" header if there are also no unbound items |

---

## Test Flows

1. **Create plan**: Sign in as trainer → Plans → "+" → enter title and description → Create → plan appears in list.
2. **Add behavior**: Tap plan → "Add Behavior" → tap "Recall" from suggestions → Add → "Recall" appears in Behaviors section with "0 steps".
3. **Add behavior — custom name**: "Add Behavior" → type "Spin" → Add → appears in list.
4. **Reorder behaviors**: Long-press `≡` handle → drag to new position → navigate away and back → order persists.
5. **Add steps to a behavior**: Tap "Recall" → "Add Step" → enter "Sit at arm's length" → Distance: Arm's length, Duration: Instant, Distraction: None → Add → step appears with capsule tags.
6. **Add step with custom D**: "Add Step" → Distance: pick "Custom" → text field appears → type "20 feet in hallway" → Add → capsule shows "20 feet in hallway".
7. **Edit step**: Swipe left on a step → Edit → change Duration to Custom → type "hold for 3 seconds" → Save → capsule updates.
8. **Reorder steps**: Long-press handle in behavior detail → drag to new position → persists in Supabase.
9. **Assignment block — no behaviors**: Plan with no behaviors → "Assign to Guardian…" is absent; warning label shown instead.
10. **Assignment block — empty behavior**: Plan with "Recall" (0 steps) → warning shows `"Recall" has no steps…`.
11. **Assign plan**: All behaviors have steps → tap "Assign to Guardian…" → select guardian → optionally select pet → Assign → "Assigned To" section shows guardian name.
12. **Duplicate assignment**: Assign same plan to same guardian again → "already assigned" error shown.
13. **Guardian views plan (behaviors)**: Sign in as guardian → Plans tab → tap plan → steps shown grouped by behavior section; first step in first behavior highlighted green as current.
14. **Practice step — green**: Tap current step → score 5/5 → footer reads "Green — ready to advance" → Log → alert: "Moving to step 2" → next step highlighted.
15. **Practice step — stay**: Score 3/5 → "Yellow — keep practicing" → same step still current.
16. **Practice step — red**: Score 1/5 → "Red — we'll drop back" → previous step becomes current.
17. **Cross-behavior advancement**: Advance to last step of first behavior → score 5 → moves into first step of second behavior.
18. **Clamp at last step**: Score 5 on final step → "Amazing — you've mastered all the steps!" → step unchanged.
19. **Memory bank**: Log a session, close the app, reopen → same step still highlighted.
20. **Standalone session**: Pets tab → tap a pet → Training Sessions → "+" → Three D's editable (all pickers including `.custom`) → `plan_item_id` is null in Supabase.
21. **Dashboard count**: Guardian home → "Training Plans" shows "1 plan assigned" → tap → switches to Plans tab.
