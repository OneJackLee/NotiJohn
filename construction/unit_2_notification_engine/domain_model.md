# Unit 2: Notification Engine — Domain Model

## Bounded Context: Notification Capture

This bounded context is the core background service responsible for capturing notifications from user-selected apps, filtering out irrelevant ones, persisting them locally, and forwarding them to the CarPlay UI in real time. It has no user-facing UI of its own.

**Note:** Per design decision DD-1, the `Notification` aggregate defined here is the canonical owner. Unit 4 (CarPlay Notification Management) operates on the same aggregate for management actions (read/unread, dismiss).

---

## Aggregates

### 1. Notification (Aggregate Root)

Represents a single captured notification from a monitored app. This is the canonical notification aggregate shared with Unit 4.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `NotificationId` | Unique identity (UUID, generated at capture time) |
| `sourceApp` | `SourceApp` | Which app sent the notification |
| `content` | `NotificationContent` | Title and body text |
| `capturedAt` | `CaptureTimestamp` | When the notification was captured |
| `fingerprint` | `NotificationFingerprint` | Hash for duplicate detection |
| `readStatus` | `ReadStatus` | Whether the notification has been read (managed by Unit 4) |

**Invariants:**
- `id` is immutable once assigned.
- `sourceApp`, `content`, `capturedAt`, and `fingerprint` are immutable after creation.
- `readStatus` defaults to `unread` at creation.

**Factory Method:**
| Method | Description | Emits |
|--------|-------------|-------|
| `Notification.capture(sourceApp, content, timestamp)` | Create a new notification from a raw OS notification | `NotificationCaptured` |

**Commands (owned by Unit 2):**
| Command | Description | Emits |
|---------|-------------|-------|
| _(none — Unit 2 creates notifications but does not mutate them after capture)_ | | |

**Commands (delegated to Unit 4):**
| Command | Description | Emits |
|---------|-------------|-------|
| `markAsRead()` | Mark this notification as read | `NotificationMarkedAsRead` |
| `dismiss()` | Permanently remove this notification | `NotificationDismissed` |

See Unit 4's domain model for full details on these commands.

---

### 2. MonitoredAppFilter (Aggregate Root)

Maintains the set of bundle identifiers that should be monitored. This is Unit 2's local projection of Unit 1's `MonitoredAppSettings`.

| Field | Type | Description |
|-------|------|-------------|
| `enabledBundleIds` | `Set<BundleIdentifier>` | Bundle IDs currently enabled for monitoring |

**Invariants:**
- Updated reactively when `AppMonitoringEnabled` / `AppMonitoringDisabled` events are received from Unit 1.

**Commands:**
| Command | Description |
|---------|-------------|
| `addApp(bundleId: BundleIdentifier)` | Add a bundle ID to the filter |
| `removeApp(bundleId: BundleIdentifier)` | Remove a bundle ID from the filter |
| `shouldCapture(bundleId: BundleIdentifier) → Bool` | Check if a notification from this app should be captured |

---

## Entities

_(No additional entities beyond the aggregate roots.)_

---

## Value Objects

### NotificationId
| Field | Type | Description |
|-------|------|-------------|
| `value` | `UUID` | Unique identifier generated at capture time |

### SourceApp
| Field | Type | Description |
|-------|------|-------------|
| `bundleId` | `BundleIdentifier` | The sending app's bundle identifier |
| `appName` | `String` | Human-readable app name |
| `appIcon` | `Data?` | App icon image data |

### NotificationContent
| Field | Type | Description |
|-------|------|-------------|
| `title` | `String` | Notification title |
| `body` | `String` | Notification body text |

### CaptureTimestamp
| Field | Type | Description |
|-------|------|-------------|
| `value` | `Date` | Exact date/time when the notification was captured |

### NotificationFingerprint
| Field | Type | Description |
|-------|------|-------------|
| `value` | `String` | Hash of `(bundleId + title + body)` — used for duplicate detection in Unit 3 |

**Computation:** Generated deterministically from `sourceApp.bundleId`, `content.title`, and `content.body`.

### ReadStatus (Enum)
| Case | Description |
|------|-------------|
| `unread` | Notification has not been viewed (default) |
| `read` | Notification has been marked as read |

### BundleIdentifier
_(Shared value object — same definition as Unit 1)_

| Field | Type | Description |
|-------|------|-------------|
| `value` | `String` | iOS app bundle ID |

---

## Domain Events

| Event | Payload | Triggered By |
|-------|---------|--------------|
| `NotificationCaptured` | `notificationId: NotificationId, sourceApp: SourceApp, content: NotificationContent, capturedAt: CaptureTimestamp, fingerprint: NotificationFingerprint` | `Notification.capture()` |
| `NotificationsPruned` | `prunedCount: Int, oldestRemainingTimestamp: CaptureTimestamp` | `StorageCapPolicy` |

### Event Consumers

| Event | Consumer | Reaction |
|-------|----------|----------|
| `NotificationCaptured` | **Unit 3 (CarPlay Presentation)** | Display banner and/or announce via TTS if CarPlay is connected |
| `NotificationCaptured` | **Unit 4 (CarPlay Notification Management)** | New entry appears in the notification list |
| `AppMonitoringEnabled` (from Unit 1) | `MonitoredAppFilter` | Add bundle ID to the capture filter |
| `AppMonitoringDisabled` (from Unit 1) | `MonitoredAppFilter` | Remove bundle ID from the capture filter |

---

## Policies

### AppFilterPolicy
- **Rule:** Only capture notifications from apps whose `bundleId` is in the `MonitoredAppFilter.enabledBundleIds` set.
- **Enforcement:** The `NotificationListenerService` consults `MonitoredAppFilter.shouldCapture()` before creating a `Notification` aggregate.
- **Rationale:** US-2.1 — "Notifications from non-selected apps are ignored."

### StorageCapPolicy
- **Rule:** The total number of stored notifications must not exceed a configurable limit (default: 100). When the limit is exceeded, the oldest notifications are pruned.
- **Enforcement:** After each `NotificationCaptured` event, the `NotificationRepository` checks the count and prunes excess entries, emitting `NotificationsPruned`.
- **Rationale:** US-2.2 — "Storage does not grow unbounded."

---

## Repositories

### NotificationRepository
| Operation | Description |
|-----------|-------------|
| `save(notification: Notification)` | Persist a newly captured notification |
| `findById(id: NotificationId) → Notification?` | Retrieve a notification by ID |
| `findAll(sortedBy: .mostRecent) → [Notification]` | List all notifications, most recent first |
| `findAllUnread() → [Notification]` | List all unread notifications |
| `count() → Int` | Return total stored notification count |
| `pruneOldest(exceeding limit: Int)` | Remove oldest notifications beyond the limit |
| `delete(id: NotificationId)` | Permanently delete a single notification |
| `deleteAll()` | Permanently delete all notifications |

**Implementation note:** Backed by Core Data / SwiftData or SQLite. Shared between Units 2 and 4 — Unit 2 writes, Unit 4 reads and updates status.

---

## Domain Services

### NotificationListenerService
Listens to the iOS notification center for incoming notifications from any app.

| Operation | Description |
|-----------|-------------|
| `startListening()` | Begin observing notifications in the background |
| `stopListening()` | Stop observing notifications |

**Behavior:**
1. Receives a raw OS notification.
2. Checks `MonitoredAppFilter.shouldCapture(bundleId)`.
3. If yes, calls `Notification.capture(...)` to create the aggregate.
4. Saves via `NotificationRepository`.
5. Publishes `NotificationCaptured` event.

**Note:** This is an infrastructure-dependent service wrapping iOS `UNUserNotificationCenter` / Notification Service Extension APIs. The domain depends on its protocol, not implementation.

### NotificationDispatcher
Forwards captured notifications to Unit 3 for real-time CarPlay display.

| Operation | Description |
|-----------|-------------|
| `dispatch(event: NotificationCaptured)` | Forward the event to Unit 3's presentation layer |

**Behavior:**
- When CarPlay is connected: forwards the event immediately for banner display and TTS.
- When CarPlay is disconnected: no action needed (notifications are already persisted and will appear in the list upon reconnection per US-2.3 / US-5.3).

---

## Aggregate Boundary Diagram

```
┌──────────────────────────────────────────────────────┐
│              Notification (AR)                        │
│                                                      │
│  - id              ← NotificationId (VO)             │
│  - sourceApp       ← SourceApp (VO)                  │
│  - content         ← NotificationContent (VO)        │
│  - capturedAt      ← CaptureTimestamp (VO)            │
│  - fingerprint     ← NotificationFingerprint (VO)    │
│  - readStatus      ← ReadStatus (VO, managed by U4)  │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│          MonitoredAppFilter (AR)                      │
│                                                      │
│  - enabledBundleIds  ← Set<BundleIdentifier>         │
│                                                      │
│  Reacts to: AppMonitoringEnabled / Disabled (Unit 1) │
└──────────────────────────────────────────────────────┘
```

---

## Integration with Other Units

| Direction | Unit | Mechanism |
|-----------|------|-----------|
| Inbound ← | Unit 1 (iPhone Companion App) | Subscribes to `AppMonitoringEnabled` / `AppMonitoringDisabled` to maintain the `MonitoredAppFilter`. |
| Outbound → | Unit 3 (CarPlay Presentation) | Publishes `NotificationCaptured` for real-time display and TTS. |
| Outbound → | Unit 4 (CarPlay Notification Management) | Shares the `NotificationRepository` — Unit 4 reads and updates notification state. |
