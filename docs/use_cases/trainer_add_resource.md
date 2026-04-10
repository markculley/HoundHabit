# Phase 11: Trainer Add Resources to Guardian

## Overview

Trainers can add resources (notes, URLs, photos) directly to a linked guardian's resource library. The guardian sees trainer-added resources alongside their own in the Resources tab.

---

## UC-11.1: Trainer Adds a Resource to a Guardian

**Actor:** Trainer  
**Precondition:** Trainer is authenticated and has at least one linked guardian.

### Flow

```
Trainer                   App                        Supabase
  │                         │                            │
  │  Guardians tab →        │                            │
  │  tap guardian name      │                            │
  │────────────────────────▶│                            │
  │  GuardianDetailView     │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Tap + (toolbar)        │                            │
  │────────────────────────▶│                            │
  │  TrainerAddResourceView │                            │
  │  sheet presented        │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Select kind, fill in   │                            │
  │  title + content        │                            │
  │  Tap Save               │                            │
  │────────────────────────▶│                            │
  │                         │  INSERT resources          │
  │                         │  owner_id = guardian_id    │
  │                         │  added_by_id = trainer_id  │
  │                         │  guardian_id = guardian_id │
  │                         │───────────────────────────▶│
  │                         │◀───────────────────────────│
  │  Sheet dismissed        │                            │
  │◀────────────────────────│                            │
```

### Resource Kinds

| Kind | Content |
|------|---------|
| Note | Free-text body |
| URL | Web link + optional notes |
| Photo | Image upload + optional notes |

---

## Architecture

### RLS Policies

**`resources` table INSERT** (`materials_insert_trainer`):
```sql
added_by_id = auth.uid()
AND EXISTS (
  SELECT 1 FROM trainer_guardian_links
  WHERE trainer_id = auth.uid()
    AND guardian_id = resources.guardian_id
    AND status = 'active'
)
```

**`resources` storage bucket INSERT** (`resources_storage_insert`):
```sql
bucket_id = 'resources' AND (
  foldername(name)[1] = auth.uid()::text
  OR EXISTS (
    SELECT 1 FROM trainer_guardian_links
    WHERE trainer_id = auth.uid()
      AND guardian_id::text = foldername(name)[1]
      AND status = 'active'
  )
)
```

The storage policy was extended in Phase 11 to allow trainers to upload photos to a linked guardian's folder (`{guardianId}/{resourceId}.jpg`).

### `ResourceService.createResourceForGuardian`

Separate method from the guardian's `createResource` — sets `owner_id` and `guardian_id` to the target guardian, `added_by_id` to the trainer.

### Guardian Visibility

The guardian's `ResourceListView` queries `resources` filtered by `guardian_id = auth.uid()`, which returns both self-added and trainer-added resources. No changes needed on the guardian side.

---

## Test Flow

1. Sign in as Trainer → tap a linked guardian → tap **+**
2. Add a **Note**: enter title + note text → Save → sheet dismisses
3. Add a **URL**: enter title + URL → Save → sheet dismisses
4. Add a **Photo**: enter title + pick photo → Save → sheet dismisses
5. Sign out → sign in as Guardian → Settings → Resources → all three resources appear
6. Verify trainer-added resources are not deletable by... (deletion is `added_by_id = auth.uid() OR guardian_id = auth.uid()` — both trainer and guardian can delete)

---

## Edge Cases

| Scenario | Behaviour |
|----------|-----------|
| Trainer not linked to guardian | RLS blocks INSERT — error shown |
| Photo upload to guardian's storage folder | Allowed via updated storage policy for linked trainers |
| Guardian deletes trainer-added resource | Permitted — `guardian_id = auth.uid()` satisfies DELETE policy |
| Trainer deletes their own added resource | Permitted — `added_by_id = auth.uid()` satisfies DELETE policy |
