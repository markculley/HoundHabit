# Phase 9 / 12a: Training Plans

## Overview

Training plans can be created by **Trainers** (who assign them to linked guardians) or by **Guardians** (who create and self-assign plans when working independently). Plans are composed of **Behaviors**, where each Behavior contains an ordered list of **Steps**. Each step defines specific values for the Three D's (Distance, Duration, Distraction) — with optional free-text custom values for each D. Guardians practice steps, enter a 0–5 rep score, and the app automatically advances, holds, or drops back their position based on the Traffic Light system. The guardian's position is persisted so they always resume exactly where they left off.

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

## UC-9.1b: Guardian Creates Their Own Plan

**Actor:** Guardian  
**Precondition:** Guardian is authenticated. No trainer is required.

Guardians can create and manage training plans independently. When a guardian creates a plan they become the `trainer_id` owner and a self-assignment is created automatically so the plan appears in their Plans list alongside any trainer-assigned plans.

### Flow

```
Guardian                  App                        Supabase
  │                         │                            │
  │  Tap "+" on Plans tab   │                            │
  │────────────────────────▶│                            │
  │  TrainerPlanFormView     │                            │
  │  (same form as trainer) │                            │
  │  + "Assign to Pet"      │                            │
  │  picker (if pets exist) │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Enter title +          │                            │
  │  description, optionally│                            │
  │  select a pet, tap Create│                           │
  │────────────────────────▶│                            │
  │                         │  createPlan(title, desc)   │
  │                         │───────────────────────────▶│
  │                         │  INSERT training_plans     │
  │                         │  (trainer_id = guardian's  │
  │                         │   own uid)                 │
  │                         │◀───────────────────────────│
  │                         │  selfAssignPlan(planId,    │
  │                         │    petId?, isShared: false)│
  │                         │───────────────────────────▶│
  │                         │  INSERT plan_assignments   │
  │                         │  (trainer_id = guardian_id │
  │                         │   = auth.uid(),            │
  │                         │   pet_id = selected pet,   │
  │                         │   is_shared = false)       │
  │                         │◀───────────────────────────│
  │  Plan appears in Plans  │                            │
  │  list (own plans can be │                            │
  │  deleted via swipe)     │                            │
  │◀────────────────────────│                            │
```

### Pet Picker in Form

`TrainerPlanFormView` accepts an optional `pets: [Pet]` parameter. When the guardian opens the form from `GuardianPlanListView`, the view passes its loaded `PetViewModel.pets`. If pets are present and mode is `.create`, an "Assign to Pet" picker section appears with a "None" option at the top. The selected `petId` is returned alongside the saved plan via `onSave: (TrainingPlan, UUID?) -> Void`.

Trainer-facing call sites pass no pets and use `{ plan, _ in }` — the picker is hidden and the second parameter ignored.

A plan can also be created from a pet's detail view (see UC-9.7), in which case the pet is pre-determined and no picker is needed.

### Navigation for Own Plans

From `GuardianPlanListView`, own plans (where `plan.trainerId == currentUserId`) navigate to `OwnedPlanDetailView` — a private wrapper that hosts `TrainerPlanDetailView` with `showAssignments: false`. This gives the guardian full plan editing capability (add behaviors, steps, reorder) without the guardian-assignment UI that's irrelevant to a self-managed plan.

Trainer-assigned plans navigate to the read-only `GuardianPlanDetailView` as before.

### RLS

A dedicated `plan_assignments` INSERT policy ("Guardian self-assigns own plans") permits the insert when `trainer_id = guardian_id = auth.uid()` and the plan is owned by that user:

```sql
WITH CHECK (
    trainer_id = auth.uid()
    AND guardian_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM training_plans
        WHERE id = plan_assignments.plan_id
          AND trainer_id = auth.uid()
    )
)
```

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

## UC-9.5: Guardian Views Plans

**Actor:** Guardian  
**Precondition:** Guardian is authenticated. Plans may be trainer-assigned or guardian-created.

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
  │                         │  (includes self-assignments│
  │                         │  for own plans)            │
  │                         │  + SELECT training_plans   │
  │                         │  WHERE id IN (planIds)     │
  │                         │◀───────────────────────────│
  │  Plan list shown        │                            │
  │  (progress badge per    │                            │
  │  plan: To Do / In       │                            │
  │  Progress / Done)       │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Tap a plan             │                            │
  │────────────────────────▶│                            │
  │  [own plan] → OwnedPlan │                            │
  │  DetailView (editable)  │                            │
  │  [assigned] → Guardian  │                            │
  │  PlanDetailView         │                            │
  │                         │  fetchAssignedPlanItems    │
  │                         │    (planId) [parallel]     │
  │                         │  fetchBehaviors(planId)    │
  │                         │    [parallel]              │
  │                         │───────────────────────────▶│
  │                         │◀───────────────────────────│
  │  Steps shown, grouped   │                            │
  │  by Behavior sections   │                            │
  │◀────────────────────────│                            │
```

### Plan List Differentiation

`GuardianPlanListView` identifies own plans via `plan.trainerId == currentUserId`:

| Plan type | Navigation destination | Delete available? |
|-----------|----------------------|-------------------|
| Own (guardian-created) | `OwnedPlanDetailView` → `TrainerPlanDetailView(showAssignments: false)` | Yes — swipe to delete |
| Trainer-assigned | `GuardianPlanDetailView` (practice mode) | No |

Empty state message: *"Tap + to create your own plan, or ask your trainer to assign one."*

### Trainer-Assigned Plan Sharing Toggle

`GuardianPlanDetailView` shows a **"Share sessions with trainer"** toggle in the plan header section for trainer-assigned plans (`assignment.trainerId != assignment.guardianId`). The toggle is hidden for self-assigned (own) plans.

- **Default: on** — all sessions logged under the plan are shared with the trainer.
- Toggling calls `GuardianPlanViewModel.updateSharing(for:isShared:)` → `TrainingPlanService.updateAssignmentSharing(assignmentId:isShared:)` → `UPDATE plan_assignments SET is_shared = ?`.
- The updated value is written to `assignedPlans[idx].assignment.isShared` in-memory immediately.
- When the guardian opens a step's practice form, `isSharedDefault: isSharedWithTrainer` is passed into `TrainingRecordFormView`. The record is created with that `isShared` value — no per-session toggle is shown for plan-linked sessions.

### Behavior-Grouped Layout

`GuardianPlanDetailView` renders one `List` section per Behavior. Steps within each section are shown in their `sortOrder` sequence. The current step (green dot + green play icon) may appear in any behavior's section.

```
┌─ Leave It ──────────────────────────────────────┐
│ ○  1. Step 1   Arm's length · Instant · None   ▶│  ← completed, replayable
│ ○  2. Step 2   Arm's length · Instant · None   ▶│  ← completed, replayable
└─────────────────────────────────────────────────┘
┌─ Touch ─────────────────────────────────────────┐
│ ●  1. Touch Step 1  Arm's length · Instant · None  ▶│  ← current (green)
└─────────────────────────────────────────────────┘
┌─ Back ──────────────────────────────────────────┐
│ ○  1. Back Step 1   Arm's length · 5 sec · None  ℹ│  ← locked (future)
└─────────────────────────────────────────────────┘
```

**Legacy / unbound items** (steps with no `behavior_id`) appear in an "Other Steps" section as a backward-compatibility fallback.

### Current Step Resolution

`GuardianPlanViewModel.currentItem(for:in:)` resolves across the full flat `items` list regardless of behavior grouping:
- If `currentItemId` is set → show that step as current
- If `currentItemId` is `nil` (first visit) → default to the first step by `sort_order` across all behaviors

### Step Accessibility (Replayability)

Steps are divided into three accessibility states based on global plan order:

| State | Visual | Tap action |
|-------|--------|-----------|
| **Current** | Green circle, green play icon, bold title | Opens practice form → advancement logic fires on save |
| **Completed** (before current in plan order) | Grey circle, grey play icon, normal title | Opens practice form → record logged, position unchanged |
| **Locked** (after current in plan order) | Grey circle, info icon, dimmed title | Opens read-only info sheet |

Guardians can **replay any previously completed step** in any order — the app doesn't care which completed steps are repeated or in what sequence. Advancement only happens when the **current** step is practiced.

**Global ordering** is computed in `GuardianPlanDetailView.orderedItems` — behaviors sorted by `behavior.sortOrder`, then items within each behavior sorted by `item.sortOrder`. This correctly handles the fact that `item.sortOrder` is scoped per-behavior (each behavior's steps start at 0), so a raw `item.sortOrder` comparison across behaviors would give wrong results.

```swift
private var orderedItems: [TrainingPlanItem] {
    var result: [TrainingPlanItem] = []
    for behavior in behaviors {
        result.append(contentsOf: items(for: behavior))
    }
    result.append(contentsOf: unboundItems)
    return result
}

private func isLocked(_ item: TrainingPlanItem) -> Bool {
    let currentIdx = orderedItems.firstIndex(where: { $0.id == currentItem?.id }) ?? 0
    let itemIdx    = orderedItems.firstIndex(where: { $0.id == item.id }) ?? 0
    return itemIdx > currentIdx
}
```

### Dashboard Integration

`DashboardViewModel.load()` fetches `fetchAssignedPlans().count` alongside badges and trainer info. The dashboard "Training Plans" section shows:
- A tappable `"X plans assigned"` button that switches to the Plans tab (tag 2) via a `switchToPlansTab` closure passed from `GuardianTabView`
- `"No plans assigned yet."` when count is zero

---

## UC-9.6: Guardian Practises a Step (Traffic Light Flow)

**Actor:** Guardian  
**Precondition:** Guardian is viewing a plan detail. Any step at or before the current step can be practiced.

This is the core loop described in the Training Prototype. The guardian performs 5 repetitions, enters how many succeeded (0–5), and the app computes the Traffic Light status. Advancement only applies when the **current** step is practiced; replaying a completed step just logs the record.

### Flow

```
Guardian                  App                        Supabase
  │                         │                            │
  │  Tap a reachable step   │                            │
  │  (▶ button — current    │                            │
  │  or any completed step) │                            │
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
  │  [if practiced item     │                            │
  │   IS the current step]  │                            │
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
  │                         │                            │
  │  [if practiced item is  │                            │
  │   a COMPLETED step]     │                            │
  │  Record logged,         │                            │
  │  no position change     │                            │
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

## UC-9.7: Guardian Views and Manages Plans from Pet Detail

**Actor:** Guardian
**Precondition:** Guardian is viewing a pet's detail screen (`PetDetailView`).

The pet detail screen is a second entry point for plans — a guardian can see all plans linked to a specific pet, create a new plan for that pet, or assign an existing own plan to the pet.

### Plans Section Layout

`PetDetailView` shows a **Plans** section below the hero photo with two subsections:

| Subsection | Condition | Action on tap |
|---|---|---|
| **My Plans** | Plans where `plan.trainerId == currentUserId` | Opens `OwnedPlanDetailView` in a sheet |
| **From My Trainer** | Plans where `plan.trainerId != currentUserId` | Opens `GuardianPlanDetailView` in a sheet |

Both lists only show plans whose `assignment.petId == petId` (i.e. linked to this specific pet).

### Adding Plans to a Pet

The `+` button in the Plans header opens a `Menu` with two options:

1. **New Plan** — opens `TrainerPlanFormView`. On save, `guardianPlanVM.adoptCreatedPlan(saved, petId: pet.id)` creates the plan and self-assignment with the pet pre-linked. No pet picker is shown since the pet is already determined by context.
2. **Assign Existing Plan** — only visible when the guardian has own plans not yet linked to this pet. Opens `AssignExistingPlanSheet` listing those plans. On selection, `TrainingPlanService.updateAssignmentPet(assignmentId:petId:)` links the existing assignment to the pet.

### Data Loading

`PetDetailView` loads independently from `GuardianPlanListView` — it fetches all assigned plans via `TrainingPlanService.fetchAssignedPlans()`, filters for `petId` match, and primes `guardianPlanVM.assignedPlans` so `GuardianPlanDetailView` can load items on demand.

```swift
private func loadPetPlans() async {
    let all = (try? await planService.fetchAssignedPlans()) ?? []
    petPlans = all.filter { $0.assignment.petId == petId }
    allOwnPlans = all.filter { $0.plan.trainerId == currentUserId }
    for ap in petPlans where !guardianPlanVM.assignedPlans.contains(...) {
        guardianPlanVM.assignedPlans.append(ap)
    }
}
```

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
| Guardian-created plans | Guardian becomes `trainer_id` on the plan. `selfAssignPlan` creates a `plan_assignment` with `trainer_id = guardian_id = auth.uid()` and `is_shared = false`. The plan then appears in `fetchAssignedPlans()` just like any trainer-assigned plan. |
| Guardian plan detail routing | `GuardianPlanListView` checks `plan.trainerId == currentUserId`. Own plans → `OwnedPlanDetailView` (wraps `TrainerPlanDetailView(showAssignments: false)`). Trainer-assigned → `GuardianPlanDetailView`. Two distinct `navigationDestination` types: `TrainingPlan` for own, `AssignedPlan` for assigned. |
| `showAssignments` flag | `TrainerPlanDetailView` accepts `showAssignments: Bool = true`. Guardians viewing their own plan pass `false` — the "Assign to Guardian" button and assignment rows are hidden entirely. |
| `is_shared` on `plan_assignments` | Controls whether sessions logged under a plan are visible to the trainer. Trainer-assigned plans default to `true` (`assignPlan` sets `isShared: true`). Self-assigned plans default to `false` (`selfAssignPlan` sets `isShared: false`). Guardian can toggle per-plan in `GuardianPlanDetailView`. The value is passed as `isSharedDefault` into `TrainingRecordFormView`; no per-session toggle is shown for plan-linked sessions. |
| `TrainerPlanFormView` pet picker | `var pets: [Pet] = []` parameter. When non-empty and mode is `.create`, an "Assign to Pet" picker section appears. `onSave` carries `(TrainingPlan, UUID?)` — the second argument is the selected petId (nil if "None" selected). Trainer call sites pass no pets and ignore the second argument. |
| Behavior as intermediate layer | `Behavior` lives in `Core/Models/Behavior.swift`. Items carry a nullable `behaviorId` so old data without behaviors still works. |
| `AssignedPlan` placement | Lives in `TrainingPlanService.swift`, not `Core/Models/` — it's a join result, not a direct DB row. Follows `LinkedGuardian` pattern in `InviteService.swift`. |
| Step `sortOrder` scope | Scoped **per behavior**, not per plan. `TrainerBehaviorDetailView` shows steps 0…N within that behavior. Guardian detail computes global order via `orderedItems` (behaviors by behavior sortOrder, then items by item sortOrder within each behavior). A raw cross-behavior `sortOrder` comparison would be wrong because each behavior resets at 0. |
| Step replayability | Guardians can replay any completed step (at or before current in global order). Advancement only fires when practicing the **current** step. `isLocked(_:)` uses global index comparison via `orderedItems`. |
| Trainer assignment progress | `TrainerPlanViewModel.planProgress(for: PlanAssignment)` computes `.todo / .inProgress / .done` and is displayed as a `PlanProgressBadge` per assignment row in `TrainerPlanDetailView`. |
| Behavior name in session detail | `TrainingRecordDetailView` self-loads the behavior name via `TrainingPlanService.fetchBehaviorName(for: planItemId)` when `planItemId` is non-nil. Two fetches: item → behaviorId → behavior name. Shown in the Three D's section alongside Distance, Duration, Distraction. |
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
| `plan_assignments` | **Guardian self-assigns own plans** | `trainer_id = guardian_id = auth.uid()` + plan owned by uid |
| `plan_assignments` | Guardian reads own | `guardian_id = auth.uid()` |
| `plan_assignments` | Guardian updates `current_item_id` | `guardian_id = auth.uid()` |
| `plan_assignments` | Guardian updates `is_shared` | `guardian_id = auth.uid()` |

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
| Guardian has no plans | "Tap + to create your own plan, or ask your trainer to assign one." in Plans tab |
| Guardian-created plan self-assignment RLS | Blocked by the existing trainer-insert policy (which requires `trainer_guardian_links`); allowed by the dedicated "Guardian self-assigns own plans" policy. |
| Guardian replays a completed step | Record is logged with `plan_item_id` set; `advanceCurrentStep` is NOT called; guardian's position (`currentItemId`) is unchanged. |
| Locked step tapped | Opens read-only `StepInfoSheet` — shows Three D's and a note that the step is not yet reachable. |
| `.sheet(item:)` for step sheets | Both practice and info sheets use `.sheet(item:)` to avoid the SwiftUI timing race where content can be nil if `isPresented` fires before the item binding updates. |
| Reorder network failure | In-memory state reverted by reloading items from Supabase |
| Guardian at last step scores green | `min(currentIdx + 1, sorted.count - 1)` clamps — stays at last step, shows "mastered all steps" message |
| Guardian at first step scores red | `max(currentIdx - 1, 0)` clamps — stays at first step, shows encouragement message |
| `currentItemId` references a deleted item | `ON DELETE SET NULL` resets pointer to nil; `currentItem(for:in:)` falls back to the first step |
| Standalone session (no plan context) | `planItemId` is nil, Three D's are editable including `.custom`, no advancement logic runs |
| Plan-linked session sharing | `isShared` on the record is set from `assignment.isShared` at creation time — no per-session override. Toggling the plan-level sharing toggle forward only affects new sessions. |
| Guardian toggles sharing off mid-plan | Existing session records retain their original `is_shared` value — only future sessions pick up the new setting. |
| Self-assigned plan — sharing toggle hidden | `isTrainerAssigned` (`trainerId != guardianId`) is false; toggle not rendered in `GuardianPlanDetailView`. |
| Step with `.custom` distance but empty string in DB | `displayLabel(customValue:)` falls back to `"Custom"` — shown to guardian but never occurs when form validation is respected |
| Legacy plan with no behaviors | Guardian detail shows a flat "Steps" section; no "Other Steps" header if there are also no unbound items |
| Behavior name in session detail | `TrainingRecordDetailView` calls `fetchBehaviorName(for: planItemId)` on appear; nil is returned for standalone sessions or steps with no behavior — row is simply hidden. |

---

## Test Flows

1. **Create plan (trainer)**: Sign in as trainer → Plans → "+" → enter title and description → Create → plan appears in list.
2. **Create plan (guardian, no trainer)**: Sign in as guardian → Plans tab → "+" → enter title and description → Create → plan appears in list with "To Do" badge; no "Assign to Guardian" UI shown in detail.
3. **Guardian own plan — add behavior**: Tap own plan → "Add Behavior" → type "Spin" → Add → behavior appears.
4. **Guardian own plan — add step**: Tap behavior → "Add Step" → enter step details → Add → step appears.
5. **Guardian own plan — delete**: Swipe left on own plan in list → Delete → plan removed from list and Supabase.
6. **Trainer-assigned plan — no delete**: Swipe left on a trainer-assigned plan → no delete action available.
7. **Add behavior (trainer)**: Tap plan → "Add Behavior" → tap "Recall" from suggestions → Add → "Recall" appears with "0 steps".
8. **Add behavior — custom name**: "Add Behavior" → type "Spin" → Add → appears in list.
9. **Reorder behaviors**: Long-press `≡` handle → drag to new position → navigate away and back → order persists.
10. **Add steps to a behavior**: Tap "Recall" → "Add Step" → enter "Sit at arm's length" → Distance: Arm's length, Duration: Instant, Distraction: None → Add → step appears with capsule tags.
11. **Add step with custom D**: "Add Step" → Distance: pick "Custom" → text field appears → type "20 feet in hallway" → Add → capsule shows "20 feet in hallway".
12. **Edit step**: Swipe left on a step → Edit → change Duration to Custom → type "hold for 3 seconds" → Save → capsule updates.
13. **Reorder steps**: Long-press handle in behavior detail → drag to new position → persists in Supabase.
14. **Assignment block — no behaviors**: Plan with no behaviors → "Assign to Guardian…" is absent; warning label shown instead.
15. **Assignment block — empty behavior**: Plan with "Recall" (0 steps) → warning shows `"Recall" has no steps…`.
16. **Assign plan**: All behaviors have steps → tap "Assign to Guardian…" → select guardian → optionally select pet → Assign → assignment row shows guardian name + "To Do" badge.
17. **Trainer sees progress**: Guardian practices a step → trainer opens same plan detail → assignment row shows "In Progress" badge.
18. **Duplicate assignment**: Assign same plan to same guardian again → "already assigned" error shown.
19. **Guardian views plan (behaviors)**: Sign in as guardian → Plans tab → tap trainer-assigned plan → steps shown grouped by behavior; first step highlighted green (current); completed steps show grey play icon; future steps show info icon.
20. **Replay completed step**: Tap a grey-play step (completed) → practice form opens with Three D's locked → log score → no advancement alert → current step unchanged.
21. **Locked step tapped**: Tap an info-icon step (future) → read-only info sheet shown; no practice form.
22. **Practice step — green**: Tap current step → score 5/5 → footer reads "Green — ready to advance" → Log → alert: "Moving to step 2" → next step highlighted.
23. **Practice step — stay**: Score 3/5 → "Yellow — keep practicing" → same step still current.
24. **Practice step — red**: Score 1/5 → "Red — we'll drop back" → previous step becomes current.
25. **Cross-behavior advancement**: Advance to last step of first behavior → score 5 → moves into first step of second behavior.
26. **Clamp at last step**: Score 5 on final step → "Amazing — you've mastered all the steps!" → step unchanged.
27. **Memory bank**: Log a session, close the app, reopen → same step still highlighted.
28. **Behavior name in record detail**: After a plan-linked session → open the record in Training Sessions list → Three D's section shows "Behavior: [name]" above Distance/Duration/Distraction.
29. **Standalone session**: Pets tab → tap a pet → Training Sessions → "+" → Three D's editable (all pickers including `.custom`) → `plan_item_id` is null in Supabase; no Behavior row in detail.
30. **Dashboard count**: Guardian home → "Training Plans" shows "1 plan assigned" → tap → switches to Plans tab.
31. **Create plan with pet (Plans tab)**: Guardian → Plans tab → "+" → form shows "Assign to Pet" section → select a pet → Create → plan appears in Plans list; open Pet Detail for that pet → plan appears under "My Plans".
32. **Create plan without pet (Plans tab)**: Guardian → Plans tab → "+" → leave pet as "None" → Create → plan appears in Plans list with no pet link; does not appear in any Pet Detail's plans section.
33. **Assign existing plan to pet**: Guardian has a plan not linked to any pet → Pet Detail → Plans "+" → "Assign Existing Plan" → plan appears in list → select it → plan now appears in Pet Detail plans section.
34. **Pet Detail plans — My Plans vs From My Trainer**: Pet with both self-created and trainer-assigned plans → Pet Detail shows "My Plans" and "From My Trainer" subsections correctly separated.
35. **Trainer sharing default on**: Guardian linked to a trainer → trainer assigns a plan → Guardian views plan detail → "Share sessions with trainer" toggle is ON.
36. **Toggle sharing off**: Guardian opens trainer-assigned plan detail → toggles "Share sessions with trainer" off → logs a session → in Supabase `training_records` the new row has `is_shared = false`; trainer's guardian detail no longer shows new sessions for this plan.
37. **Sharing toggle hidden for own plans**: Guardian views a self-created plan detail → no "Share sessions with trainer" toggle shown.
38. **No per-session toggle for plan sessions**: Guardian logs a step from a plan → `TrainingRecordFormView` does not show "Share with Trainer" toggle.
