# App Store Submission Checklist

Tracks everything needed to ship Hound Habit to TestFlight (beta) and the App Store (public).

---

## Phase 1 — Accounts & IDs

- [ ] Apple Developer Program enrollment active ($99/yr) — developer.apple.com
- [ ] App Store Connect access confirmed — appstoreconnect.apple.com
- [ ] Bundle identifier registered in Certificates, Identifiers & Profiles — must match Xcode project's bundle ID
- [ ] App Store Connect app record created (*My Apps → +*)
  - Name: **Hound Habit**
  - Primary language
  - Bundle ID (select the one registered above)
  - SKU (internal identifier, e.g. `hound-habit-ios`)

## Phase 2 — Versioning

- [ ] `MARKETING_VERSION` = `1.0` (Xcode target → General → Identity)
- [ ] `CURRENT_PROJECT_VERSION` (build number) bumped for every TestFlight/App Store upload

> "Beta" is delivered via TestFlight, not via the version string. Keep the version numeric.

## Phase 3 — Assets

### Icons
- [ ] 1024×1024 marketing icon in asset catalog (no alpha, no rounded corners)
- [ ] All iPhone icon sizes filled in `Assets.xcassets/AppIcon.appiconset`

### Screenshots (3-10 per size, PNG or JPEG)
- [ ] **6.9" iPhone** (iPhone 16 Pro Max, 1320×2868) — required
- [ ] **6.5" iPhone** (iPhone 11 Pro Max, 1242×2688) — required
- [ ] Optional: 5.5" iPhone, iPad if ever targeted

Suggested screens to capture:
- Dashboard with a streak + badges
- Training record log entry
- Pet profile
- Trainer plan view
- Resources gallery

## Phase 4 — Metadata (App Store Connect)

- [ ] App description (up to 4000 chars)
- [ ] Promotional text (170 chars, updatable without review)
- [ ] Subtitle (30 chars)
- [ ] Keywords (100 chars, comma-separated)
- [ ] Primary category: *Health & Fitness* or *Lifestyle*
- [ ] Secondary category (optional)
- [ ] Support URL — public page for user support
- [ ] Marketing URL (optional)
- [ ] **Privacy Policy URL**: `https://www.cometncloud.com/houndhabitprivacypolicy`
- [ ] Copyright string (e.g. "© 2026 Comet 'n' Cloud")

## Phase 5 — Ratings & Compliance

- [ ] Age rating questionnaire completed (likely 4+)
- [ ] **Privacy "nutrition label" questionnaire** — separate from `PrivacyInfo.xcprivacy`. Answers should align with what the xcprivacy file declares:
  - Email address (linked, not for tracking)
  - Name (linked, not for tracking)
  - Photos (linked, not for tracking)
  - Other user content — training records/notes (linked, not for tracking)
- [ ] Export compliance — confirm the app uses only standard HTTPS/TLS encryption → "No" to custom cryptography
- [ ] Content rights — confirm you own or have rights to all content

## Phase 6 — Build & Upload

- [ ] Select *Any iOS Device (arm64)* as destination in Xcode
- [ ] *Product → Archive*
- [ ] *Organizer → Distribute App → App Store Connect → Upload*
- [ ] Wait for processing (~15-30 min, email notification when done)

## Phase 7 — TestFlight (Beta)

- [ ] Internal testing group created in App Store Connect (up to 100 testers, no review needed)
- [ ] Internal testers added by Apple ID / email
- [ ] Build assigned to internal group → testers receive TestFlight invite
- [ ] External testing group (optional, up to 10,000 testers) — requires one-time **Beta App Review** (~24h)
- [ ] Collect feedback, fix issues, upload new builds (bump `CURRENT_PROJECT_VERSION` each time)

## Phase 8 — App Review

- [ ] Sign-in demo account credentials provided to Apple in the review notes (Guardian + Trainer roles)
- [ ] Review notes explain any non-obvious flows (e.g. trainer invite codes)
- [ ] Review notes mention the account deletion path: **Settings → Account → Delete Account** (Apple Guideline 5.1.1(v))
- [ ] Submit for Review
- [ ] Monitor status in App Store Connect; respond quickly to any rejections

## Phase 9 — Release

- [ ] Choose release method:
  - Automatic on approval, or
  - Manual (click Release when ready), or
  - Scheduled date
- [ ] Post-release: monitor Crashes tab, TestFlight/App Store reviews

---

## Open items / blockers

- [ ] Confirm `https://www.cometncloud.com/houndhabitprivacypolicy` page is actually live with the contents from `docs/privacy_policy.md`
- [ ] Decide support URL destination
- [ ] Produce screenshots (needs polished demo data on simulator)
- [ ] Produce marketing icon if not already in asset catalog
