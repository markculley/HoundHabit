# Phase 8: Trainer — View Guardian Records & Comment

## Overview

After a trainer-guardian link is established (Phase 7), the trainer can browse a linked guardian's pets and shared training sessions, and leave comments on individual records. Guardians see those comments read-only when they open the same record.

---

## UC-8.1: Trainer Views Guardian's Shared Records

**Actor:** Trainer  
**Precondition:** At least one active trainer-guardian link exists.

### Flow

```
Trainer                   App                        Supabase
  │                         │                            │
  │  Tap "Guardians" tab    │                            │
  │────────────────────────▶│                            │
  │                         │  fetchLinkedGuardians()    │
  │                         │───────────────────────────▶│
  │                         │  trainer_guardian_links    │
  │                         │  JOIN profiles             │
  │                         │◀───────────────────────────│
  │  Guardian list shown    │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Tap guardian row       │                            │
  │────────────────────────▶│                            │
  │                         │  fetchPets(guardianId)     │
  │                         │  fetchRecords(guardianId)  │ ← parallel async let
  │                         │───────────────────────────▶│
  │                         │  pets WHERE guardian_id=?  │
  │                         │  training_records WHERE    │
  │                         │    guardian_id=?           │
  │                         │    AND is_shared=true      │ ← RLS enforces
  │                         │◀───────────────────────────│
  │  GuardianDetailView     │                            │
  │  shows pets + sessions  │                            │
  │◀────────────────────────│                            │
```

### RLS Enforcement

The trainer sees only `is_shared = true` records — this is enforced entirely at the Postgres layer:

```sql
-- training_records SELECT policy
CREATE POLICY "Trainer can read linked guardian records"
ON training_records FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM trainer_guardian_links tgl
    WHERE tgl.trainer_id = auth.uid()
      AND tgl.guardian_id = training_records.guardian_id
      AND tgl.status = 'active'
  )
  AND is_shared = true
);
```

No app-level filtering is needed in `GuardianViewModel.load(guardian:)`.

### Key Code

**`GuardianViewModel.load(guardian:)`** in [GuardianDetailView.swift](../../HoundHabit/Trainer/Guardians/GuardianDetailView.swift):
```swift
async let fetchedPets    = petService.fetchPets(guardianId: guardian.guardianId)
async let fetchedRecords = recordService.fetchRecords(guardianId: guardian.guardianId)
pets    = try await fetchedPets
records = try await fetchedRecords
```
Parallel `async let` minimises latency — both queries fire simultaneously.

**`RecordNavItem`** — a small `Hashable` wrapper used for value-based navigation:
```swift
struct RecordNavItem: Hashable {
    let record: TrainingRecord
    let petName: String
}
```
Required because `navigationDestination(for:)` can only carry one value, but the detail view needs both the record and the resolved pet name.

---

## UC-8.2: Trainer Adds a Comment

**Actor:** Trainer  
**Precondition:** Trainer is viewing a shared record in `TrainingRecordDetailView` (read-only mode).

### Flow

```
Trainer                   App                        Supabase
  │                         │                            │
  │  Tap record row         │                            │
  │────────────────────────▶│                            │
  │                         │  loadComments(for: record) │
  │                         │───────────────────────────▶│
  │                         │  comments WHERE            │
  │                         │    training_record_id = ?  │
  │                         │    ORDER BY created_at ASC │
  │                         │◀───────────────────────────│
  │  Detail view + comments │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Type comment, tap Send │                            │
  │────────────────────────▶│                            │
  │                         │  addComment(recordId, body)│
  │                         │───────────────────────────▶│
  │                         │  INSERT INTO comments      │
  │                         │    (training_record_id,    │
  │                         │     author_id,             │ ← auth.uid()
  │                         │     body)                  │
  │                         │  RETURNING *               │
  │                         │◀───────────────────────────│
  │  Comment appears in list│                            │
  │◀────────────────────────│                            │
```

### Comment Section Logic

The `commentSection` in `TrainingRecordDetailView` is shown when `onAddComment != nil || !comments.isEmpty || selfLoadComments`. The input row only renders when `onAddComment` is non-nil — so guardians (who get no closure) see comments read-only.

```swift
// Shown when trainer (onAddComment provided)
if onAddComment != nil {
    CommentInputRow(text: $newCommentBody, isSending: isSendingComment, onSend: sendComment)
}
```

### RLS

```sql
-- comments INSERT policy
CREATE POLICY "Author can insert own comments"
ON comments FOR INSERT
WITH CHECK (
  author_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM training_records tr
    WHERE tr.id = training_record_id
    AND (
      tr.guardian_id = auth.uid()                           -- own record
      OR EXISTS (                                           -- linked guardian
        SELECT 1 FROM trainer_guardian_links tgl
        WHERE tgl.trainer_id = auth.uid()
          AND tgl.guardian_id = tr.guardian_id
          AND tgl.status = 'active'
      )
    )
  )
);
```

---

## UC-8.3: Trainer Deletes Own Comment

**Actor:** Trainer  
**Precondition:** Trainer has at least one comment on a record.

Swipe left on a comment row (swipe-to-delete). Only the comment's author sees the delete action — enforced both in the UI (`isOwn` check in `CommentRow`) and in Postgres.

```sql
-- comments DELETE policy
CREATE POLICY "Author can delete own comments"
ON comments FOR DELETE
USING (author_id = auth.uid());
```

---

## UC-8.4: Guardian Reads Trainer Comments

**Actor:** Guardian  
**Precondition:** At least one comment exists on a record.

When the guardian opens a training record from `TrainingRecordListView`, `selfLoadComments: true` is passed. The detail view self-loads comments via `.task`:

```swift
// In TrainingRecordDetailView.recordContent(_:)
.task(id: r.id) {
    guard selfLoadComments else { return }
    selfLoadedComments = (try? await commentService.fetchComments(recordId: r.id)) ?? []
}
```

No closures are passed, so the comment section renders as read-only — no input row, no delete swipe action.

```
Guardian                  App                        Supabase
  │                         │                            │
  │  Tap training record    │                            │
  │────────────────────────▶│                            │
  │                         │  fetchComments(recordId)   │
  │                         │───────────────────────────▶│
  │                         │  comments WHERE            │
  │                         │    training_record_id = ?  │ ← RLS: own record
  │                         │◀───────────────────────────│
  │  Comments visible,      │                            │
  │  no input shown         │                            │
  │◀────────────────────────│                            │
```

---

## Data Model

```swift
struct Comment: Codable, Identifiable, Hashable {
    let id: UUID
    let trainingRecordId: UUID   // "training_record_id"
    let authorId: UUID           // "author_id"
    let body: String
    let createdAt: Date          // "created_at"
    let updatedAt: Date          // "updated_at"
}
```

Supabase table:

| Column              | Type        | Notes                              |
|---------------------|-------------|------------------------------------|
| id                  | uuid PK     | gen_random_uuid()                  |
| training_record_id  | uuid FK     | → training_records.id              |
| author_id           | uuid FK     | → auth.users.id (trainer or guardian) |
| body                | text        | NOT NULL                           |
| created_at          | timestamptz | default now()                      |
| updated_at          | timestamptz | default now()                      |

---

## Architecture: Comment Thread Ownership

The comment thread is implemented with a **closure-injection** pattern rather than a role enum, which keeps `TrainingRecordDetailView` role-agnostic:

| Caller             | `onAddComment` | `onDeleteComment` | `selfLoadComments` | Result                      |
|--------------------|----------------|-------------------|--------------------|-----------------------------|
| Guardian (own)     | nil            | nil               | true               | Read-only thread, self-loads |
| Trainer (detail)   | `{ ... }`      | `{ ... }`         | false              | Full CRUD, loads externally  |
| Guardian (existing)| nil            | nil               | false              | No comment section           |

---

## Edge Cases

| Scenario                                  | Behaviour                                                  |
|-------------------------------------------|------------------------------------------------------------|
| Record has no comments                    | "No comments yet." placeholder shown                       |
| Trainer submits empty comment             | `sendComment()` guards on `trimmed.isEmpty` — no-op       |
| Network failure on comment load           | `try?` swallows error; shows empty section silently        |
| Guardian tries to delete trainer comment  | `isOwn` is false → swipe action not rendered               |
| Trainer tries to delete guardian comment  | `isOwn` is false → swipe action not rendered               |
| Guardian record is not shared             | RLS blocks trainer query; record never appears in list     |

---

## Test Flows

1. **Trainer views records**: Link a guardian. Sign in as **guardian**, log 3 sessions — enable "Share with Trainer" on 2 of them, leave it off on the third. Sign in as **trainer** → Guardians → tap that guardian → "Shared Sessions" shows exactly 2 records; the unshared one is absent.
2. **Trainer adds comment**: Tap a record → type comment → tap Send → comment appears with "You" label and timestamp.
3. **Trainer deletes comment**: Swipe left on own comment → "Delete" action → comment removed from list.
4. **Guardian reads comment**: Sign in as guardian → open the same record → trainer's comment visible, no input row shown.
5. **Comment persists**: Restart the app as trainer → same comment still appears (Supabase round-trip confirmed).
6. **Empty state**: Record with no comments shows "No comments yet." for both trainer and guardian.
7. **Non-shared record hidden**: Create a record with `isShared = false` → trainer's guardian detail shows no such record.
