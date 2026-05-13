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

## UC-9.2: Trainer Adds and Edits Behaviors

**Actor:** Trainer (or Guardian editing their own plan via `OwnedPlanDetailView`)
**Precondition:** Actor is viewing a plan in `TrainerPlanDetailView`.

Behaviors are the top-level groupings within a plan — one per skill the guardian will train (e.g. "Sit", "Down", "Recall"). Each Behavior acts as its own progression sequence with its own ordered steps.

### Flow — Add a Behavior

```
Trainer                   App                        Supabase
  │                         │                            │
  │  Scroll to bottom of    │                            │
  │  Behaviors section,     │                            │
  │  tap "+ Add Behavior"   │                            │
  │  (inline row, not a     │                            │
  │  toolbar button)        │                            │
  │────────────────────────▶│                            │
  │  TrainerBehaviorFormView│                            │
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
  │  Behaviors list above   │                            │
  │  the inline + row       │                            │
  │◀────────────────────────│                            │
```

### Flow — Edit a Behavior Name (inline, auto-save)

```
Trainer                   App                        Supabase
  │                         │                            │
  │  Tap a behavior row     │                            │
  │  (push)                 │                            │
  │────────────────────────▶│                            │
  │  TrainerBehaviorDetail  │                            │
  │  shows Name section     │                            │
  │  as editable TextField  │                            │
  │  pre-filled with current│                            │
  │  name (no Rename modal) │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Type into Name field   │                            │
  │────────────────────────▶│                            │
  │                         │  scheduleNameCommit():     │
  │                         │  cancel prior Task,        │
  │                         │  start 500ms debounce      │
  │                         │  ...                       │
  │                         │  commitName() →            │
  │                         │  updateBehavior(name:)     │
  │                         │───────────────────────────▶│
  │                         │  UPDATE behaviors SET name │
  │                         │◀───────────────────────────│
  │                         │                            │
  │  Swipe back / tap       │                            │
  │  another field          │                            │
  │────────────────────────▶│                            │
  │                         │  .onDisappear flushes      │
  │                         │  pending debounced commit  │
  │                         │  (covers fast back-swipe)  │
```

### Inline +Add row (IOS-21)

The "Add Behavior" affordance lives as a row at the **bottom of the Behaviors section**, not in the toolbar. Style: `Label("Add Behavior", systemImage: "plus.circle")` with `.foregroundStyle(.tint)`. Empty-state copy nudges toward it: *"No behaviors yet. Tap + Add Behavior below to begin."*

### Inline name edit (IOS-21)

`TrainerBehaviorDetailView` shows a `Section("Name")` at the top with a TextField. Local state (`editingName`) mirrors the persisted name. Commit semantics:

- **Debounce:** `.onChange(of: editingName)` schedules a 500ms `Task.sleep`; the next keystroke cancels and reschedules.
- **Submit:** `.onSubmit` flushes immediately.
- **Disappear:** `.onDisappear` flushes any pending commit so a swipe-back doesn't drop the latest edit.
- **Validation:** an empty trimmed name surfaces an inline red caption ("Name can't be empty") and skips the commit. Once non-empty again, the next change triggers a commit.
- **Redundant-commit guard:** `lastCommittedName` prevents network calls when the value hasn't changed across debounce ticks.

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

## UC-9.3: Trainer Adds and Edits Steps

**Actor:** Trainer (or Guardian editing their own plan via `OwnedPlanDetailView`)
**Precondition:** Actor is viewing a behavior in `TrainerBehaviorDetailView`.

Each step encodes the exact Distance, Duration, and Distraction the guardian should practise. Only one of the Three D's should differ between consecutive steps (the "One Change" rule).

### Flow — Add a Step

```
Trainer                   App                        Supabase
  │                         │                            │
  │  Tap behavior in list   │                            │
  │────────────────────────▶│                            │
  │  TrainerBehaviorDetail  │                            │
  │  (NavigationLink push)  │                            │
  │                         │  loadItems(for: behavior)  │
  │                         │───────────────────────────▶│
  │                         │  SELECT training_plan_items│
  │                         │  WHERE behavior_id=?       │
  │                         │◀───────────────────────────│
  │  Steps list shown,      │                            │
  │  with "+ Add Step" row  │                            │
  │  at bottom (inline,     │                            │
  │  not a toolbar button)  │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Tap "+ Add Step"       │                            │
  │────────────────────────▶│                            │
  │  TrainerPlanItemFormView│                            │
  │  (sheet, mode = .add)   │                            │
  │                         │                            │
  │  Enter step name,       │                            │
  │  pick Distance /        │                            │
  │  Duration / Distraction │                            │
  │  (optionally choose     │                            │
  │  "Custom" and type a    │                            │
  │  free-text value)       │                            │
  │  tap Add                │                            │
  │────────────────────────▶│                            │
  │                         │  onSave fires once →       │
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

### Flow — Edit a Step (auto-save)

```
Trainer                   App                        Supabase
  │                         │                            │
  │  Tap an existing step   │                            │
  │  row (whole row is a    │                            │
  │  button; no swipe-Edit  │                            │
  │  action)                │                            │
  │────────────────────────▶│                            │
  │  TrainerPlanItemFormView│                            │
  │  (sheet, mode = .edit)  │                            │
  │  populated; toolbar     │                            │
  │  shows "Done" only —    │                            │
  │  no Save button         │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Change a picker        │                            │
  │  (Distance/Duration/    │                            │
  │  Distraction)           │                            │
  │────────────────────────▶│                            │
  │                         │  .onChange fires           │
  │                         │  commitIfEditing(          │
  │                         │    immediate: true)        │
  │                         │  → onCommit → updateItem   │
  │                         │───────────────────────────▶│
  │                         │  UPDATE training_plan_items│
  │                         │◀───────────────────────────│
  │                         │                            │
  │  Type into title or a   │                            │
  │  Custom value field     │                            │
  │────────────────────────▶│                            │
  │                         │  scheduleDebouncedCommit() │
  │                         │  cancel prior Task,        │
  │                         │  start 500ms debounce      │
  │                         │  ...                       │
  │                         │  commitIfEditing()         │
  │                         │  → onCommit → updateItem   │
  │                         │───────────────────────────▶│
  │                         │◀───────────────────────────│
  │                         │                            │
  │  Tap Done / swipe down  │                            │
  │  to dismiss sheet       │                            │
  │────────────────────────▶│                            │
  │                         │  .onDisappear flushes any  │
  │                         │  pending debounced commit  │
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

### Tap-to-edit + auto-save (IOS-21)

The step row in `TrainerBehaviorDetailView` is wrapped in a `Button { itemToEdit = item }` — tapping anywhere on the row opens the form in **edit mode**. There is no swipe-trailing "Edit" action; the trailing swipe shows only **Delete**.

`TrainerPlanItemFormView` exposes two optional callbacks (callers pick the right one — beware Swift trailing-closure resolution, always label `onSave:` / `onCommit:` explicitly):

```swift
var onSave: ((ItemFormResult) -> Void)? = nil    // create — one-shot on Save tap
var onCommit: ((ItemFormResult) -> Void)? = nil  // edit — fires per commit
```

Edit-mode commit semantics:

| Field | Trigger | Cadence |
|-------|---------|---------|
| Title `TextField`, custom-value `TextField`s | `.onChange` | Debounced 500ms after last keystroke |
| Title `.onSubmit` | Submit key | Immediate |
| Distance / Duration / Distraction `Picker` | `.onChange` | Immediate (any pending text-debounce is also cancelled) |
| Sheet dismissal (Done, swipe-down) | `.onDisappear` | Flushes any pending debounced commit |

Edit-mode validation:

- An empty trimmed title surfaces an inline red caption ("Title can't be empty") and **does not commit**. The form does NOT auto-revert — the user is mid-edit. Once non-empty again, the next change fires another commit cycle.
- A `.custom` picker selection with an empty custom-value field also blocks commits (same `canSave` gate the create flow uses).

Lifecycle guards prevent spurious commits:

- `hasPopulated` blocks commits during the initial `populateIfEditing()` call (otherwise `.onAppear` would fire a no-op write).
- `commitTask?.cancel()` coalesces debounced edits so only the last keystroke pause triggers a save.

In **create** mode the form is unchanged: an explicit "Add" button validates and calls `onSave` once. The leading toolbar item is "Cancel" in create mode and "Done" in edit mode (Done flushes pending and dismisses).

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
  │  (currently optional —  │                            │
  │  pending: required, see │                            │
  │  note below)            │                            │
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

### Pending: pet required at assignment time

Per the PRD (*"Attach Training Plan to Pet"*), a pet **must** be selected when a plan is assigned to a guardian. The current implementation allows "Any pet" as a fallback — tracked separately as a backlog card. Once shipped, `AssignPlanSheet` will:

- Drop the "Any pet" tag and "Optional" header.
- Disable Assign until both guardian AND pet are selected.
- Show a clear message when the selected guardian has zero pets.

A companion card adds trainer-side editing of the pet on an existing assignment so legacy "Any pet" rows can be repaired without delete + recreate.

---

## UC-9.4b: Trainer Copies an Existing Plan

**Actor:** Trainer (or Guardian copying their own plan)
**Precondition:** Actor owns the source plan (`plan.trainerId == currentUserId`). Copying a trainer-assigned plan is not exposed to guardians — only the trainer who owns it can copy.

A copy duplicates the plan's structure (behaviors + steps + Three D's + custom values) into a **new** `training_plans` row owned by the caller. Assignments do NOT carry over: the copy starts unassigned and the caller is immediately prompted to assign or skip.

### Flow

```
Trainer                   App                        Supabase
  │                         │                            │
  │  Plan detail …          │                            │
  │  toolbar overflow menu  │                            │
  │  → tap "Copy Plan"      │                            │
  │────────────────────────▶│                            │
  │                         │  copyPlan(plan) →          │
  │                         │  rpc("copy_plan",          │
  │                         │       source_plan_id: …)   │
  │                         │───────────────────────────▶│
  │                         │  INSERT training_plans     │
  │                         │  (new id, trainer_id =     │
  │                         │   auth.uid())              │
  │                         │  + INSERT behaviors        │
  │                         │  (cloned)                  │
  │                         │  + INSERT                  │
  │                         │  training_plan_items       │
  │                         │  (cloned, new behavior_ids)│
  │                         │◀───────────────────────────│
  │                         │  returns new plan          │
  │                         │                            │
  │  AssignPlanSheet         │                            │
  │  (allowNone: true) opens │                            │
  │  on the new copy        │                            │
  │  [or CopyPlanPetPicker  │                            │
  │   if guardian-owned]    │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Pick guardian + pet,   │                            │
  │  OR pick "None",        │                            │
  │  OR Cancel              │                            │
  │────────────────────────▶│                            │
  │                         │                            │
  │  [confirmed] navigate   │                            │
  │  to new plan detail     │                            │
  │  [cancelled] deletePlan │                            │
  │  rolls back the copy    │                            │
  │───────────────────────▶ │                            │
```

### Atomic copy via Postgres RPC

`TrainingPlanService.copyPlan(planId:)` calls a `copy_plan(source_plan_id uuid)` Postgres function. The function is `security definer` and:

1. Inserts a new `training_plans` row with `trainer_id = auth.uid()`, the source plan's title prefixed (e.g. *"Sit (Copy)"*), and a fresh `id`.
2. Selects all behaviors of the source and re-inserts them under the new plan, preserving `sort_order`. New behavior ids are generated.
3. Selects all `training_plan_items` of the source and re-inserts them under the new plan, remapping each `behavior_id` to the corresponding new behavior.
4. Returns the new plan id.

The Swift caller then re-fetches the full `training_plans` row to return a populated model.

### Post-copy assign flow

The view that initiated the copy (`TrainerPlanDetailView` for trainer-owned plans, `OwnedPlanDetailView` for guardian-owned plans) immediately presents an assignment sheet on the **new** copy:

| Caller | Sheet | `allowNone` |
|---|---|---|
| `TrainerPlanDetailView` (showAssignments = true) | `AssignPlanSheet` | `true` (lets trainer save without assigning) |
| `OwnedPlanDetailView` (showAssignments = false) | `CopyPlanPetPickerSheet` | n/a (guardian-only pet picker) |

The sheet's `onComplete` callback flips a `copyConfirmed` flag. `onDismiss` reads the flag:

- **Confirmed** (assigned to a guardian, or explicitly picked "None") → `copyDestination = copy` pushes the new plan's detail onto the navigation stack.
- **Cancelled** (toolbar Cancel / swipe-down without confirming) → `viewModel.deletePlan(copy)` rolls back the copy so the world looks like nothing happened.

This is why `copyConfirmed` is a separate flag from "sheet shown" — SwiftUI's sheet lifecycle alone can't distinguish "user chose to proceed without an assignment" from "user dismissed without acting."

### Why copies don't inherit assignments

A copy is a fresh plan owned by the caller. Inheriting the source's `plan_assignments` rows would let a guardian-owned copy auto-assign to that guardian's pet (annoying if the user wanted a starting template), or, in the trainer case, would push a new plan into a guardian's "From My Trainer" tab without consent. Forcing an explicit assign-or-skip on every copy makes the user's intent unambiguous.

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

### Plan List Differentiation (IOS-14)

`GuardianPlanListView` splits the guardian's plans into two sections based on `viewModel.isOwnPlan(_:)` (which checks `plan.trainerId == currentUserId`):

| Section | Plans included | Navigation destination | Delete available? |
|---|---|---|---|
| **My Plans** | Own (guardian-created) | `OwnedPlanDetailView` → `TrainerPlanDetailView(showAssignments: false)` | Yes — swipe to delete |
| **From My Trainer** | Trainer-assigned | `GuardianPlanDetailView` (practice mode) | No |

Sections only render when non-empty; if the guardian has no own plans, the **My Plans** section is hidden entirely, and likewise for **From My Trainer**. A guardian with neither sees the `ContentUnavailableView` empty state: *"Tap + to create your own plan, or ask your trainer to assign one."*

Each row in either section is rendered by `AssignedPlanRow`, which shows:

- **Pet avatar (left)** — `PetAvatarView(url: pet.photoUrl, size: 40)` resolved by `pet(for: assignedPlan)` (looks up `assignment.petId` against `PetViewModel.pets`). When no pet is attached (legacy "Any pet" assignments), the avatar falls back to a paw-print placeholder.
- Plan title
- Progress badge (To Do / In Progress / Done)

The pet avatar makes it obvious-at-a-glance which pet a plan is for in households with multiple pets.

### Trainer-Assigned Plan Sharing Toggle

`GuardianPlanDetailView` shows a **"Share sessions with trainer"** toggle in the plan header section for trainer-assigned plans (`assignment.trainerId != assignment.guardianId`). The toggle is hidden for self-assigned (own) plans.

- **Default: on** — all sessions logged under the plan are shared with the trainer.
- Toggling calls `GuardianPlanViewModel.updateSharing(for:isShared:)` → `TrainingPlanService.updateAssignmentSharing(assignmentId:isShared:)` → `UPDATE plan_assignments SET is_shared = ?`.
- The updated value is written to `assignedPlans[idx].assignment.isShared` in-memory immediately.
- When the guardian opens a step's practice form, `isSharedDefault: isSharedWithTrainer` is passed into `TrainingRecordFormView`. The record is created with that `isShared` value — no per-session toggle is shown for plan-linked sessions.

### Plan Header (Guardian view)

The header section of `GuardianPlanDetailView` shows:

- `Label("Training Plan", systemImage: "list.bullet.clipboard")` — visual category
- `LabeledContent("Description", value: …)` — only rendered when the plan has a non-empty description. Labelled to match the trainer's view of the same field.
- "Assigned <date>" caption
- "Share sessions with trainer" toggle (trainer-assigned plans only — see above)

### Behavior-Grouped Layout

`GuardianPlanDetailView` renders steps inside a single `Section("Behaviors")`. Inside the section, each behavior is shown as a bold subheader row above its steps, with steps in their `sortOrder` sequence. The current step (green dot + green play icon) may appear under any behavior.

```
BEHAVIORS
┌─────────────────────────────────────────────────┐
│ Leave It                                        │  ← bold subheader
│ ○  1. Step 1   Arm's length · Instant · None   ▶│  ← completed, replayable
│ ○  2. Step 2   Arm's length · Instant · None   ▶│  ← completed, replayable
│                                                 │
│ Touch                                           │  ← bold subheader
│ ●  1. Touch Step 1  Arm's length · Instant · None ▶│  ← current (green)
│                                                 │
│ Back                                            │  ← bold subheader
│ ○  1. Back Step 1   Arm's length · 5 sec · None  ℹ│  ← locked (future)
└─────────────────────────────────────────────────┘
```

**Legacy / unbound items** (steps with no `behavior_id`) appear after all behaviors with an "Other Steps" subheader, as a backward-compatibility fallback.

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
