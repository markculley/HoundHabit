# Use Case: Settings & Account (Phase 4.5)

## UC-S.1 View Account Information

Guardian navigates to **Settings → Account** to view their profile and auth details.

```mermaid
sequenceDiagram
    actor G as Guardian
    participant UI as AccountView
    participant SVC as AuthService
    participant DB as Supabase (profiles / auth.users)

    G->>UI: Settings tab → tap Account
    UI->>SVC: currentProfile() [.task]
    SVC->>DB: SELECT * FROM profiles WHERE id = auth.uid()
    DB-->>SVC: Profile (role, full_name)
    SVC-->>UI: Profile
    UI->>UI: supabase.auth.currentUser → email, createdAt, lastSignInAt
    UI->>G: Show Role, Name, Email, Created, Last Login
```

---

## UC-S.2 Sign Out

Guardian taps **Sign Out** in Settings. `AppRouter` listens to `onAuthStateChange` and automatically routes to the login screen — no explicit navigation needed.

```mermaid
sequenceDiagram
    actor G as Guardian
    participant UI as SettingsView
    participant SVC as AuthService
    participant AR as AppRouter
    participant AUTH as Supabase Auth

    G->>UI: Tap "Sign Out"
    UI->>SVC: signOut()
    SVC->>AUTH: supabase.auth.signOut()
    AUTH-->>AR: onAuthStateChange(.signedOut)
    AR->>AR: route = .unauthenticated
    AR->>G: Login screen presented
```

---

## Test Flow

### T-S.1 View account info
1. Go to the **Settings** tab.
2. Confirm the list shows an **Account** row and a **Sign Out** button.
3. Tap **Account**.
4. Confirm Role, Name, and Email match the signed-in user.
5. Confirm Created and Last Login dates are present and plausible.

### T-S.2 Sign out
1. From the **Settings** tab, tap **Sign Out**.
2. Confirm the app returns to the login screen immediately (no confirmation dialog — the action is reversible).
3. Sign back in and confirm the app returns to the Guardian Home tab.
