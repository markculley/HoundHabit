# HabitHound — Claude Instructions

## Project Documentation

### Key docs (all in `docs/`)
- **`docs/prd.md`** — Product requirements; authoritative source for feature scope, enum values (Three D's, status colours), and UX decisions
- **`docs/mvp_plan.md`** — Architecture, tech stack, database schema, folder structure, and the 12-phase execution plan
- **`docs/use_cases/`** — One markdown file per use case with Mermaid sequence diagrams, test flows, and conceptual explanations. Create or update a file here whenever a new use case is implemented or changed.

### Notion Kanban board
The project is tracked on a Notion board named **"Habit Hound"**. The 12 columns map to the 12 phases:

| # | Phase |
|---|-------|
| 1 | Project Scaffold & Supabase Setup |
| 2 | Authentication Flow |
| 3 | Pet Profiles (Guardian) |
| 4 | Training Record Logging (Guardian) |
| 5 | Dashboard & Badges |
| 6 | Resources (Guardian) |
| 7 | Trainer Invite & Guardian Linking |
| 8 | Trainer: View Guardian Records & Comment |
| 9 | Training Plans |
| 10 | Notifications & Timers |
| 11 | Trainer: Add Resources to Guardian |
| 12 | Polish, RLS Hardening & App Store Prep |

Update the Notion board (via MCP) when a phase is started or completed.

---

## Code Rules

### Previews
Every SwiftUI view file must include a `#Preview` block at the bottom. Use realistic but minimal data — prefer passing an empty or default ViewModel rather than mocking data. Example:

```swift
#Preview {
    PetFormView(mode: .add, viewModel: PetViewModel())
}
```

### General
- Pattern: MVVM + Service Layer (`@Observable` ViewModels, stateless `async throws` Services)
- No third-party dependencies beyond `supabase-swift` v2.x
- All snake_case ↔ camelCase mapping via `CodingKeys` on `Codable` structs
- UUID storage paths must use `.lowercased()` to match Supabase RLS (`auth.uid()::text` is lowercase)
- Never nest `NavigationStack` inside another `NavigationStack`
- Always use value-based `NavigationLink(value:)` + `.navigationDestination(for:)` — the legacy `NavigationLink(destination:)` silently breaks on second tap after popping back
- Never mix `navigationDestination(isPresented:)` and `NavigationLink(value:)` in the same stack — taps will silently pop back instead of pushing. If a pushed view needs its own value-based navigation, present it as a `.sheet` with its own `NavigationStack` instead
