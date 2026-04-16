# Unit 3: CarPlay Presentation — Data Binding

## Overview

Unit 3 is event-driven with no persistent UI state to bind. Data flows from the `DomainEventBus` through the `IncomingNotificationHandler` to the `BannerPresentationService`. There are no ViewModels or observable state — all processing is imperative and triggered by events.

---

## Event → Banner Pipeline

```
DomainEventBus
  │
  │ subscribe(to: NotificationCaptured.self)
  │
  ▼
IncomingNotificationHandler
  │
  ├── CarPlaySession.isConnected? ──NO──→ (discard, no-op)
  │
  ├── DuplicateSuppressionPolicy.isDuplicate? ──YES──→ publish(DuplicateNotificationSuppressed)
  │
  └── Pass ──→ NotificationBanner.from(event)
                  │
                  ▼
              BannerPresentationService.show(banner)
                  │
                  ├── UNNotificationRequest created
                  │     title: sourceApp.appName
                  │     subtitle: content.title
                  │     body: content.body (truncated)
                  │
                  └── UNUserNotificationCenter.add(request)
                        │
                        ▼
                      System displays on CarPlay
                        │
                        ▼ (after BannerDuration.seconds)
                      BannerAppService.scheduleBannerDismissal()
                        │
                        ▼
                      UNUserNotificationCenter.removeDeliveredNotifications()
```

---

## Data Transformations

### NotificationCaptured → NotificationBanner

| Source (Event) | Target (Banner) | Transformation |
|----------------|-----------------|----------------|
| `sourceApp.appName` | `sourceAppName` | Direct copy |
| `content.title` | `title` | Direct copy |
| `content.body` | `bodyPreview` | Truncated to 100 characters |
| `notificationId` | `notificationId` | Direct copy |
| — | `displayDuration` | Default `BannerDuration(seconds: 5)` |

### NotificationBanner → UNNotificationContent

| Source (Banner) | Target (UNNotificationContent) | Mapping |
|-----------------|-------------------------------|---------|
| `sourceAppName` | `content.title` | Direct |
| `title` | `content.subtitle` | Direct |
| `bodyPreview` | `content.body` | Direct |
| `notificationId.value.uuidString` | `request.identifier` | Used for later removal |

---

## State Dependencies

### CarPlaySession State

The `IncomingNotificationHandler` reads `CarPlaySession.isConnected` on every event. This is a synchronous property read — no binding or observation needed.

```swift
// Synchronous check — no Combine/observation
guard session.isConnected else { return }
```

### DuplicateSuppressionPolicy State

The `RecentAnnouncementLog` is an in-memory dictionary. Reads and writes are synchronous.

```swift
// Check
let isDupe = recentLog.hasBeenAnnounced(fingerprint: fp, within: window)

// Record
recentLog.record(fingerprint: fp, at: now)
```

---

## Combine Subscriptions

Unit 3 maintains the following long-lived Combine subscriptions:

| Subscription | Source | Handler | Lifetime |
|-------------|--------|---------|----------|
| `NotificationCaptured` | `DomainEventBus` | `IncomingNotificationHandler.handle()` | App lifetime |
| Purge timer | `Timer.publish(every: 60)` | `RecentAnnouncementLog.purgeExpired()` | App lifetime |

**Subscription setup** happens in `Unit3Container` initialization or app startup. Subscriptions are stored in a `Set<AnyCancellable>` owned by the container.

---

## No Persistent State

Unit 3 does not maintain any persistent data binding:
- `CarPlaySession` is in-memory only.
- `RecentAnnouncementLog` is in-memory only.
- Banners are transient system notifications.

All state is reconstructed from scratch on app launch. No data migration or versioning concerns.
