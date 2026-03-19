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
make build   # build for simulator
make run     # build, install, and launch on simulator
```

> Requires `Secrets.xcconfig` at the project root (gitignored). Copy from a teammate or the project 1Password vault.

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

