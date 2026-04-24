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

## UC-S.3 Delete Account

Required by Apple App Store Guideline 5.1.1(v): any app that supports account creation must let users initiate permanent account deletion from within the app.

User taps **Settings → Account → Delete Account**. The client cannot delete from `auth.users` directly (that requires the `service_role` key, which must never ship in the app), so deletion is performed by a Postgres function with `SECURITY DEFINER` that runs with elevated privileges.

```mermaid
sequenceDiagram
    actor U as User (Guardian or Trainer)
    participant UI as AccountView
    participant SVC as AuthService
    participant RPC as Supabase RPC
    participant FN as public.delete_my_account()
    participant DB as Postgres (public schema)
    participant AUTH as auth.users
    participant AR as AppRouter

    U->>UI: Tap "Delete Account"
    UI->>U: Alert "Delete your account?" (destructive confirm)
    U->>UI: Confirm
    UI->>SVC: deleteAccount()
    SVC->>RPC: POST /rest/v1/rpc/delete_my_account
    RPC->>FN: invoke (JWT → auth.uid())
    FN->>DB: DELETE from comments, plan_assignments,<br/>training_plan_items, training_plans,<br/>training_records, resources, pets,<br/>trainer_guardian_links, invites, badges, profiles
    FN->>AUTH: DELETE FROM auth.users WHERE id = auth.uid()
    AUTH-->>AR: onAuthStateChange(.signedOut)
    SVC->>AUTH: supabase.auth.signOut() (belt-and-braces)
    AR->>AR: route = .unauthenticated
    AR->>U: Login screen presented
```

### Storage cleanup
Storage objects (pet photos, resource images, avatars) are intentionally **not** deleted by the function — Postgres cannot call the Storage API directly. Objects live in private buckets keyed by user UUID and are unreachable once the owning `auth.user` is gone. A periodic cleanup job can sweep orphans later. Apple's deletion requirement applies to the account and its data visible through the app, which is satisfied.

### Security posture
- Function declared `SECURITY DEFINER` with `SET search_path = public, auth` to prevent search-path hijacking.
- `REVOKE ALL FROM public` + `GRANT EXECUTE TO authenticated` — only signed-in users can invoke it, and only for their own `auth.uid()`.
- No parameters — the target user is always `auth.uid()`, so a caller cannot delete another user's account.

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

### T-S.3 Delete account
1. Create a throwaway account (e.g. `temp@jones.com`) and seed it with a pet + one training record so deletion has something to cascade through.
2. Settings → Account → scroll to the **Delete Account** section.
3. Confirm the destructive button and its explanatory footer are visible.
4. Tap **Delete Account** → the confirmation alert appears.
5. Tap **Cancel** → confirm nothing changes.
6. Tap **Delete Account** again → confirm in the alert.
7. Confirm the button shows a "Deleting…" spinner while the RPC runs.
8. Confirm the app returns to the login screen automatically.
9. In Supabase Dashboard → Authentication → Users, confirm the row is gone.
10. Run `SELECT count(*) FROM pets WHERE guardian_id = '<deleted user id>'` → should return 0. Repeat for `training_records`, `profiles`, etc.
11. Try to sign in again with the deleted credentials → should fail with "Invalid login credentials."
