# Unit 1: iPhone Companion App — Interactions

## Interaction Inventory

| ID | Interaction | Screen | Trigger | Response |
|----|-------------|--------|---------|----------|
| I1.1 | Advance onboarding step | S1.1–S1.4 | Tap "Continue" / "Get Started" | Complete current step, navigate to next |
| I1.2 | Skip onboarding step | S1.3 | Tap "Skip" | Skip appSelection step, advance to completion |
| I1.3 | Request notification permission | S1.2 | Tap "Allow Notifications" | Trigger iOS system permission dialog |
| I1.4 | Open iOS Settings | S1.2, S1.5 | Tap "Open Settings" | Deep-link to app's iOS settings page |
| I1.5 | Toggle app monitoring | S1.3, S1.5 | Toggle switch on app row | Enable/disable monitoring for that app |
| I1.6 | App appears on first launch | — | App launch | Check onboarding status, route accordingly |

---

## Interaction Details

### I1.1 — Advance Onboarding Step

**Trigger:** User taps "Continue" (S1.1, S1.2, S1.3) or "Get Started" (S1.4).

**Flow:**
1. ViewModel calls `onboardingService.completeStep(currentStep)`.
2. Domain validates step order and marks as completed.
3. `currentStep` advances to the next step.
4. View transitions to the next screen (SwiftUI navigation or tab change within the onboarding container).
5. On S1.4 "Get Started": calls `onboardingService.finishOnboarding()`, sets `isComplete = true`, transitions to S1.5.

**Error handling:**
- If step is already completed (e.g., double-tap): no-op (idempotent).
- If step order is violated: should not happen given linear UI flow; log error silently.

**Animation:** Slide transition (left-to-right) between steps.

---

### I1.2 — Skip Onboarding Step

**Trigger:** User taps "Skip" on S1.3 (App Selection).

**Flow:**
1. ViewModel calls `onboardingService.skipStep(.appSelection)`.
2. Domain marks step as skipped, advances `currentStep` to `.completion`.
3. View transitions to S1.4.

**Constraint:** Only `appSelection` is skippable per domain model.

---

### I1.3 — Request Notification Permission

**Trigger:** User taps "Allow Notifications" on S1.2.

**Flow:**
1. ViewModel calls `onboardingService.requestNotificationPermission()`.
2. iOS system permission dialog appears over the app.
3. User grants or denies.
4. ViewModel receives `PermissionStatus` result.
5. View updates:
   - `granted`: Show success indicator (checkmark), enable "Continue" button.
   - `denied`: Show permission denied recovery block (S1.6 inline).

**Edge case:** If permission was already determined (granted or denied), the system dialog does not appear. The view reflects the current status immediately.

**Returning from Settings:** When the user returns from iOS Settings after changing permission:
1. `onAppear` (or `scenePhase` change) triggers `permissionService.checkCurrentStatus()`.
2. View updates to reflect the new status.

---

### I1.4 — Open iOS Settings

**Trigger:** User taps "Open Settings" button (shown when permission is denied).

**Flow:**
1. Call `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`.
2. iOS switches to the Settings app, directly to NotiJohn's settings page.
3. User enables notification access.
4. User returns to NotiJohn.
5. `onAppear` re-checks permission status → view updates.

---

### I1.5 — Toggle App Monitoring

**Trigger:** User flips a toggle switch on an app row (S1.3 or S1.5).

**Flow (enable):**
1. Toggle animates to ON.
2. ViewModel calls `appMonitoringService.enableApp(appInfo)`.
3. Domain adds/enables the app in `MonitoredAppSettings`.
4. Repository saves.
5. `AppMonitoringEnabled` event published → Unit 2 starts capturing from this app.

**Flow (disable):**
1. Toggle animates to OFF.
2. ViewModel calls `appMonitoringService.disableApp(bundleId)`.
3. Domain disables the app.
4. Repository saves.
5. `AppMonitoringDisabled` event published → Unit 2 stops capturing from this app.

**Immediate effect:** Per `ImmediateEffectPolicy`, the change is applied instantly. No "Save" button needed.

**Optimistic UI:** Toggle updates immediately. If save fails (rare), toggle reverts and an error is displayed.

---

### I1.6 — App Launch Routing

**Trigger:** App launches or returns to foreground.

**Flow:**
1. `@main` app entry checks `onboardingService.isOnboardingComplete()`.
2. If `false` → present onboarding flow (S1.1).
3. If `true` → present settings screen (S1.5).
4. On every launch, `permissionService.checkCurrentStatus()` is called.
5. If permission is now denied (was previously granted), the settings screen shows a warning banner.

---

## State Transitions

### Onboarding Flow State Machine

```
[welcome] ──Complete──→ [permissionRequest] ──Complete──→ [appSelection] ──Complete──→ [completion] ──Finish──→ [DONE]
                                                             │
                                                             └──Skip──→ [completion] ──Finish──→ [DONE]
```

### Permission Status State Machine

```
[notDetermined] ──Request──→ [granted]    (happy path)
                ──Request──→ [denied]     (user declines)
[denied]        ──Settings──→ [granted]   (user enables in Settings)
[granted]       ──Settings──→ [denied]    (user revokes in Settings)
```
