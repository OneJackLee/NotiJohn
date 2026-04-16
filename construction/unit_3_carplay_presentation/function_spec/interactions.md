# Unit 3: CarPlay Presentation — Interactions

## Overview

Unit 3 is primarily a **passive** unit from the driver's perspective. The driver does not directly interact with banners or the connection lifecycle — these are system-driven and event-driven. This document describes the automated behaviors.

---

## Interaction Inventory

| ID | Interaction | Trigger | Type | Response |
|----|-------------|---------|------|----------|
| I3.1 | CarPlay connects | System (USB/wireless) | Automatic | Start session, set root template |
| I3.2 | CarPlay disconnects | System (USB/wireless) | Automatic | End session, stop banners |
| I3.3 | New notification arrives | `NotificationCaptured` event | Automatic | Show banner (if criteria met) |
| I3.4 | Banner auto-dismisses | Timer expiry | Automatic | Remove delivered notification |
| I3.5 | Duplicate notification arrives | `NotificationCaptured` event | Automatic | Suppress banner, emit event |

---

## Interaction Details

### I3.1 — CarPlay Connects

**Trigger:** iOS system notifies the app that CarPlay has connected (USB or wireless).

**Flow:**
1. `CPTemplateApplicationSceneDelegate.didConnect(interfaceController:to:)` is called.
2. `CarPlaySceneLifecycleAdapter.didConnect()` → `CarPlaySessionAppService.onCarPlayConnect()`.
3. `CarPlaySession.start()` → emits `CarPlaySessionStarted`.
4. Root template (Unit 4's `CPListTemplate`) is set on `interfaceController`.
5. `IncomingNotificationHandler` begins processing `NotificationCaptured` events.

**User experience:** The NotiJohn app appears on the CarPlay screen with the notification list. No driver action required.

---

### I3.2 — CarPlay Disconnects

**Trigger:** iOS system notifies the app that CarPlay has disconnected.

**Flow:**
1. `CPTemplateApplicationSceneDelegate.didDisconnect(interfaceController:)` is called.
2. `CarPlaySceneLifecycleAdapter.didDisconnect()` → `CarPlaySessionAppService.onCarPlayDisconnect()`.
3. `CarPlaySession.end()` → emits `CarPlaySessionEnded`.
4. `IncomingNotificationHandler` stops processing (connection check returns `false`).
5. Unit 2 continues capturing notifications in the background.

**User experience:** CarPlay screen goes away. Notifications accumulate silently and will appear in the list when CarPlay reconnects.

---

### I3.3 — New Notification Arrives (Banner Display)

**Trigger:** `NotificationCaptured` event published by Unit 2 on the `DomainEventBus`.

**Preconditions:**
- `CarPlaySession.isConnected == true`
- Notification fingerprint has NOT been displayed in the last `DuplicateWindow` (30 seconds)

**Flow:**
1. `IncomingNotificationHandler.handle(event:)` is invoked via Combine subscription.
2. Connection check: `session.isConnected` → must be `true`.
3. Duplicate check: `duplicatePolicy.isDuplicate(fingerprint:, at:)` → must be `false`.
4. Create `NotificationBanner.from(event:)`.
5. Call `bannerService.show(banner:)` → posts `UNNotificationRequest` for immediate delivery.
6. Record fingerprint: `duplicatePolicy.recordDisplay(fingerprint:, at:)`.
7. Publish `BannerDisplayed` event.
8. Schedule auto-dismiss via `bannerAppService.scheduleBannerDismissal()`.

**User experience:** A system notification card appears at the top of the CarPlay screen showing the app name, title, and body preview. It auto-dismisses after 5 seconds.

---

### I3.4 — Banner Auto-Dismisses

**Trigger:** `BannerDuration` timer expires (default: 5 seconds after display).

**Flow:**
1. `BannerAppService.scheduleBannerDismissal()` fires after the configured delay.
2. `bannerService.dismiss(notificationId:)` → calls `UNUserNotificationCenter.removeDeliveredNotifications(withIdentifiers:)`.
3. Publish `BannerAutoDismissed` event.

**User experience:** The banner slides away automatically. No driver action needed.

---

### I3.5 — Duplicate Notification Suppressed

**Trigger:** `NotificationCaptured` event with a fingerprint matching a recently displayed banner.

**Flow:**
1. `IncomingNotificationHandler.handle(event:)` invoked.
2. Connection check passes.
3. Duplicate check: `duplicatePolicy.isDuplicate()` → `true`.
4. Publish `DuplicateNotificationSuppressed` event.
5. No banner is shown.

**User experience:** Nothing visible. The notification is still stored in the list (Unit 4) and visible when the driver opens the list — it is only the banner that is suppressed.

---

## Timing Constraints

| Parameter | Default | Notes |
|-----------|---------|-------|
| Banner display duration | 5 seconds | Configurable via `BannerDuration` |
| Duplicate suppression window | 30 seconds | Configurable via `DuplicateWindow` |
| Duplicate log purge interval | 60 seconds | Timer-based cleanup of expired entries |
