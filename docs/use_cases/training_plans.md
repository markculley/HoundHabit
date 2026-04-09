# Phase 9: Training Plans

## Overview

Trainers create reusable training plans composed of ordered steps, assign them to linked guardians (optionally tied to a specific pet), and guardians view their assigned plans read-only. The dashboard surfaces a plan count with a direct link to the Plans tab.

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

**`TrainerPlanFormView`** uses `PlanFormMode` (`.create` / `.edit(TrainingPlan)`) to handle both create and edit in one view. The "Plan Description" section placeholder makes clear this is a high-level overview — steps are added separately after creation.

---

## UC-9.2: Trainer Adds and Reorders Steps

**Actor:** Trainer  
**Precondition:** Trainer is viewing a plan in `TrainerPlanDetailView`.

### Flow

```
Trainer                   App                        Supabase
  │                         │                            │
  │  Tap "Add Step"         │                            │
  │────────────────────────▶│                            │
  │  TrainerPlanItemFormView │                            │
  │  (sheet)                │                            │
  │                         │                            │
  │  Enter title +          │                            │
  │  instructions, tap Add  │                            │
  │────────────────────────▶│                            │
  │                         │  createItem(planId,        │
  │                         │    title, desc, sortOrder) │
  │                         │───────────────────────────▶│
  │                         │  INSERT training_plan_items│
  │                         │◀───────────────────────────│
  │  Step appears in list   │                            │
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
  │                         │◀───────────────────────────│
  │  "Assigned To" section  │                            │
  │  shows guardian + date  │                            │
  │◀────────────────────────│                            │
```

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
  │  Steps shown read-only  │                            │
  │◀────────────────────────│                            │
```

### Dashboard Integration

`DashboardViewModel.load()` fetches `fetchAssignedPlans().count` alongside badges and trainer info. The dashboard "Training Plans" section shows:
- A tappable `"X plans assigned"` button that switches to the Plans tab (tag 3) via a `switchToPlansTab` closure passed from `GuardianTabView`
- `"No plans assigned yet."` when count is zero

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
    let planId: UUID         // "plan_id"
    var sortOrder: Int       // "sort_order"
    var title: String
    var description: String?
}

struct PlanAssignment: Codable, Identifiable, Hashable {
    let id: UUID
    let planId: UUID         // "plan_id"
    let trainerId: UUID      // "trainer_id" — stored to avoid recursive RLS
    let guardianId: UUID     // "guardian_id"
    let petId: UUID?         // "pet_id" — nullable
    let assignedAt: Date     // "assigned_at"
}
```

`AssignedPlan` is a join result (not a DB row) computed by `TrainingPlanService`:

```swift
struct AssignedPlan: Identifiable, Hashable {
    var id: UUID { assignment.id }
    let assignment: PlanAssignment
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

---

## Edge Cases

| Scenario | Behaviour |
|----------|-----------|
| Plan assigned twice to same guardian | Postgres `UNIQUE` constraint throws; app shows "already assigned" message |
| Guardian unlinked after assignment | Plan remains visible (assignment row persists); trainer can delete assignment manually |
| Plan deleted by trainer | `ON DELETE CASCADE` removes all items and assignments |
| Guardian has no plans | "No plans assigned yet." in both Plans tab and dashboard |
| Reorder network failure | In-memory state reverted by reloading items from Supabase |

---

## Test Flows

1. **Create plan**: Sign in as trainer → Plans → "+" → enter title and description → Create → plan appears in list.
2. **Add and reorder steps**: Tap plan → Add Step → add 3 steps → long-press `≡` handle on a row → drag to new position → navigate away and back → order persists.
3. **Edit step**: Swipe left on a step → Edit → change title → Save → title updates in list.
4. **Assign plan**: Tap "Assign" → select guardian → optionally select pet → tap Assign → "Assigned To" section shows guardian name and date.
5. **Duplicate assignment**: Assign same plan to same guardian again → "already assigned" error shown.
6. **Guardian views plan**: Sign in as guardian → Plans tab → plan listed with title and assigned date → tap plan → steps shown in correct order, read-only.
7. **Dashboard count**: Guardian home screen → "Training Plans" section shows "1 plan assigned" → tap → switches to Plans tab.
8. **No plans**: Guardian with no assignments sees "No plans assigned yet." in both dashboard and Plans tab.
