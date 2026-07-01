# Phase 9 / 12a: Training Plans

## Overview

Training plans are created by **Trainers**, who assign them to linked guardians. (Guardians cannot author their own plans — see the removed-UC note above UC-9.2.) Plans are composed of **Behaviors**, where each Behavior contains an ordered list of **Steps**. Each step defines specific values for the Three D's (Distance, Duration, Distraction) — with optional free-text custom values for each D. Guardians practice a step, run a timer, and log a 0–5 rep score. A step is **complete** once the guardian has logged a score of 5 on it on 3 consecutive calendar days; steps are gated sequentially within a behavior (a step unlocks when the previous one in its behavior is complete).

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

> **Removed — guardian-created plans (IOS-28).** An earlier build had a UC-9.1b
> ("Guardian Creates Their Own Plan") where guardians authored and self-assigned
> their own plans. That feature was removed: guardians can no longer create
> plans — only trainers create plans and assign them to guardians. The enabling
> RLS policy (`"Guardian self-assigns own plans"`) was dropped. See the PRD's
> v2 Backlog ("Guardian-Created Training Plans") for the deferred-enhancement note.

---

## UC-9.2: Trainer Adds Behaviors

**Actor:** Trainer
**Precondition:** Trainer is viewing a plan in `TrainerPlanDetailView`.

Behaviors are the top-level groupings within a plan — one per skill the guardian will train (e.g. "Sit", "Down", "Recall"). Each Behavior acts as its own progression sequence with its own ordered steps. A behavior's *type* is one of 12 fixed `BehaviorType`s (see below); it's chosen once at creation and not edited afterward.

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
  │  (sheet) — list of the  │                            │
  │  12 standard behaviors  │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Tap a behavior type,   │                            │
  │  tap Add                │                            │
  │────────────────────────▶│                            │
  │                         │  createBehavior(planId,    │
  │                         │    type, sortOrder)        │
  │                         │───────────────────────────▶│
  │                         │  INSERT behaviors          │
  │                         │◀───────────────────────────│
  │  Behavior appears in    │                            │
  │  Behaviors list above   │                            │
  │  the inline + row       │                            │
  │◀────────────────────────│                            │
```

### Behavior type is a fixed picklist

A behavior is one of **12 standard `BehaviorType`s** — picked from a fixed list, never free-typed:

| | | | |
|---|---|---|---|
| Sit | Down | Leave It | Drop It |
| Stand | Wait/Stay | Walk | Touch |
| Go to Mat | Recall | Off | Attention |

`BehaviorType` is a `Codable` discriminated union — `.standard(StandardBehavior)` or `.custom(String)` — that encodes to/from a **single string** (`init(from:)`/`encode(to:)` use a `singleValueContainer`), so `Behavior.type: BehaviorType` still maps to the `name` column via `CodingKeys` as a plain string. `StandardBehavior` is the `String`-backed enum of the 12 presets whose raw values **are** the display labels (e.g. `case waitStay = "Wait/Stay"`) — unlike the snake_case Three D's enums — so the shared `behaviors.name` column stays human-readable for both clients. `BehaviorType(rawValue:)` maps a known label to `.standard` and anything else to `.custom` (a custom name matching a standard label collapses to `.standard`, keeping the taxonomy deterministic). A DB `CHECK` constraint (`behaviors_name_nonempty`) only enforces a non-empty, length-capped value.

`TrainerBehaviorFormView` has a `Section("Behavior")` list of the 12 standard presets (checkmark on selection) **plus** a `Section("Custom")` text field for a trainer-typed name. The two are mutually exclusive — picking a preset clears the custom field and vice versa — and "Add" enables once either is set (`resolvedType != nil`). Mirrors the Three D's preset + custom idiom. Duplicates are allowed — a plan may hold the same behavior twice.

### Inline +Add row

The "Add Behavior" affordance lives as a row at the **bottom of the Behaviors section**, not in the toolbar. Style: `Label("Add Behavior", systemImage: "plus.circle")` with `.foregroundStyle(.tint)`. Empty-state copy nudges toward it: *"No behaviors yet. Tap + Add Behavior below to begin."*

### Behavior detail has no editable name

`TrainerBehaviorDetailView` shows the behavior as the large navigation title, then the "Steps" header and the steps list — **no "Name" section**. The behavior type is set once at creation in `TrainerBehaviorFormView` and is not editable from the detail view; to change it, delete and re-add the behavior. (An earlier build, IOS-21, had a debounced inline-rename `Section("Name")` here — removed once behavior became a fixed type.)

### Reorder / Delete

Behaviors in `TrainerPlanDetailView` support drag-to-reorder (`.onMove`) and swipe-to-delete. Deleting a behavior **cascades** to all its steps via the DB `ON DELETE CASCADE` on `training_plan_items.behavior_id`.

---

## UC-9.3: Trainer Adds and Edits Steps

**Actor:** Trainer
**Precondition:** Trainer is viewing a behavior in `TrainerBehaviorDetailView`.

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

**Actor:** Trainer
**Precondition:** Trainer owns the source plan (`plan.trainerId == currentUserId`).

A copy duplicates the plan's structure (behaviors + steps + Three D's + custom values) into a **new** `training_plans` row owned by the trainer. Assignments do NOT carry over: the copy starts unassigned and the trainer is immediately prompted to assign or skip.

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

`TrainerPlanDetailView` immediately presents an `AssignPlanSheet` (with `allowNone: true`, so the trainer can save without assigning) on the **new** copy.

The sheet's `onComplete` callback flips a `copyConfirmed` flag. `onDismiss` reads the flag:

- **Confirmed** (assigned to a guardian, or explicitly picked "None") → `copyDestination = copy` pushes the new plan's detail onto the navigation stack.
- **Cancelled** (toolbar Cancel / swipe-down without confirming) → `viewModel.deletePlan(copy)` rolls back the copy so the world looks like nothing happened.

This is why `copyConfirmed` is a separate flag from "sheet shown" — SwiftUI's sheet lifecycle alone can't distinguish "user chose to proceed without an assignment" from "user dismissed without acting."

### Why copies don't inherit assignments

A copy is a fresh plan owned by the trainer. Inheriting the source's `plan_assignments` rows would push a new plan into a guardian's plan list without consent. Forcing an explicit assign-or-skip on every copy makes the trainer's intent unambiguous.

---

## UC-9.5: Guardian Views Plans

**Actor:** Guardian  
**Precondition:** Guardian is authenticated. All plans are trainer-assigned (guardians cannot create plans — see the removed-UC note above UC-9.2).

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
  │  (progress badge per    │                            │
  │  plan: To Do / In       │                            │
  │  Progress / Done)       │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Tap a plan             │                            │
  │────────────────────────▶│                            │
  │  GuardianPlanDetailView │                            │
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

### Plan List Layout

`GuardianPlanListView` shows a single flat list of the guardian's trainer-assigned plans — every row navigates to the read-only `GuardianPlanDetailView` (practice mode). There are no sections and no create/delete affordances: the guardian neither authors nor owns plans (see the removed-UC note above UC-9.2; an earlier IOS-14 build split the list into "My Plans" / "From My Trainer", but "My Plans" was removed in IOS-28).

A guardian with no assigned plans sees the `ContentUnavailableView` empty state: *"Ask your trainer to assign a training plan."*

Each row is rendered by `AssignedPlanRow`, which shows:

- **Pet avatar (left)** — `PetAvatarView(url: pet.photoUrl, size: 40)` resolved by `pet(for: assignedPlan)` (looks up `assignment.petId` against `PetViewModel.pets`). When no pet is attached (legacy "Any pet" assignments), the avatar falls back to a paw-print placeholder.
- Plan title
- Progress badge (To Do / In Progress / Done)

The pet avatar makes it obvious-at-a-glance which pet a plan is for in households with multiple pets.

### Sharing Toggle

`GuardianPlanDetailView` shows a **"Share sessions with trainer"** toggle in the plan header section. (Every plan a guardian sees is trainer-assigned, so the toggle always applies.)

- **Default: on** — all sessions logged under the plan are shared with the trainer.
- Toggling calls `GuardianPlanViewModel.updateSharing(for:isShared:)` → `TrainingPlanService.updateAssignmentSharing(assignmentId:isShared:)` → `UPDATE plan_assignments SET is_shared = ?`.
- The updated value is written to `assignedPlans[idx].assignment.isShared` in-memory immediately.
- When the guardian opens a step to practise, the live `isSharedWithTrainer` value is passed into `TrainingSessionView`. The record is created with that `isShared` value — no per-session toggle is shown for plan-linked sessions.

### Plan Header (Guardian view)

The header section of `GuardianPlanDetailView` shows:

- `Label("Training Plan", systemImage: "list.bullet.clipboard")` — visual category
- `LabeledContent("Description", value: …)` — only rendered when the plan has a non-empty description. Labelled to match the trainer's view of the same field.
- "Assigned <date>" caption
- "Share sessions with trainer" toggle (see above)

### Behavior-Grouped Layout

`GuardianPlanDetailView` renders steps inside a single `Section("Behaviors")`. Inside the section, each behavior is shown as a bold subheader row above its steps, with steps in their `sortOrder` sequence.

```
BEHAVIORS
┌─────────────────────────────────────────────────┐
│ Touch                                           │  ← bold subheader
│ ✓  Touch 1   Arm's length · Instant · None     ▶│  ← complete (green badge + checkmark)
│ 2  Touch 2   6 ft · Instant · None             ▶│  ← in progress, unlocked
│       1 / 3 days                                │     (streak counter, orange)
│ 3  Touch 3   12 ft · Instant · None            🔒│  ← locked (previous step not complete)
│       Complete the previous step first          │
└─────────────────────────────────────────────────┘
```

**Legacy / unbound items** (steps with no `behavior_id`) appear after all behaviors with an "Other Steps" subheader, as a backward-compatibility fallback; they're sequenced among themselves.

### Step Completion (3-day streak)

A step is **complete** once the guardian has logged a **score of 5 on it on 3 consecutive calendar days** (by `training_records.recorded_at`, in `Calendar.current`). Completion is **sticky** — *any* historical run of 3 consecutive perfect days counts, and once earned it stays earned. Computed client-side by `GuardianPlanViewModel.stepCompletion(planItemId:)`, which also returns the longest historical consecutive-day run for the "N / 3 days" progress counter.

`GuardianPlanViewModel.records` (all the guardian's `training_records`) is loaded on the plan detail's `.task` and refreshed by `TrainingSessionView` after each logged session.

### Step Accessibility (sequential gating)

Steps are gated **sequentially within a behavior**: a step is **locked** until the previous step in the *same* behavior is complete. The first step of each behavior is always unlocked, and behaviors are independent — a guardian can work "Touch" and "Down" in parallel.

| State | Visual | Tap action |
|-------|--------|-----------|
| **Complete** | Green circle + white checkmark, green ▶ | Opens `TrainingSessionView` — still trainable (logs another record; completion stays) |
| **In progress** (unlocked, not complete) | Grey circle + step number, grey ▶, "N / 3 days" counter when N > 0 | Opens `TrainingSessionView` |
| **Locked** (previous step in behavior not complete) | Dimmed row, 🔒 icon, "Complete the previous step first" caption | Not tappable |

```swift
// GuardianPlanViewModel
func isStepLocked(_ item: TrainingPlanItem) -> Bool {
    let siblings = (items[item.planId] ?? [])
        .filter { $0.behaviorId == item.behaviorId }
        .sorted { $0.sortOrder < $1.sortOrder }
    guard let index = siblings.firstIndex(where: { $0.id == item.id }), index > 0 else {
        return false   // first step in the behavior — always unlocked
    }
    return !stepCompletion(planItemId: siblings[index - 1].id).isComplete
}
```

There is no longer a single "current step" pointer or locked-step info sheet — the old advancement model was removed (see UC-9.6).

### Dashboard Integration

`DashboardViewModel.load()` fetches `fetchAssignedPlans().count` alongside badges and trainer info. The dashboard "Training Plans" section shows:
- A tappable `"X plans assigned"` button that switches to the Plans tab (tag 2) via a `switchToPlansTab` closure passed from `GuardianTabView`
- `"No plans assigned yet."` when count is zero

---

## UC-9.6: Guardian Practises a Step

**Actor:** Guardian
**Precondition:** Guardian is viewing a plan detail. The step is unlocked (it's the first step of its behavior, or the previous step in its behavior is complete).

The guardian taps an unlocked step, runs a timer while training, then logs how many of 5 reps succeeded. There is **no advancement pointer and no advancement message** — progress is per-step completion (the 3-day streak, see UC-9.5).

### Flow

```
Guardian                  App                        Supabase
  │                         │                            │
  │  Tap an unlocked step   │                            │
  │────────────────────────▶│                            │
  │  TrainingSessionView    │                            │
  │  (sheet) — plan /       │                            │
  │  behavior / step names, │                            │
  │  the step's Three D's,  │                            │
  │  the training timer,    │                            │
  │  a "Train Now" button   │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Tap "Train Now"        │                            │
  │  → timer starts;        │                            │
  │  button → "Done"        │                            │
  │                         │                            │
  │  Reps 0–5 + Notes       │                            │
  │  appear when the timer  │                            │
  │  expires OR when "Done" │                            │
  │  is tapped early        │                            │
  │                         │                            │
  │  Set score, add notes,  │                            │
  │  tap "Done"             │                            │
  │────────────────────────▶│                            │
  │                         │  createRecord(             │
  │                         │    score, plan_item_id,    │
  │                         │    distance/duration/      │
  │                         │    distraction (+ custom)  │
  │                         │    from the step, notes,   │
  │                         │    is_shared from the      │
  │                         │    assignment)             │
  │                         │  status = from(score:)     │
  │                         │───────────────────────────▶│
  │                         │  INSERT training_records   │
  │                         │◀───────────────────────────│
  │  loadRecords() refreshes│                            │
  │  → step completion + the│                            │
  │  "N / 3 days" counter   │                            │
  │  update; the next step  │                            │
  │  may unlock. Sheet      │                            │
  │  dismisses.             │                            │
  │◀────────────────────────│                            │
```

`TrainingSessionView` is the one consistent screen for doing a session — it's also reachable from the pet detail's Training Sessions list ("Train Again"). See `log_training.md` UC-4.1 for the full screen behaviour.

### Score → status

The 0–5 rep score still derives a `TrainingStatus` colour, stored on the record and shown in the reps stepper and the session detail:

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

The status is a per-session readout only — it no longer advances or drops a pointer. What matters for plan progress is whether the step has hit its 3-consecutive-day streak of **score 5** (`green`).

### Vestigial advancement pointer

`GuardianPlanViewModel.advanceCurrentStep` and `plan_assignments.current_item_id` still exist and are still written after a plan-linked session — **only** so the plan-progress badge (To Do / In Progress / Done) keeps working in the interim. They are no longer the progress model and are slated for removal in the "Rework plan progress badge" card. There is no advancement *message* — the alert was removed.

---

## UC-9.7: Guardian Views Plans from Pet Detail

**Actor:** Guardian
**Precondition:** Guardian is viewing a pet's detail screen (`PetDetailView`).

The pet detail screen is a second entry point for plans — a guardian can see all plans their trainer has assigned to a specific pet. It is **read-only**: there is no create or assign affordance (guardians don't author or assign plans — IOS-28).

### Plans Section Layout

`PetDetailView` shows a **Plans** section below the hero photo: a plain `Text("Plans")` header (no `+` button) and a flat list of the plans linked to this pet. Each row taps through to `GuardianPlanDetailView` in a sheet.

The list shows only plans whose `assignment.petId == petId` (i.e. linked to this specific pet). When there are none, an inline message reads *"No training plans for <Pet> yet. Your trainer can assign one."*

### Data Loading

`PetDetailView` loads independently from `GuardianPlanListView` — it fetches all assigned plans via `TrainingPlanService.fetchAssignedPlans()`, filters for `petId` match, and primes `guardianPlanVM.assignedPlans` so `GuardianPlanDetailView` can load items on demand.

```swift
private func loadPetPlans() async {
    let all = (try? await planService.fetchAssignedPlans()) ?? []
    petPlans = all.filter { $0.assignment.petId == petId }
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
    var type: BehaviorType   // "name" column — one of the 12 fixed BehaviorTypes
    var sortOrder: Int       // "sort_order" — scoped within the plan
    let createdAt: Date      // "created_at"
}

// BehaviorType raw values ARE the display labels (not snake_case) so the shared
// `behaviors.name` column stays human-readable; a DB CHECK constraint enforces the set.
enum BehaviorType: String, Codable, CaseIterable, Hashable {
    case sit = "Sit", down = "Down", leaveIt = "Leave It", dropIt = "Drop It",
         stand = "Stand", waitStay = "Wait/Stay", walk = "Walk", touch = "Touch",
         goToMat = "Go to Mat", recall = "Recall", off = "Off", attention = "Attention"
    var label: String { rawValue }
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
    var currentItemId: UUID? // "current_item_id" — vestigial advancement pointer; still written but no longer the progress model (slated for removal)
}
```

`AssignedPlan` is a join result (not a DB row) computed by `TrainingPlanService`:

```swift
struct AssignedPlan: Identifiable, Hashable {
    var id: UUID { assignment.id }
    var assignment: PlanAssignment   // var — mutated in-memory (e.g. sharing toggle)
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
| Guardian plan detail routing | `GuardianPlanListView` is a flat list — every row is a trainer-assigned plan and navigates to `GuardianPlanDetailView` via a single `navigationDestination(for: AssignedPlan.self)`. Guardians cannot create or own plans (IOS-28). |
| `is_shared` on `plan_assignments` | Controls whether sessions logged under a plan are visible to the trainer. `assignPlan` sets `isShared: true` by default. Guardian can toggle per-plan in `GuardianPlanDetailView`. The live value is passed into `TrainingSessionView`; no per-session toggle is shown for plan-linked sessions. |
| `TrainerPlanFormView` | `onSave: (TrainingPlan) -> Void`. Create/edit only — there is no pet picker (guardians can't create plans, so the form is trainer-only). |
| Behavior as intermediate layer | `Behavior` lives in `Core/Models/Behavior.swift`. Items carry a nullable `behaviorId` so old data without behaviors still works. |
| Behavior type | `Behavior.type` is a `BehaviorType` discriminated union — `.standard` (one of 12 presets) or `.custom` (trainer-typed free text). Picked at creation in `TrainerBehaviorFormView`; not editable afterward (no inline rename — change = delete + re-add). Persists as a bare string in `behaviors.name`; a DB `CHECK` (`behaviors_name_nonempty`) only bounds length, not the value set. |
| `AssignedPlan` placement | Lives in `TrainingPlanService.swift`, not `Core/Models/` — it's a join result, not a direct DB row. Follows `LinkedGuardian` pattern in `InviteService.swift`. |
| Step `sortOrder` scope | Scoped **per behavior**, not per plan. `TrainerBehaviorDetailView` shows steps 0…N within that behavior. Guardian detail computes global order via `orderedItems` (behaviors by behavior sortOrder, then items by item sortOrder within each behavior). A raw cross-behavior `sortOrder` comparison would be wrong because each behavior resets at 0. |
| Step gating | Steps are gated sequentially within a behavior — `GuardianPlanViewModel.isStepLocked(_:)` returns true when the previous step in the same behavior isn't complete. Behaviors are independent; the first step of each is always unlocked. Completed steps stay trainable. |
| Step completion | `GuardianPlanViewModel.stepCompletion(planItemId:)` computes, from the guardian's `training_records`, the longest run of consecutive calendar days with a score-5 session. `>= 3` → complete (sticky). Pure logic, unit-tested. |
| Trainer assignment progress | `TrainerPlanViewModel.planProgress(for: PlanAssignment)` computes `.todo / .inProgress / .done` and is displayed as a `PlanProgressBadge` per assignment row in `TrainerPlanDetailView`. |
| Behavior name in session detail | `TrainingRecordDetailView` self-loads the behavior name via `TrainingPlanService.fetchBehaviorName(for: planItemId)` when `planItemId` is non-nil. Two fetches: item → behaviorId → behavior name. Shown in the Three D's section alongside Distance, Duration, Distraction. |
| Custom Three D values | Stored as dedicated nullable columns; the enum column stores `"custom"` as the raw value. Display resolves at read time via `displayLabel(customValue:)`. Never stored on non-custom rows. |
| Assignment block | Computed in `TrainerPlanDetailView.assignBlockReason` — no network call, uses already-loaded `behaviors` and `items` dictionaries. |
| Assign sheet navigation | Presented as `.sheet` with own `NavigationStack` — avoids mixing `navigationDestination` styles in the trainer's nav stack. |
| Reorder atomicity | Delete + re-insert is not transactional. On failure the app reloads from Supabase to recover consistent state. Acceptable for MVP. |
| `trainer_id` on `plan_assignments` | Added to avoid infinite RLS recursion: `training_plans` policy checked `plan_assignments`, which checked back to `training_plans`. |
| Status derivation | `TrainingStatus.from(score:)` is the single source of truth — called by `TrainingRecordService` (on write) and `TrainingSessionView` (for the live reps preview). Manual status selection has been removed entirely. |
| Vestigial advancement pointer | `advanceCurrentStep` / `current_item_id` are still written after a plan-linked session, but only to keep the plan-progress badge alive in the interim — they're no longer the progress model. Removal is tracked in the "Rework plan progress badge" card. |

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
| Behavior deleted by trainer | `ON DELETE CASCADE` removes all steps in that behavior and their `training_records` references go `ON DELETE SET NULL` on `plan_item_id` |
| Guardian has no plans | "Ask your trainer to assign a training plan." in Plans tab |
| Guardian trains a completed step again | Completed steps stay tappable — a new record is logged. Completion is sticky, so it stays complete. |
| Locked step tapped | Nothing happens — the row is `.disabled` (dimmed, 🔒 icon, "Complete the previous step first" caption). It's locked until the previous step in its behavior is complete. |
| `.sheet(item:)` for step sheets | Both practice and info sheets use `.sheet(item:)` to avoid the SwiftUI timing race where content can be nil if `isPresented` fires before the item binding updates. |
| Reorder network failure | In-memory state reverted by reloading items from Supabase |
| Guardian at last step scores green | `min(currentIdx + 1, sorted.count - 1)` clamps — stays at last step, shows "mastered all steps" message |
| Guardian at first step scores red | `max(currentIdx - 1, 0)` clamps — stays at first step, shows encouragement message |
| `currentItemId` references a deleted item | `ON DELETE SET NULL` resets the (vestigial) pointer to nil — harmless; it no longer drives the UI |
| Step with old records but a now-incomplete predecessor | A step can be locked yet still carry historical records (e.g. trained before the gating rule, or before its predecessor regressed). The lock is based purely on the *previous* step's completion; the locked step's own streak just isn't shown while locked. |
| Plan-linked session sharing | `isShared` on the record is set from `assignment.isShared` at creation time — no per-session override. Toggling the plan-level sharing toggle forward only affects new sessions. |
| Guardian toggles sharing off mid-plan | Existing session records retain their original `is_shared` value — only future sessions pick up the new setting. |
| Step with `.custom` distance but empty string in DB | `displayLabel(customValue:)` falls back to `"Custom"` — shown to guardian but never occurs when form validation is respected |
| Legacy plan with no behaviors | Guardian detail shows a flat "Steps" section; no "Other Steps" header if there are also no unbound items |
| Behavior name in session detail | `TrainingRecordDetailView` calls `fetchBehaviorName(for: planItemId)` on appear; nil is returned for standalone sessions or steps with no behavior — row is simply hidden. |

---

## Test Flows

1. **Create plan (trainer)**: Sign in as trainer → Plans → "+" → enter title and description → Create → plan appears in list.
2. **Guardian cannot create plans**: Sign in as guardian → Plans tab → there is no "+" button; the empty state reads *"Ask your trainer to assign a training plan."*
3. **Guardian plan list — no delete**: Sign in as guardian → Plans tab → swipe left on any plan row → no delete action available (guardians don't own plans).
4. **Add standard behavior (trainer)**: Tap plan → "Add Behavior" → list of the 12 standard presets → tap "Recall" → Add → "Recall" appears with "0 steps".
4b. **Add custom behavior (trainer)**: "Add Behavior" → leave presets unselected → type "Heel" in the Custom field → Add → "Heel" appears with "0 steps". (Typing in Custom clears any preset checkmark and vice versa.)
5. **Add duplicate behavior**: "Add Behavior" → pick a type already in the plan → Add → it's added again (duplicates are allowed).
6. **Behavior detail has no Name section**: Tap a behavior → the view is just the behavior name (nav title) + "Steps" header + steps; there is no editable Name field.
7. **Reorder behaviors**: Long-press `≡` handle → drag to new position → navigate away and back → order persists.
8. **Add steps to a behavior**: Tap "Recall" → "Add Step" → enter "Sit at arm's length" → Distance: Arm's length, Duration: Instant, Distraction: None → Add → step appears with capsule tags.
9. **Add step with custom D**: "Add Step" → Distance: pick "Custom" → text field appears → type "20 feet in hallway" → Add → capsule shows "20 feet in hallway".
10. **Edit step**: Swipe left on a step → Edit → change Duration to Custom → type "hold for 3 seconds" → Save → capsule updates.
11. **Reorder steps**: Long-press handle in behavior detail → drag to new position → persists in Supabase.
12. **Assignment block — no behaviors**: Plan with no behaviors → "Assign to Guardian…" is absent; warning label shown instead.
13. **Assignment block — empty behavior**: Plan with "Recall" (0 steps) → warning shows `"Recall" has no steps…`.
14. **Assign plan**: All behaviors have steps → tap "Assign to Guardian…" → select guardian → optionally select pet → Assign → assignment row shows guardian name + "To Do" badge.
15. **Trainer sees progress**: Guardian practices a step → trainer opens same plan detail → assignment row shows "In Progress" badge.
16. **Duplicate assignment**: Assign same plan to same guardian again → "already assigned" error shown.
17. **Guardian views plan (behaviors)**: Sign in as guardian → Plans tab → tap a plan → steps shown grouped by behavior; the first step of each behavior is unlocked; later steps are locked (dimmed, 🔒) until the previous step in the behavior is complete.
18. **Practise a step**: Tap an unlocked step → `TrainingSessionView` → "Train Now" (timer starts) → let the timer expire (or tap "Done" early) → Reps + Notes appear → set score, tap "Done" → session logged, sheet dismisses. No advancement message.
19. **Locked step is not tappable**: Tap a locked step → nothing happens; the row shows 🔒 + "Complete the previous step first".
20. **Step completion unlocks the next**: Log a score-5 session on the first step of a behavior on 3 consecutive calendar days → the step shows the green checkmark badge and the next step in that behavior unlocks.
21. **Streak counter**: Log a score-5 on a step on 1–2 consecutive days → the step shows "1 / 3 days" / "2 / 3 days" in orange; a non-5 day or a gap resets it.
22. **Behaviors are independent**: Completing the last step needed in behavior A does not lock or unlock anything in behavior B; behavior B's first step is always reachable.
23. **Train Again from Pet detail**: Pet detail → Training Sessions → tap a session → "Train Again" → `TrainingSessionView` opens for that step.
24. **Behavior name in record detail**: After a plan-linked session → open the record in the pet's Training Sessions list → the detail's Three D's section shows "Behavior: [name]" above Distance/Duration/Distraction.
25. **Dashboard count**: Guardian home → "Training Plans" shows "1 plan assigned" → tap → switches to Plans tab.
26. **Pet Detail plans section**: Trainer assigns a plan to a guardian's pet → guardian opens that Pet Detail → the plan appears in the Plans section (read-only — no "+" / create / assign affordance).
27. **Trainer sharing default on**: Guardian linked to a trainer → trainer assigns a plan → Guardian views plan detail → "Share sessions with trainer" toggle is ON.
28. **Toggle sharing off**: Guardian opens an assigned plan detail → toggles "Share sessions with trainer" off → logs a session → in Supabase `training_records` the new row has `is_shared = false`; trainer's guardian detail no longer shows new sessions for this plan.
29. **No per-session toggle for plan sessions**: Guardian practises a step → `TrainingSessionView` shows no "Share with Trainer" toggle (sharing is plan-level).
