# Unit 3: CarPlay Presentation — Screens

## Overview

Unit 3 does not own persistent CarPlay screens. It manages:
1. The CarPlay connection lifecycle (scene delegate).
2. Transient notification banners displayed via system notifications.

The persistent CarPlay screen (notification list) is owned by Unit 4.

---

## Screen Inventory

| Screen ID | Name | Type | Entry Point |
|-----------|------|------|-------------|
| S3.1 | CarPlay Connected State | Scene state | iPhone connects to CarPlay |
| S3.2 | CarPlay Disconnected State | Scene state | iPhone disconnects from CarPlay |
| S3.3 | Notification Banner | Transient overlay | New notification captured while connected |

---

## Screen Descriptions

### S3.1 — CarPlay Connected State

**Purpose:** CarPlay is connected and the app is active on the car's display.

**Behavior:**
- `CarPlaySceneDelegate.didConnect()` is called by the system.
- `CarPlaySession.start()` is invoked.
- The root template (Unit 4's notification list) is set on the `CPInterfaceController`.
- `IncomingNotificationHandler` starts responding to `NotificationCaptured` events.

**Visual:** No Unit 3–specific UI. The root template is Unit 4's `CPListTemplate`.

---

### S3.2 — CarPlay Disconnected State

**Purpose:** CarPlay has been disconnected.

**Behavior:**
- `CarPlaySceneDelegate.didDisconnect()` is called by the system.
- `CarPlaySession.end()` is invoked.
- `IncomingNotificationHandler` stops showing banners (connection check returns false).
- No cleanup of pending banners needed (CarPlay UI is gone).
- Notifications continue to be captured and stored by Unit 2 in the background.

**Visual:** No UI — CarPlay display is off.

---

### S3.3 — Notification Banner

**Purpose:** Transient notification display on the CarPlay screen when a new notification arrives.

**Type:** System notification (delivered via `UNUserNotificationCenter`).

**Layout (system-controlled):**
```
┌──────────────────────────────────────────────┐
│  NotiJohn                                     │
│  ┌────────────────────────────────────────┐   │
│  │ [App Name]                             │   │
│  │ Notification Title                     │   │
│  │ Body preview text truncated to fit...  │   │
│  └────────────────────────────────────────┘   │
│                                               │
│  (Auto-dismisses after ~5 seconds)            │
└──────────────────────────────────────────────┘
```

**Components (mapped to UNNotificationContent):**
- `title` → Source app name (e.g., "WhatsApp")
- `subtitle` → Notification title
- `body` → Body preview (truncated to ~100 characters)
- `categoryIdentifier` → `"NOTIJOHN_BANNER"` (for custom handling if needed)

**Lifecycle:**
1. `NotificationCaptured` event received from Unit 2.
2. `IncomingNotificationHandler` checks: connected? not duplicate?
3. Creates `UNNotificationRequest` with immediate trigger.
4. System displays the notification on CarPlay.
5. After `BannerDuration` (5 seconds), a scheduled removal cleans up the delivered notification.

**Duplicate suppression:**
- If the same fingerprint was displayed within the last 30 seconds (`DuplicateWindow`), the banner is not shown.
- The notification is still stored in the list (Unit 4) — only the banner is suppressed.

---

## State Diagram

```
                    ┌───────────────┐
                    │  Disconnected │
                    │   (S3.2)      │
                    └───────┬───────┘
                            │
                    didConnect()
                            │
                            ▼
                    ┌───────────────┐
              ┌────│   Connected   │────┐
              │    │    (S3.1)     │    │
              │    └───────┬───────┘    │
              │            │            │
     NotificationCaptured  │   didDisconnect()
              │            │            │
              ▼            │            ▼
    ┌──────────────┐       │   ┌───────────────┐
    │ Show Banner  │       │   │  Disconnected │
    │   (S3.3)     │       │   │   (S3.2)      │
    │              │       │   └───────────────┘
    │ (auto-dismiss│       │
    │  after 5s)   │       │
    └──────────────┘       │
              │            │
              └────────────┘
```
