# Habit Hound

A pet training tracker that bridges the gap between trainer visits. Guardians log sessions and track progress; Trainers deliver plans, review records, and leave feedback.

## Roles

| Role | What they do |
|---|---|
| **Guardian** | Logs training sessions, manages pets, earns badges, views trainer plans |
| **Trainer** | Invites guardians, creates training plans, reviews shared records, adds materials |

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

## Sequence Diagram

```mermaid
sequenceDiagram
    actor T as Trainer
    actor G as Guardian
    participant App as HabitHound App
    participant DB as Supabase

    %% Onboarding
    T->>App: Sign up (Trainer role)
    App->>DB: Create account + profile
    T->>App: Generate invite code
    App->>DB: Store invite (email + code)
    T-->>G: Share invite code (out of band)

    G->>App: Sign up (Guardian role)
    App->>DB: Create account + profile
    G->>App: Enter invite code
    App->>DB: Accept invite → create trainer_guardian_link

    %% Pet setup
    G->>App: Create pet record
    App->>DB: Insert pet (name, breed, photo)

    %% Training loop
    loop Each training session
        G->>App: Log training record
        Note over App: Pet, status (🔴🟠🟡🟢),<br/>Three D's, notes, share flag
        App->>DB: Insert training_record
        DB-->>App: Trigger awards badge if earned
        App-->>G: Show badge / streak update
    end

    %% Trainer reviews
    T->>App: View linked guardian
    App->>DB: Fetch guardian's shared records
    T->>App: Comment on training record
    App->>DB: Insert comment

    %% Training plan
    T->>App: Create training plan + items
    App->>DB: Insert training_plan + training_plan_items
    T->>App: Assign plan to guardian (+ optional pet)
    App->>DB: Insert plan_assignment
    G->>App: View assigned plan (read-only)

    %% Materials
    T->>App: Add material to guardian (URL / photo / note)
    App->>DB: Insert material (added_by_id = trainer)
    G->>App: View materials tab
    App->>DB: Fetch materials where guardian_id = me
```
