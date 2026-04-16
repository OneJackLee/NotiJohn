# Unit 2: Notification Engine — API Contract

## Overview

Unit 2 has no user-facing UI. This document defines the API contract that other units consume: the domain events published by Unit 2, the shared `NotificationRepository`, and the `NotificationQueryService`.

---

## Published Domain Events

These events are published on the shared `DomainEventBus` and consumed by Units 3 and 4.

### NotificationCaptured

Published when a new notification is successfully captured and persisted.

```swift
struct NotificationCaptured: DomainEvent {
    let notificationId: NotificationId    // UUID of the new notification
    let sourceApp: SourceApp              // bundleId, appName, appIcon
    let content: NotificationContent      // title, body
    let capturedAt: CaptureTimestamp      // capture timestamp
    let fingerprint: NotificationFingerprint  // hash for duplicate detection
    let occurredAt: Date                  // event timestamp
}
```

**Consumers:**
| Consumer | Reaction |
|----------|----------|
| Unit 3 (`IncomingNotificationHandler`) | Display banner on CarPlay (if connected, if not duplicate) |
| Unit 4 (`NotificationListAppService`) | Refresh list to show new notification at top |

---

### NotificationsPruned

Published when oldest notifications are pruned to enforce the storage cap.

```swift
struct NotificationsPruned: DomainEvent {
    let prunedCount: Int                          // how many were removed
    let oldestRemainingTimestamp: CaptureTimestamp // timestamp of the oldest surviving notification
    let occurredAt: Date
}
```

**Consumers:**
| Consumer | Reaction |
|----------|----------|
| Unit 4 (`NotificationListAppService`) | Refresh list (removed entries disappear) |

---

## Consumed Domain Events

Unit 2 subscribes to these events from Unit 1.

| Event | Source | Handler |
|-------|--------|---------|
| `AppMonitoringEnabled` | Unit 1 | `MonitoredAppFilter.addApp(bundleId:)` |
| `AppMonitoringDisabled` | Unit 1 | `MonitoredAppFilter.removeApp(bundleId:)` |

---

## Shared Repository: NotificationRepository

Unit 4 shares the same `NotificationRepository` instance. The interface:

```swift
protocol NotificationRepository {
    // Write operations (used by Unit 2 capture pipeline)
    func save(_ notification: Notification) async throws
    func pruneOldest(exceeding limit: Int) async throws -> Int

    // Read operations (used by Unit 4 via NotificationQueryService)
    func findById(_ id: NotificationId) async -> Notification?
    func findAll(sortedBy: NotificationSortOrder) async -> [Notification]
    func findAllUnread() async -> [Notification]
    func count() async -> Int

    // Delete operations (used by Unit 4 management)
    func delete(_ id: NotificationId) async throws
    func deleteAll() async throws -> Int
}
```

**Thread safety:** The SwiftData `ModelContext` is accessed on a single actor. All repository operations are `async` and dispatched to the appropriate context.

---

## Shared Query Service: NotificationQueryService

Read-only service provided for Unit 4's convenience.

```swift
final class NotificationQueryService {
    func fetchAll() async -> [Notification]
    func fetchById(_ id: NotificationId) async -> Notification?
    func fetchUnreadCount() async -> Int
}
```

---

## Notification Aggregate (Shared Data Contract)

The `Notification` aggregate is the canonical data object shared between Units 2 and 4:

```swift
final class Notification {
    let id: NotificationId                    // UUID
    let sourceApp: SourceApp                  // bundleId, appName, appIcon
    let content: NotificationContent          // title, body
    let capturedAt: CaptureTimestamp           // capture timestamp
    let fingerprint: NotificationFingerprint   // duplicate detection hash
    private(set) var readStatus: ReadStatus    // .unread (default) or .read
}
```

**Ownership:**
- Unit 2 creates instances via `Notification.capture()` and persists them.
- Unit 4 reads and modifies `readStatus` via `markAsRead()` and deletes via `dismiss()`.

---

## Integration Points Summary

```
Unit 1                Unit 2                  Unit 3
  │                     │                       │
  │ AppMonitoring       │ NotificationCaptured  │
  │ Enabled/Disabled    │ ─────────────────────→│ (banner display)
  │ ───────────────────→│                       │
  │                     │ NotificationCaptured  │
  │                     │ ─────────────────────→│ Unit 4
  │                     │                       │ (list refresh)
  │                     │                       │
  │                     │ NotificationRepository│
  │                     │ ←────────────────────→│ Unit 4
  │                     │   (shared instance)   │ (read/update/delete)
```
