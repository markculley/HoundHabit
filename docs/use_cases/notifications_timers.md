# Phase 10: Notifications & Timers

## Overview

Three distinct capabilities: a daily training reminder (local push notification), a countdown timer embedded in the session log form, and haptic feedback on key interactions.

---

## UC-10.1: Guardian Enables Daily Training Reminder

**Actor:** Guardian  
**Precondition:** Guardian is authenticated.

### Flow

```
Guardian                  App                        iOS
  │                         │                            │
  │  Settings → Notifications│                           │
  │────────────────────────▶│                            │
  │                         │  authorizationStatus()     │
  │                         │───────────────────────────▶│
  │                         │◀───────────────────────────│
  │  NotificationSettingsView│                           │
  │  shown with current state│                           │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Toggle "Remind me"     │                            │
  │  ON (first time)        │                            │
  │────────────────────────▶│                            │
  │                         │  requestPermission()       │
  │                         │───────────────────────────▶│
  │  System permission alert│                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Tap "Allow"            │                            │
  │────────────────────────▶│                            │
  │                         │  scheduleReminder(9, 0)    │
  │                         │───────────────────────────▶│
  │                         │  UNCalendarNotificationTrigger│
  │                         │  repeating daily at 9:00 AM│
  │                         │  UserDefaults: enabled=true│
  │                         │◀───────────────────────────│
  │  Toggle shown ON        │                            │
  │◀────────────────────────│                            │
```

### Permission Denied Flow

```
Guardian                  App                        iOS Settings
  │                         │                            │
  │  Toggle ON (denied)     │                            │
  │────────────────────────▶│                            │
  │                         │  requestPermission() → false│
  │                         │  isEnabled reverted to OFF │
  │                         │  authorizationStatus = .denied│
  │  Inline denial message  │                            │
  │  + "Open Settings" btn  │                            │
  │◀────────────────────────│                            │
  │                         │                            │
  │  Tap "Open Settings"    │                            │
  │────────────────────────▶│───────────────────────────▶│
  │                         │  UIApplication.open(       │
  │                         │    openSettingsURLString)  │
```

### Time Change Flow

```
Guardian                  App                        iOS
  │                         │                            │
  │  Change time to 7:30 AM │                            │
  │────────────────────────▶│                            │
  │                         │  removePending(identifier) │
  │                         │  scheduleReminder(7, 30)   │
  │                         │───────────────────────────▶│
  │                         │  UserDefaults updated      │
  │                         │◀───────────────────────────│
```

### Reschedule on Launch

```swift
// AppRouter.resolveRoute() — after auth resolves for guardian
if profile.role == .guardian {
    Task { await NotificationManager().rescheduleIfNeeded() }
}
```

`rescheduleIfNeeded()` reads `UserDefaults`. If enabled and system permission is still granted, it re-adds the notification. Safe to call every launch — `removePendingNotificationRequests` runs first to prevent duplicates.

### Persistence

All state stored in `UserDefaults` with namespaced keys:

| Key | Default | Purpose |
|-----|---------|---------|
| `HoundHabit.reminder.enabled` | `false` | Whether reminder is active |
| `HoundHabit.reminder.hour` | `9` | Hour component |
| `HoundHabit.reminder.minute` | `0` | Minute component |

---

## UC-10.2: Guardian Uses Training Timer

**Actor:** Guardian  
**Precondition:** Guardian is filling out the session log form.

### Flow

```
Guardian                  App
  │                         │
  │  Tap "Log" or "+"       │
  │────────────────────────▶│
  │  TrainingRecordFormView  │
  │  "Training Timer" row   │
  │  (collapsed by default) │
  │◀────────────────────────│
  │                         │
  │  Tap to expand timer    │
  │────────────────────────▶│
  │  TimerView shown        │
  │  Duration picker + ring │
  │◀────────────────────────│
  │                         │
  │  Select "30 sec"        │
  │  Tap ▶ (play)           │
  │────────────────────────▶│
  │                         │  Timer.scheduledTimer
  │                         │  fires every 0.1s
  │                         │  remaining decrements
  │  Ring animates,         │
  │  time counts down       │
  │◀────────────────────────│
  │                         │
  │  [30 seconds later]     │
  │                         │  remaining = 0
  │                         │  state = .complete
  │                         │  HapticManager.timerComplete()
  │  Ring fills green       │
  │  "Done!" shown          │
  │  Haptic pulse           │
  │◀────────────────────────│
  │                         │
  │  Fill in Three D's,     │
  │  tap Log                │
  │────────────────────────▶│
  │                         │  HapticManager.light()
  │                         │  timerViewModel.reset()
  │                         │  (on form disappear)
```

### Timer State Machine

```
idle ──[start]──▶ running ──[pause]──▶ paused
  ▲                  │                    │
  │                  │[tick → 0]          │[start]
  │                  ▼                    │
  └──[reset]── complete               running
```

### Duration Presets

| Label | Seconds | Use case |
|-------|---------|----------|
| 5 sec | 5 | Quick reps / development testing |
| 30 sec | 30 | Short stay exercises |
| 1 min | 60 | Standard duration work |
| 2 min | 120 | Extended stays |
| 5 min | 300 | Long duration challenges |

### Implementation Notes

**Timer uses `Timer.scheduledTimer`** (not `async`/`Task.sleep`) — integrates with the main run loop, coalesces with SwiftUI render cycle, no manual cancellation needed.

**`TimerViewModel` is `@MainActor`** — all haptic calls and UIKit interactions require the main thread.

**Embedded as `DisclosureGroup`** in `TrainingRecordFormView` between Three D's and Notes sections — collapsed by default, no form clutter.

**`timerViewModel.reset()` called `onDisappear`** — cleans up any running timer when the form is dismissed.

---

## UC-10.3: Haptic Feedback

Haptics fire silently in the background — no UI changes, just tactile feedback.

| Trigger | Method | Style |
|---------|--------|-------|
| Session saved | `HapticManager.light()` | Light impact |
| Timer start | `HapticManager.medium()` | Medium impact |
| Timer pause | `HapticManager.medium()` | Medium impact |
| Timer reset | `HapticManager.light()` | Light impact |
| Timer completes | `HapticManager.timerComplete()` | Heavy + notification success (0.15s apart) |

---

## Architecture

### `NotificationManager`

Stateless `struct` consistent with the service layer pattern. Accepts injectable `UserDefaults` for testability:

```swift
struct NotificationManager {
    init(defaults: UserDefaults = .standard)

    func requestPermission() async -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func scheduleReminder(hour: Int, minute: Int) async throws
    func cancelReminder()
    func rescheduleIfNeeded() async

    var isReminderEnabled: Bool   // reads UserDefaults
    var reminderHour: Int         // default 9
    var reminderMinute: Int       // default 0
}
```

### `HapticManager`

Stateless `struct` with `@MainActor` static methods — callable from anywhere:

```swift
struct HapticManager {
    @MainActor static func light()
    @MainActor static func medium()
    @MainActor static func heavy()
    @MainActor static func success()
    @MainActor static func timerComplete()  // heavy + 0.15s delay + success
}
```

### `TimerViewModel`

`@Observable @MainActor final class` — owned by `TrainingRecordFormView` via `@State`:

```swift
@Observable @MainActor
final class TimerViewModel {
    var selectedDuration: TimerDuration
    var state: TimerState        // .idle | .running | .paused | .complete
    var remaining: TimeInterval

    var progress: Double         // 0.0 → 1.0
    var displayTime: String      // "1:30" or ":30"
    var totalSeconds: TimeInterval

    func start()
    func pause()
    func reset()
    func selectDuration(_ duration: TimerDuration)
    func tick()                  // internal — called by Timer, exposed for tests
}
```

**Pure logic helpers** — extracted as static functions for testability without `@MainActor` constraints:

```swift
static func formatTime(_ remaining: TimeInterval) -> String
static func calculateProgress(remaining: TimeInterval, total: TimeInterval) -> Double
```

These are tested directly in `TimerViewModelTests` without instantiating the class.

---

## Edge Cases

| Scenario | Behaviour |
|----------|-----------|
| Permission denied | Toggle reverts to OFF, inline message shown with "Open Settings" link |
| Permission previously denied, user re-enables in iOS Settings | `authorizationStatus()` on appear returns `.authorized`; toggle works normally |
| App killed while timer running | Timer stops (no background execution); state lost. Acceptable for MVP. |
| Form dismissed mid-countdown | `onDisappear` calls `timerViewModel.reset()`, timer invalidated |
| Guardian changes reminder time while app is running | Old notification removed, new one scheduled atomically |
| iOS clears pending notifications (e.g. after restore) | `rescheduleIfNeeded()` on launch re-adds it |
| `scheduleReminder` fails (e.g. clock skew) | `try?` in `rescheduleIfNeeded`; silent failure on launch, error surfaced on manual toggle |

---

## Tests

### `NotificationManagerTests` — UserDefaults read/write (no system dependencies)

| Test | Verifies |
|------|----------|
| `defaultHourIsNine` | Fresh `UserDefaults` suite → `reminderHour == 9` |
| `defaultMinuteIsZero` | Fresh suite → `reminderMinute == 0` |
| `defaultEnabledIsFalse` | Fresh suite → `isReminderEnabled == false` |
| `cancelReminderSetsEnabledFalse` | Write `enabled=true`, call `cancelReminder()` → `false` |
| `persistsCustomTime` | Write hour=14, minute=30 → reads back correctly |

Each test uses a unique `UserDefaults(suiteName: UUID().uuidString)` to avoid polluting `.standard`.

### `TimerViewModelTests` — pure static logic (no `@MainActor` constraints)

Tests target the extracted static helpers `TimerViewModel.formatTime(_:)` and `TimerViewModel.calculateProgress(remaining:total:)` rather than instantiating the `@MainActor` class:

| Test | Input | Expected |
|------|-------|----------|
| `formatTime_subMinute_30` | 30.0 | `":30"` |
| `formatTime_subMinute_5` | 5.0 | `":05"` |
| `formatTime_overMinute_90` | 90.0 | `"1:30"` |
| `formatTime_overMinute_65` | 65.0 | `"1:05"` |
| `progress_atStart` | remaining=30, total=30 | `0.0` |
| `progress_atComplete` | remaining=0, total=30 | `1.0` |
| `progress_halfway` | remaining=15, total=30 | `0.5` |
| `progress_clamped` | remaining=-1, total=30 | `1.0` |

---

## Test Flows

1. **Enable reminder**: Settings → Notifications → toggle ON → system permission alert → Allow → toggle stays ON, time picker appears.
2. **Change reminder time**: With toggle ON, change time to 7:30 AM → app reschedules (verify in Xcode debugger or by checking `UNUserNotificationCenter.current().pendingNotificationRequests()`).
3. **Disable reminder**: Toggle OFF → pending notification removed, time picker hidden.
4. **Permission denied**: Toggle ON → Deny → toggle reverts to OFF, denial message shown, "Open Settings" button visible.
5. **Use timer**: Log session → expand "Training Timer" → select 5 sec → tap play → ring counts down → haptic fires at completion → "Done!" shown.
6. **Pause and resume**: Start timer → pause → time stops → start again → continues from where it left off.
7. **Reset mid-count**: Start timer → reset → returns to selected duration, state idle.
8. **Form dismissed mid-count**: Start timer → tap Cancel → timer stops (no memory leak).
9. **Save with haptic**: Fill form → tap Log → light haptic fires on save.
