# Unit 4: CarPlay Notification Management — Domain Model

## Bounded Context: Notification Management

This bounded context covers the CarPlay screens where drivers browse, inspect, and manage stored notifications. It is state-driven (CRUD operations on notification records) rather than event-driven, making it distinct from Unit 3's real-time presentation concerns.

**Note:** Per design decision DD-1, this unit operates on the same `Notification` aggregate defined in Unit 2. Unit 2 owns creation/storage; this unit owns read status management and dismissal.

---

## Aggregates

### Notification (Aggregate Root — shared with Unit 2)

This unit adds management commands to the `Notification` aggregate defined in Unit 2. The aggregate fields are defined in Unit 2's domain model; this section documents only the commands and behavior owned by Unit 4.

**Commands (owned by Unit 4):**
| Command | Description | Precondition | Emits |
|---------|-------------|--------------|-------|
| `markAsRead()` | Set `readStatus` to `.read` | `readStatus == .unread` (idempotent if already read) | `NotificationMarkedAsRead` |
| `dismiss()` | Permanently remove this notification | Notification exists | `NotificationDismissed` |

**Invariants (owned by Unit 4):**
- A dismissed notification is permanently removed — it cannot be un-dismissed.
- Marking as read is idempotent — calling `markAsRead()` on an already-read notification is a no-op.
- Dismissing is distinct from marking as read — a notification can be read but not dismissed.

---

## Entities

_(No additional entities. This unit operates on the `Notification` aggregate from Unit 2.)_

---

## Value Objects

### ReadStatus (Enum)
_(Shared value object — same definition as Unit 2)_

| Case | Description |
|------|-------------|
| `unread` | Notification has not been viewed (default) |
| `read` | Notification has been marked as read |

### NotificationSummary
A read-optimized projection of a `Notification` for list display.

| Field | Type | Description |
|-------|------|-------------|
| `notificationId` | `NotificationId` | Reference to the notification |
| `sourceAppName` | `String` | Name of the sending app |
| `title` | `String` | Notification title |
| `capturedAt` | `Date` | When the notification was captured |
| `readStatus` | `ReadStatus` | Current read/unread state |

### NotificationDetail
A read-optimized projection of a `Notification` for detail display.

| Field | Type | Description |
|-------|------|-------------|
| `notificationId` | `NotificationId` | Reference to the notification |
| `sourceAppName` | `String` | Name of the sending app |
| `appIcon` | `Data?` | App icon image data |
| `title` | `String` | Notification title |
| `body` | `String` | Full notification body text |
| `capturedAt` | `Date` | When the notification was captured |
| `readStatus` | `ReadStatus` | Current read/unread state |

---

## Domain Events

| Event | Payload | Triggered By |
|-------|---------|--------------|
| `NotificationMarkedAsRead` | `notificationId: NotificationId` | `Notification.markAsRead()` |
| `NotificationDismissed` | `notificationId: NotificationId` | `Notification.dismiss()` |
| `AllNotificationsCleared` | `clearedCount: Int` | `NotificationClearingService.clearAll()` |

### Event Consumers

| Event | Consumer | Reaction |
|-------|----------|----------|
| `NotificationCaptured` (from Unit 2) | Notification list view | New entry appears at top of the list |
| `NotificationMarkedAsRead` | Notification list view | Update visual indicator (remove unread dot/bold) |
| `NotificationDismissed` | Notification list view | Remove entry from the list |
| `AllNotificationsCleared` | Notification list view | Clear the entire list |

---

## Policies

### AutoMarkAsReadOnViewPolicy
- **Rule:** When a user opens the detail view of a notification, it is automatically marked as read.
- **Enforcement:** The application service handling the "view detail" use case calls `notification.markAsRead()` as a side effect of loading the detail.
- **Rationale:** US-4.2 AC — "Opening a notification detail automatically marks it as read." Also US-4.4 AC — "Opening a notification detail also marks it as read."

### ClearAllConfirmationPolicy
- **Rule:** The "Clear All" action requires a confirmation step before execution to prevent accidental clearing.
- **Enforcement:** This is enforced at the application/UI layer — the domain service `NotificationClearingService.clearAll()` assumes confirmation has already been obtained.
- **Rationale:** US-4.6 AC — "A confirmation step prevents accidental clearing."

---

## Repositories

### NotificationRepository (shared with Unit 2)

This unit uses the same `NotificationRepository` defined in Unit 2, with the following operations being particularly relevant:

| Operation | Used By | Description |
|-----------|---------|-------------|
| `findAll(sortedBy: .mostRecent) → [Notification]` | List view (US-4.1) | Load all notifications, most recent first |
| `findById(id: NotificationId) → Notification?` | Detail view (US-4.2) | Load a single notification for detail display |
| `save(notification: Notification)` | Mark as read (US-4.4) | Persist updated read status |
| `delete(id: NotificationId)` | Dismiss (US-4.5) | Permanently remove a notification |
| `deleteAll()` | Clear all (US-4.6) | Permanently remove all notifications |

---

## Domain Services

### NotificationClearingService
Handles the bulk "clear all" operation.

| Operation | Description |
|-----------|-------------|
| `clearAll()` | Delete all notifications from the repository and emit `AllNotificationsCleared` |

**Behavior:**
1. Count current notifications for the event payload.
2. Call `NotificationRepository.deleteAll()`.
3. Emit `AllNotificationsCleared(clearedCount)`.

**Note:** Confirmation is handled by the UI/application layer before calling this service (per `ClearAllConfirmationPolicy`).

---

## Use Case Flows

### View Notification List (US-4.1, US-4.3)
1. Query `NotificationRepository.findAll(sortedBy: .mostRecent)`.
2. Map each `Notification` to a `NotificationSummary` value object.
3. Render the list with visual distinction for `readStatus == .unread` (bold text / dot indicator).

### View Notification Detail (US-4.2)
1. Query `NotificationRepository.findById(id)`.
2. Apply `AutoMarkAsReadOnViewPolicy` → call `notification.markAsRead()`.
3. Save updated notification via `NotificationRepository.save()`.
4. Map to `NotificationDetail` value object.
5. Render the detail view.

### Mark as Read (US-4.4)
1. Load notification via `NotificationRepository.findById(id)`.
2. Call `notification.markAsRead()`.
3. Save via `NotificationRepository.save()`.
4. `NotificationMarkedAsRead` event updates the list view.

### Dismiss Notification (US-4.5)
1. Load notification via `NotificationRepository.findById(id)`.
2. Call `notification.dismiss()` — emits `NotificationDismissed`.
3. Call `NotificationRepository.delete(id)`.
4. List view removes the entry.

### Clear All Notifications (US-4.6)
1. UI presents confirmation dialog (per `ClearAllConfirmationPolicy`).
2. On confirmation, call `NotificationClearingService.clearAll()`.
3. `AllNotificationsCleared` event clears the list view.

---

## Aggregate Boundary Diagram

```
┌──────────────────────────────────────────────────────┐
│        Notification (AR — defined in Unit 2)          │
│                                                      │
│  Fields (owned by Unit 2):                           │
│  - id, sourceApp, content, capturedAt, fingerprint   │
│                                                      │
│  State (managed by Unit 4):                          │
│  - readStatus      ← ReadStatus (VO)                │
│                                                      │
│  Commands (owned by Unit 4):                         │
│  - markAsRead()    → NotificationMarkedAsRead        │
│  - dismiss()       → NotificationDismissed           │
└──────────────────────────────────────────────────────┘

  Projections for CarPlay UI:

  ┌────────────────────────┐    ┌────────────────────────┐
  │  NotificationSummary   │    │  NotificationDetail    │
  │  (VO — list view)      │    │  (VO — detail view)    │
  │  - sourceAppName       │    │  - sourceAppName       │
  │  - title               │    │  - appIcon             │
  │  - capturedAt          │    │  - title               │
  │  - readStatus          │    │  - body                │
  └────────────────────────┘    │  - capturedAt          │
                                │  - readStatus          │
                                └────────────────────────┘
```

---

## Integration with Other Units

| Direction | Unit | Mechanism |
|-----------|------|-----------|
| Inbound ← | Unit 2 (Notification Engine) | Reads from the shared `NotificationRepository` that Unit 2 writes to. Subscribes to `NotificationCaptured` events for real-time list updates. |
| Sibling ↔ | Unit 3 (CarPlay Presentation) | Both operate on CarPlay but on different screens/flows. Minimal direct coupling — Unit 3 handles real-time banners/TTS, Unit 4 handles the persistent list. |
