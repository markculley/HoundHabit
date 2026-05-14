# Premise

A training tracker that is needed by pet owners to bridge the gap between the last Trainer visit and the next. Further, after the last Trainer visit, this tool can be used to manage ongoing owner training.

## Definitions
- Guardian: a pet owner

## Intended Buyer

1. Trainers who then direct guardians to download the app
2. Guardian who wants to use it

## What it Doesn’t Do

- Auto-generate or prescribe a Training Plan (all plans are user-created)
- No promises. No Guarantees
- Doesn’t teach the Guardian how to train. That’s the Trainer’s job.

## What it Does Do

- Enables guardians to track Training Sessions
- Enables guardians to track more than one pet
- Enables guardians to share training results
- Enables guardians to store video recording or photos of their or a pet
- Enables guardians to read Trainer-delivered notes
- Enables Trainers to deliver training plans to guardians


## build artifacts
Hound Habit is a multi-platform mobile app with a shared backend:

- **iOS app** — native SwiftUI, this repo (`hound_habit`)
- **Android app** — native Kotlin + Jetpack Compose, separate repo (`hound_habit_android`)
- **Backend** — Supabase (Postgres + Auth + Storage + RLS). Both clients hit the same Supabase project; schema, RLS policies, and RPCs (e.g. `delete_my_account`) are shared. See [why_supabase.md](why_supabase.md).

## iPhone
- assume that users have purchased their iPhone in the last three years
- assume that in an iPhone bought three years ago is fully updated. What ios version would that be? That is the minimum supported version

## android
- assume that users have purchased their Android in the last three years
- assume that in an Android phone bought three years ago is fully updated. What os version would that be? That is the minimum supported version

## IPad and Android tablets
This is a stretch goal. Not part of MVP. It would be nice to support this.


# Use Cases

## Guardian

### First Time Use

- Create an account
- Visit Home Screen

### Saving References

- articles
- YouTube videos
- Document
- Videos & Photos
    - Associated Notes
    - Date stamp

### Share Account (Grant Access) …to Trainer

- Permissions
    - Read, Write, Comment

### Log a Training Session

- Log a *Training Record*

### Create a Pet

- Create a *Pet Record*

### Remind Me

- To do an activity

### Set a Timer

- For treating
- Fire play time
- Etc

## Trainer

### CRUD a Guardian

- Guardian Record
- Create/Read/Update/Delete a Guardian

### Create a Training Plan for a Guardian

- Design a Training Record

### Share Training Plan with a Guardian

- with one or more guardians

### View Guardians

- View a selectable list of Guardians

### Select Guardian

- from the **View Guardians** result

### View Guardian

- View *Guardian Record*
- View *Pet Records*
- View *Training Plan* records
- View *Training* records

### Link/Unlink Guardians

- Two Guardian for one or more pets

### Comment on a Training (Record)

- Ideally in Confluence-style but …

### Add Resource to Guardian Resources

- URL
- Photo
- Note
- etc.

## Hound Habit App

- Analyze Training Records and suggest what?

# Features

## CRUD a Training Plan

- Used by trainers
- A Training Plan contains one or more **Behaviors**
- A Behavior contains one or more **Steps**
- Hierarchy: Training Plan → Behavior → Step

### Training Plan Detail (Trainer)
- Header section shows plan title, description, and "Assigned To" (Guardian name, or an "Assign" button when unassigned)
- Body lists Behavior names with an "Add Behavior" button

### Behavior
- Properties: Type, ordered list of Steps
- A Behavior's type is picked from a **fixed list** of the 12 standard behaviors — not free text:
  - Sit, Down, Leave It, Drop It, Stand, Wait/Stay, Walk, Touch, Go to Mat, Recall, Off, Attention
- Tapping a Behavior in the plan detail opens the Behavior detail view, which shows the behavior as the title and lists its Steps (the type is set at creation and is not editable from the detail view — to change it, delete and re-add the behavior)

### Step (Training Plan Item)
- Properties: Title, Three D's (Distance, Duration, Distraction)
- Three D's have preset options **and** a free-text custom value option:
  - Distance presets: Arm's Length, 6 ft, 12 ft; + Custom
  - Duration presets: Instant, 5 Seconds; + Custom
  - Distraction presets: None, Any; + Custom

## Attach Training Plan to Pet

- If created separately of course
- **Pet is required when a plan is assigned to a guardian.** A pet is only optional at plan-creation time — the trainer (or guardian) can draft a plan without any pet attached. Once that plan is being assigned to a guardian, a specific pet must be selected. If the guardian has no pets yet, the assignment is blocked until they add one.

## CRUD a Training Record

- Only Guardians can do this
- For a Pet

## CRUD a Resource Record

- Only Guardians can do this

## CRUD a Behavior Record

- For a Pet

## CRUD a Pet Record

- Only Guardians can do this

## CRUD a Guardian Record

- Not delete of course
- Only Guardians can do this

## Link Guardian Records

- Husband and Wife scenario
- Only Trainers can do this
- Maybe v2 Guardians could do this

# Database

## Resource Record

**Table Properties**

- image
- video
- notes
- url
- etc

## Behavior Record

A Behavior is a child of a Training Plan and a parent of Steps.

**Table Properties**

- `plan_id` — FK to Training Plan
- `name` — the behavior type, one of the 12 standard behaviors (a DB `CHECK` constraint enforces the valid set). Stored as the human-readable label (e.g. `"Sit"`, `"Wait/Stay"`). Not free text.
- `sort_order` — display order within the plan

## Pet Record

**Table Properties**

- **Status History**
- **Pet name**
- **Photo**

## Guardian Record

**Table Properties**

- traditional person properties
- Client start - when the Guardian became a client
- Client end - when the Guardian stopped being a client
- Client History - start and end history
- notes

## Training Record

**Table Properties**

- **Pet Name**
- **DateTime**
- **Share**
- **Status**
    - red - not getting it
    - orange - occasional success
    - yellow - half way there
    - green - Success
- **What’s Next** - What the guardian should do next
- **Three D**’s.
    - Distance - Owner editable
        - Arm’s length
        - 6 feet
        - 12 feet
        - Custom (free text)
    - Distraction - Owner editable
        - None
        - Any
        - Custom (free text)
    - Duration - Owner editable
        - Instant
        - 5 seconds
        - Custom (free text)
- **Notes**

# v2 Backlog

## Guardian → Trainer Resource Sharing

Guardians can currently only receive resources from their trainer. In v2, a guardian should be able to share a resource (photo, note, URL) back to their trainer — for example, a progress photo or a video of a session.

**Suggested approach:** Add `is_shared_with_trainer boolean NOT NULL DEFAULT false` to the `resources` table. Guardians can toggle sharing per resource. The trainer's guardian detail view shows shared resources alongside shared session records.

For text messages, the existing comment thread on a training session already covers the immediate need in v1.

## Guardian-Created Training Plans

An earlier build let a guardian create and manage their own training plans without a trainer ("My Plans"). It was removed (see iOS card IOS-28 / the Android equivalent) — the flow was confusing alongside trainer-assigned plans, and a guardian authoring their own Behavior → Step plans is a meaningfully different product than the trainer-delivered model. Deferred to a future enhancement.

If revisited: a guardian-created plan was just a `training_plans` row with `trainer_id` = the guardian's own user id, plus a self-assignment in `plan_assignments` where `trainer_id == guardian_id`. The enabling RLS policy (`"Guardian self-assigns own plans"` INSERT on `plan_assignments`) was dropped; restoring the feature means re-adding that policy (or equivalent) and the guardian-side authoring UI.
