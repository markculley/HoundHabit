# Habit Hound

A pet training tracker that bridges the gap between trainer visits. Guardians log sessions and track progress; Trainers deliver plans, review records, and leave feedback.

## Roles

| Role | What they do |
|---|---|
| **Guardian** | Logs training sessions, manages pets, earns badges, views trainer plans |
| **Trainer** | Invites guardians, creates training plans, reviews shared records, adds resources |

## Stack

- **iOS** — SwiftUI, iOS 17+, `@Observable`
- **Backend** — Supabase (PostgreSQL + Auth + Storage)
- **Auth** — Email/password + Sign in with Apple
- **Notifications** — Local only

## Build & Run

```bash
make build            # build for simulator
make run              # build, install, and launch on simulator
make emulator         # boot the simulator without building
make test             # run unit tests
```

> Requires `Secrets.xcconfig` at the project root (gitignored). Copy from a teammate or the project 1Password vault.

## Database Utilities

Requires a `.db_url` file at the project root (gitignored) containing your Supabase connection string. Get it from Dashboard → Project Settings → Database → Connection pooling → URI.

```bash
make sql-last-auth              # show active auth sessions
make sql-last-sessions          # show last 10 training sessions
make sql-last-sessions N=25     # show last N training sessions
make sql-storage                # list all files across storage buckets
```

SQL scripts live in [`scripts/sql/`](scripts/sql/).

## Storage

User-generated files (pet photos, resource photos) are stored in Supabase Storage buckets. Paths encode the owner's user ID so RLS can enforce access at the storage layer — not just the database layer.

| Bucket | Path | Contents |
|--------|------|----------|
| `pet-photos` | `{guardian_id}/{pet_id}/photo.jpg` | Pet profile photos |
| `resources` | `{guardian_id}/{resource_id}.jpg` | Guardian resource photos |
| `avatars` | `{user_id}.jpg` | User profile pictures |

## Badges

Badges are awarded automatically by a Postgres trigger when a guardian logs a session. Each badge can only be earned once.

| Badge | Condition |
|---|---|
| 🐾 **First Step** | Logged your first training session |
| ✅ **Green Light** | Earned your first green (Success) status |
| 🔥 **Week Warrior** | Trained 7 days in a row |
| 🏆 **Monthly Master** | Trained 30 days in a row |

## Implementation Plan

See [`docs/mvp_plan.md`](docs/mvp_plan.md) for the full 12-phase execution plan and database schema.

## SwiftUI Navigation

**Always use value-based navigation inside a `NavigationStack`.** The legacy destination-based form silently breaks after the first pop — tapping the same row a second time does nothing.

```swift
// ✅ Correct — value-based
NavigationLink(value: pet.id) {
    PetRow(pet: pet)
}
// Declare the destination once on the List (or any ancestor in the stack)
.navigationDestination(for: UUID.self) { petId in
    PetDetailView(petId: petId, viewModel: viewModel)
}

// ❌ Wrong — destination-based (breaks on second tap)
NavigationLink(destination: PetDetailView(petId: pet.id, viewModel: viewModel)) {
    PetRow(pet: pet)
}
```

**Never nest a `NavigationStack` inside another `NavigationStack`.** The inner stack swallows navigation events, causing destinations to appear empty or not load at all. Each tab or root view owns exactly one `NavigationStack`; all pushed views inherit it.

