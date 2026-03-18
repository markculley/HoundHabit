# HabitHound iPhone MVP — Architecture & Execution Plan

## Context

HabitHound is a pet training tracker app. It bridges the gap between trainer visits by letting pet owners (Guardians) log training sessions, view progress, and receive training plans from professional Trainers. This plan covers the iPhone MVP with both Guardian and Trainer roles, Supabase backend, online-only operation, photo support, local notifications, and a streaks/badges reward system.

---

## Architecture

### Stack
- **Frontend**: SwiftUI (iOS 17+), `@Observable` ViewModels
- **Backend**: Supabase (PostgreSQL + Auth + Storage)
- **Auth**: Email/password + Sign in with Apple
- **Media**: Photos only via Supabase Storage
- **Notifications**: Local only (`UNUserNotificationCenter`)
- **Dependencies**: `supabase-swift` v2.x only; all else is system frameworks

### Pattern: MVVM + Service Layer
- **Models** — pure `Codable` structs. Supabase returns JSON with snake_case field names (`guardian_id`, `recorded_at`); Swift uses camelCase (`guardianId`, `recordedAt`). Each model defines `CodingKeys` to map between the two so JSON decoding works automatically.
- **Services** — stateless `async throws` wrappers around Supabase client
- **ViewModels** — `@Observable` classes, owned by views via `@State`
- **AppRouter** — single source of truth: `.unauthenticated` | `.guardian` | `.trainer`

### Folder Structure
```
HabitHound/
├── HabitHoundApp.swift
├── AppRouter.swift
├── Core/
│   ├── Auth/          (AuthViewModel, LoginView, SignUpView, RoleSelectionView)
│   ├── Models/        (Profile, Pet, TrainingRecord, TrainingPlan, TrainingPlanItem,
│   │                   Material, Comment, TrainerGuardianLink, Badge)
│   ├── Services/      (SupabaseClient, AuthService, PetService, TrainingRecordService,
│   │                   TrainingPlanService, MaterialService, CommentService,
│   │                   InviteService, StorageService)
│   └── Extensions/    (Color+Status, Date+Formatting)
├── Guardian/
│   ├── GuardianTabView.swift
│   ├── Dashboard/     (DashboardView, DashboardViewModel)
│   ├── Pets/          (PetListView, PetDetailView, PetFormView, PetViewModel)
│   ├── TrainingRecords/
│   ├── Materials/
│   ├── Plans/
│   ├── Achievements/
│   └── Settings/
├── Trainer/
│   ├── TrainerTabView.swift
│   ├── Guardians/
│   ├── Plans/
│   ├── Invites/
│   └── Settings/
└── Shared/
    ├── Components/    (StatusBadgeView, PetAvatarView, PhotoPickerView,
    │                   TimerView, EmptyStateView)
    └── Utilities/     (NotificationManager, HapticManager)
```

### Navigation

**Guardian Tabs**: Home · Pets · Log (center) · Materials · Settings

**Trainer Tabs**: Guardians · Plans · Invite · Settings

---

## Database Schema (Supabase / PostgreSQL)

### Tables

**`profiles`** — extends `auth.users`
```
id uuid PK (references auth.users), role text ('guardian'|'trainer'),
full_name text, avatar_url text, created_at/updated_at timestamptz
```

**`pets`**
```
id uuid PK, guardian_id uuid FK→profiles, name text NOT NULL,
breed text, photo_url text, created_at/updated_at timestamptz
```

**`training_records`**
```
id uuid PK, pet_id uuid FK→pets, guardian_id uuid FK→profiles,
recorded_at timestamptz, status text ('red'|'orange'|'yellow'|'green'),
distance text ('arms_length'|'6_feet'|'12_feet'|'20_feet'|'20_plus_feet'),
distraction text ('none'|'any'),
duration text ('instant'|'5_seconds'|'5_plus_seconds'),
notes text, is_shared boolean DEFAULT false, created_at/updated_at timestamptz
```

**`training_plans`**
```
id uuid PK, trainer_id uuid FK→profiles, title text NOT NULL,
description text, created_at/updated_at timestamptz
```

**`training_plan_items`**
```
id uuid PK, plan_id uuid FK→training_plans ON DELETE CASCADE,
sort_order integer DEFAULT 0, title text NOT NULL, description text
```

**`plan_assignments`**
```
id uuid PK, plan_id uuid FK→training_plans, guardian_id uuid FK→profiles,
pet_id uuid FK→pets (nullable), assigned_at timestamptz
```

**`materials`**
```
id uuid PK, owner_id uuid FK→profiles, added_by_id uuid FK→profiles,
guardian_id uuid FK→profiles, kind text ('photo'|'url'|'note'),
url text, body text, title text, created_at timestamptz
```

**`comments`**
```
id uuid PK, training_record_id uuid FK→training_records ON DELETE CASCADE,
author_id uuid FK→profiles, body text NOT NULL, created_at/updated_at timestamptz
```

**`trainer_guardian_links`**
```
id uuid PK, trainer_id uuid FK→profiles, guardian_id uuid FK→profiles,
status text ('active'|'inactive') DEFAULT 'active', linked_at timestamptz,
UNIQUE(trainer_id, guardian_id)
```

**`invites`**
```
id uuid PK, trainer_id uuid FK→profiles, email text NOT NULL,
code text NOT NULL UNIQUE, status text ('pending'|'accepted'|'expired'),
created_at timestamptz, expires_at timestamptz DEFAULT (now() + 7 days)
```

**`badges`**
```
id uuid PK, user_id uuid FK→profiles, badge_type text NOT NULL,
earned_at timestamptz, UNIQUE(user_id, badge_type)
```
Badge types: `first_session`, `first_green`, `7_day_streak`, `30_day_streak`

### Storage Buckets
- `pet-photos` — `{guardian_id}/{pet_id}.jpg`
- `materials` — `{guardian_id}/{material_id}.jpg`
- `avatars` — `{user_id}.jpg`

### RLS (Row Level Security) Strategy
RLS is a PostgreSQL feature where the database enforces access rules at the row level — independent of the app. Because the iPhone app talks directly to Supabase using an API key, RLS ensures that even if someone bypassed the app, they could not read or write data they don't own. Every table has RLS enabled and policies define exactly who can SELECT/INSERT/UPDATE/DELETE each row.

1. **Own data**: `guardian_id = auth.uid()` or `owner_id = auth.uid()`
2. **Linked trainer read**: SELECT allowed when row exists in `trainer_guardian_links` with `trainer_id = auth.uid()` AND `status = 'active'`
3. **Trainer writes**: INSERT allowed into `materials`, `comments`, `plan_assignments` for linked guardians
4. **Profiles**: Any authenticated user can read any profile; only own row can be updated
5. **Invites**: Trainers manage their own; any authenticated user can lookup by `code`
6. **Badges**: INSERT only via Postgres trigger (tamper-proof); SELECT own only

Badge and streak logic runs in a Postgres FUNCTION triggered on `training_records` INSERT.

---

## Phased Execution Plan

### Phase 1 — Project Scaffold & Supabase Setup
- Create Supabase project, save URL + anon key
- Add `supabase-swift` v2.x to `HabitHound.xcodeproj`
- Create `Secrets.xcconfig` (gitignored), load keys via `Info.plist`
- Create `Core/Services/SupabaseClient.swift` with shared instance
- Apply full SQL schema to Supabase; enable RLS on all tables
- Create the three Storage buckets
- Restructure `HabitHound/` folder tree (placeholder files ok)

**Files**: `HabitHound.xcodeproj/project.pbxproj`, `Core/Services/SupabaseClient.swift`, `Makefile`

### Phase 2 — Authentication Flow
- `AuthService`: signUp (with role), signIn, signInWithApple, signOut, currentProfile
- `Core/Models/Profile.swift`
- `AuthViewModel` — `@Observable`, manages session state
- `LoginView`, `SignUpView`, `RoleSelectionView`
- `AppRouter` — listens to `supabase.auth.onAuthStateChange`, routes by role
- Update `HabitHoundApp.swift` to inject `AppRouter`
- Sign in with Apple entitlement + delegate
- Stub `GuardianTabView` and `TrainerTabView`

**Files**: `HabitHoundApp.swift`, `AppRouter.swift`, `Core/Auth/`, `Core/Models/Profile.swift`, `Core/Services/AuthService.swift`

### Phase 3 — Pet Profiles (Guardian)
- `Core/Models/Pet.swift`
- `PetService`: fetchPets, createPet, updatePet, deletePet
- `StorageService`: uploadPhoto, publicURL
- `PetViewModel`, `PetListView`, `PetFormView` (PhotosPicker), `PetDetailView` stub
- Wire Guardian Tab 2

**Files**: `Core/Models/Pet.swift`, `Core/Services/PetService.swift`, `Core/Services/StorageService.swift`, `Guardian/Pets/`

### Phase 4 — Training Record Logging (Guardian) ← Core Loop
- `TrainingRecord.swift` with `TrainingStatus`, `Distance`, `Distraction`, `Duration` enums
- `TrainingRecordService`: fetch/create/update/delete
- `TrainingRecordFormView`: pet picker, date, status buttons (4 colors), Three D's segmented pickers, notes, share toggle
- `TrainingRecordListView`, `TrainingRecordDetailView`
- `Shared/Components/StatusBadgeView.swift`
- Wire Tab 3 (Log) as sheet; wire PetDetailView to filtered list

**Files**: `Core/Models/TrainingRecord.swift`, `Core/Services/TrainingRecordService.swift`, `Guardian/TrainingRecords/`

### Phase 5 — Dashboard & Badges
- `DashboardViewModel`: streak computation, recent records, badge fetch
- Postgres FUNCTION + trigger for badge awards on `training_records` INSERT
- `Core/Models/Badge.swift`
- `DashboardView`: streak counter, badge scroll row, quick-log button, recent records
- `AchievementsView`: full badge gallery with locked/earned states
- `Shared/Components/EmptyStateView.swift`
- Wire Guardian Tab 1

**Files**: `Guardian/Dashboard/`, `Guardian/Achievements/`, `Core/Models/Badge.swift`, Supabase SQL function

### Phase 6 — Materials (Guardian)
- `Core/Models/Material.swift` with `MaterialKind` enum
- `MaterialService`: fetchMaterials, createMaterial, deleteMaterial
- `MaterialListView` (segmented by kind), `MaterialFormView` (kind picker)
- `Shared/Components/PhotoPickerView.swift` (reusable wrapper)
- Wire Guardian Tab 4

**Files**: `Core/Models/Material.swift`, `Core/Services/MaterialService.swift`, `Guardian/Materials/`, `Shared/Components/PhotoPickerView.swift`

### Phase 7 — Trainer Invite & Guardian Linking
- `Core/Models/TrainerGuardianLink.swift`
- `InviteService`: createInvite (generates 8-char code), fetchInviteByCode, acceptInvite (creates link)
- `InviteGuardianView` (Trainer) — email field, shows copyable code
- "Enter Invite Code" in Guardian Settings
- `GuardianListView` for Trainer Tab 1
- Harden RLS policies for cross-role data access using `trainer_guardian_links`

**Files**: `Core/Services/InviteService.swift`, `Trainer/Invites/`, `Trainer/Guardians/GuardianListView.swift`, RLS policy migrations

### Phase 8 — Trainer: View Guardian Records & Comment
- `Core/Models/Comment.swift`
- `CommentService`: fetchComments, addComment, deleteComment
- `GuardianDetailView` (Trainer): guardian info + pet list + read-only training records
- Extend `TrainingRecordDetailView` with role-conditional comment thread
- `GuardianViewModel` — fetches linked guardians, pets, records

**Files**: `Core/Models/Comment.swift`, `Core/Services/CommentService.swift`, `Trainer/Guardians/`

### Phase 9 — Training Plans
- `TrainingPlan.swift`, `TrainingPlanItem.swift`
- `TrainingPlanService`: plan CRUD, item CRUD, assignPlan, fetchAssignedPlans
- `TrainerPlanListView`, `TrainerPlanFormView` (drag-to-reorder items), `TrainerPlanDetailView`
- Assign sheet: guardian picker + optional pet picker
- `GuardianPlanListView`, `GuardianPlanDetailView` (read-only)
- Wire Trainer Tab 2 and Guardian Pet detail view

**Files**: `Core/Models/TrainingPlan.swift`, `Core/Services/TrainingPlanService.swift`, `Trainer/Plans/`, `Guardian/Plans/`

### Phase 10 — Notifications & Timers
- `NotificationManager`: requestPermission, scheduleReminder, cancelReminder, listPending
- `NotificationSettingsView` (Guardian Settings): daily reminder toggle + time picker
- `TimerView` (shared component): countdown timer with haptics
- `HapticManager`: wraps UIImpactFeedbackGenerator
- Wire timer button in `TrainingRecordFormView` or `DashboardView`

**Files**: `Shared/Utilities/NotificationManager.swift`, `Shared/Utilities/HapticManager.swift`, `Shared/Components/TimerView.swift`, `Guardian/Settings/NotificationSettingsView.swift`

### Phase 11 — Trainer: Add Materials to Guardian
- "Add Material" action in `GuardianDetailView`
- `TrainerAddMaterialView` — same form as `MaterialFormView`, sets `added_by_id = trainer`, `guardian_id = target guardian`
- Guardian's `MaterialListView` already surfaces trainer-added materials via `guardian_id` query

**Files**: `Trainer/Guardians/TrainerAddMaterialView.swift`, extend `Trainer/Guardians/GuardianDetailView.swift`

### Phase 12 — Polish, RLS Hardening & App Store Prep
- Audit all RLS policies; run cross-user access SQL test script
- Add DB indexes: `training_records(guardian_id)`, `(pet_id)`, `(recorded_at DESC)`, `materials(guardian_id)`, `badges(user_id)`
- Replace all force-unwraps with proper error propagation
- Global error alert in `AppRouter` via shared `ErrorStore`
- Loading skeletons / `ProgressView` on all list screens
- App icon (all required sizes in `Assets.xcassets`)
- `PrivacyInfo.xcprivacy` + `NSPhotoLibraryUsageDescription`, `NSUserNotificationsUsageDescription`
- TestFlight build + internal testing

---

## Dependency Graph

```
Phase 1 (Scaffold + Schema)
  └── Phase 2 (Auth)
        ├── Phase 3 (Pets)
        │     └── Phase 4 (Training Records)  ← Core Loop
        │           ├── Phase 5 (Dashboard + Badges)
        │           ├── Phase 8 (Trainer View + Comments) ← needs Phase 7
        │           └── Phase 9 (Training Plans) ← needs Phase 7
        ├── Phase 6 (Materials) ← parallel with Phase 3/4
        └── Phase 7 (Trainer Invite + Linking)
              ├── Phase 8, 9, 11
Phase 10 (Notifications) ← after Phase 4, mostly independent
Phase 12 (Polish) ← always last
```

---

## Critical Files

| File | Role |
|------|------|
| `HabitHound/HabitHoundApp.swift` | Entry point — inject AppRouter |
| `HabitHound/ContentView.swift` | Replace with AppRouter + tab views |
| `HabitHound.xcodeproj/project.pbxproj` | Package + file additions |
| `Makefile` | Extend with `BUNDLE_ID` update |
| `docs/prd.md` | Authoritative source for enums (Three D's, status values) |

---

## Verification

- **Phase 1**: App builds and links `Supabase` module; schema visible in Supabase dashboard
- **Phase 2**: Sign up as guardian → routes to Guardian tab shell; sign up as trainer → Trainer shell; returning user bypasses auth
- **Phase 4**: Log a training record → appears in Supabase `training_records` table; visible in list view
- **Phase 5**: Log 2nd session → badge `first_session` in `badges` table; streak increments
- **Phase 7**: Trainer generates invite code → Guardian enters code → `trainer_guardian_links` row created; trainer sees guardian in their list
- **Phase 9**: Trainer creates plan + assigns to guardian → guardian sees plan in their Plans tab
- **Phase 12**: Run Supabase SQL: confirm guardian A cannot read guardian B's records; confirm trainer can read linked guardian's records but not unlinked guardian's
