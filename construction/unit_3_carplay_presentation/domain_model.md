# Unit 3: CarPlay Presentation — Domain Model

## Bounded Context: Notification Presentation

This bounded context handles the real-time, event-driven CarPlay experience: displaying incoming notification banners, reading notifications aloud via text-to-speech, suppressing duplicate announcements, and managing the CarPlay connection lifecycle.

---

## Aggregates

### 1. CarPlaySession (Aggregate Root)

Represents the active CarPlay connection session. Tracks connection state and governs whether banners and TTS announcements are active.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `SessionId` | Unique identity per connection session (new ID each time CarPlay connects) |
| `connectionState` | `ConnectionState` | Current connection state |
| `connectedAt` | `Date?` | Timestamp when the session started |
| `disconnectedAt` | `Date?` | Timestamp when the session ended |

**Invariants:**
- Only one active session at a time (previous session must be ended before starting a new one).
- Banners and TTS are only active when `connectionState == .connected`.
- TTS stops immediately on disconnect.

**Commands:**
| Command | Description | Emits |
|---------|-------------|-------|
| `start()` | Establish a new CarPlay session | `CarPlaySessionStarted` |
| `end()` | Terminate the current CarPlay session | `CarPlaySessionEnded` |

---

### 2. AnnouncementQueue (Aggregate Root)

Manages the ordered queue of TTS announcements. Ensures sequential playback and respects navigation guidance.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `QueueId` | Singleton identity (one queue per app) |
| `pendingAnnouncements` | `[PendingAnnouncement]` | Ordered list of announcements waiting to be spoken |
| `currentAnnouncement` | `PendingAnnouncement?` | The announcement currently being spoken |
| `isActive` | `Bool` | Whether the queue is actively processing (paused on disconnect or nav guidance) |

**Invariants:**
- Announcements are played sequentially — never concurrently.
- The queue pauses when `CarPlaySession` is disconnected.
- The queue defers when active navigation guidance is detected.
- Duplicate notifications (per `DuplicateSuppressionPolicy`) are never enqueued.

**Commands:**
| Command | Description | Emits |
|---------|-------------|-------|
| `enqueue(announcement: PendingAnnouncement)` | Add an announcement to the end of the queue | `AnnouncementQueued` |
| `startNext()` | Begin speaking the next announcement in the queue | `AnnouncementStarted` |
| `completeCurrent()` | Mark the current announcement as finished | `AnnouncementCompleted` |
| `pause()` | Pause queue processing (e.g., for nav guidance or disconnect) | `AnnouncementQueuePaused` |
| `resume()` | Resume queue processing | `AnnouncementQueueResumed` |
| `clear()` | Discard all pending announcements (e.g., on disconnect) | `AnnouncementQueueCleared` |

---

## Entities

### PendingAnnouncement

An individual TTS announcement waiting in the queue.

| Field | Type | Description |
|-------|------|-------------|
| `notificationId` | `NotificationId` | Reference to the source notification |
| `utterance` | `TTSUtterance` | The text to be spoken |
| `queuedAt` | `Date` | When this announcement was added to the queue |

**Note:** Entity within the `AnnouncementQueue` aggregate — not accessed independently.

---

## Value Objects

### SessionId
| Field | Type | Description |
|-------|------|-------------|
| `value` | `UUID` | Unique session identifier, generated on each connect |

### ConnectionState (Enum)
| Case | Description |
|------|-------------|
| `connected` | CarPlay is actively connected |
| `disconnected` | CarPlay is not connected |

### NotificationBanner
Represents the visual notification card shown on the CarPlay screen.

| Field | Type | Description |
|-------|------|-------------|
| `notificationId` | `NotificationId` | Reference to the source notification |
| `sourceAppName` | `String` | Name of the app that sent the notification |
| `title` | `String` | Notification title |
| `bodyPreview` | `String` | Truncated preview of the body text |
| `displayDuration` | `BannerDuration` | How long the banner stays visible |

### BannerDuration
| Field | Type | Description |
|-------|------|-------------|
| `seconds` | `TimeInterval` | Duration in seconds before auto-dismiss (default: 5) |

**Validation:** Must be a positive value.

### TTSUtterance
| Field | Type | Description |
|-------|------|-------------|
| `text` | `String` | Formatted text to speak (e.g., "Message from WhatsApp: Hey, are you on your way?") |

**Construction:** Composed from `sourceApp.appName`, `content.title`, and `content.body`.

### NotificationFingerprint
_(Shared value object — same definition as Unit 2)_

| Field | Type | Description |
|-------|------|-------------|
| `value` | `String` | Hash of `(bundleId + title + body)` |

### DuplicateWindow
| Field | Type | Description |
|-------|------|-------------|
| `seconds` | `TimeInterval` | Time window for duplicate suppression (default: 30) |

**Validation:** Must be a positive value.

---

## Domain Events

| Event | Payload | Triggered By |
|-------|---------|--------------|
| `CarPlaySessionStarted` | `sessionId: SessionId, connectedAt: Date` | `CarPlaySession.start()` |
| `CarPlaySessionEnded` | `sessionId: SessionId, disconnectedAt: Date` | `CarPlaySession.end()` |
| `BannerDisplayed` | `notificationId: NotificationId` | `BannerPresentationService` |
| `BannerAutoDismissed` | `notificationId: NotificationId` | `BannerPresentationService` (after duration expires) |
| `AnnouncementQueued` | `notificationId: NotificationId` | `AnnouncementQueue.enqueue()` |
| `AnnouncementStarted` | `notificationId: NotificationId` | `AnnouncementQueue.startNext()` |
| `AnnouncementCompleted` | `notificationId: NotificationId` | `AnnouncementQueue.completeCurrent()` |
| `AnnouncementQueuePaused` | `reason: PauseReason` | `AnnouncementQueue.pause()` |
| `AnnouncementQueueResumed` | _(none)_ | `AnnouncementQueue.resume()` |
| `AnnouncementQueueCleared` | `discardedCount: Int` | `AnnouncementQueue.clear()` |
| `DuplicateNotificationSuppressed` | `notificationId: NotificationId, fingerprint: NotificationFingerprint` | `DuplicateSuppressionPolicy` |

### Event Consumers

| Event | Consumer | Reaction |
|-------|----------|----------|
| `NotificationCaptured` (from Unit 2) | `IncomingNotificationHandler` | Trigger banner display and TTS enqueue (if not duplicate, if connected) |
| `CarPlaySessionStarted` | `AnnouncementQueue` | Activate the queue |
| `CarPlaySessionEnded` | `AnnouncementQueue` | Clear the queue and stop TTS immediately |
| `AnnouncementCompleted` | `AnnouncementQueue` | Auto-advance to next pending announcement |

---

## Policies

### DuplicateSuppressionPolicy
- **Rule:** If the same notification fingerprint (same `bundleId + title + body`) has been announced within the `DuplicateWindow`, suppress the new announcement. The notification is still stored in the list (per US-3.3 AC) but not re-announced or re-bannered.
- **Enforcement:** Before enqueueing, check the `RecentAnnouncementLog` for a matching fingerprint within the time window.
- **Rationale:** US-3.3 — "duplicate or repeated notifications to not be announced multiple times."

### NavigationGuidanceRespectPolicy
- **Rule:** TTS announcements must not interrupt active navigation voice guidance. If nav guidance is detected, pause the `AnnouncementQueue` and resume after guidance finishes.
- **Enforcement:** The `TTSService` monitors the audio session for navigation interruptions and signals the `AnnouncementQueue` to pause/resume.
- **Rationale:** US-3.2 AC — "TTS does not interrupt active navigation voice guidance."

### DisconnectCleanupPolicy
- **Rule:** When CarPlay disconnects, immediately stop any in-progress TTS and clear the announcement queue. Banners are no longer displayed.
- **Enforcement:** On `CarPlaySessionEnded`, the `AnnouncementQueue.clear()` is called and `TTSService.stopImmediately()` is invoked.
- **Rationale:** US-5.3 AC — "TTS announcements stop immediately when CarPlay disconnects."

---

## Repositories

### RecentAnnouncementLog
An in-memory, time-windowed store of recently announced notification fingerprints for duplicate detection.

| Operation | Description |
|-----------|-------------|
| `record(fingerprint: NotificationFingerprint, at: Date)` | Log that a notification with this fingerprint was announced |
| `hasBeenAnnounced(fingerprint: NotificationFingerprint, within: DuplicateWindow) → Bool` | Check if this fingerprint was announced recently |
| `purgeExpired()` | Remove entries older than the duplicate window |

**Implementation note:** In-memory dictionary with timestamp values. No persistence needed — cleared on app restart.

---

## Domain Services

### IncomingNotificationHandler
Orchestrates the response to a `NotificationCaptured` event from Unit 2.

| Operation | Description |
|-----------|-------------|
| `handle(event: NotificationCaptured)` | Coordinate banner display and TTS announcement |

**Behavior:**
1. Check `CarPlaySession.connectionState` — if disconnected, do nothing (notification is already persisted by Unit 2).
2. Check `DuplicateSuppressionPolicy` — if duplicate, emit `DuplicateNotificationSuppressed` and skip.
3. Create a `NotificationBanner` and pass to `BannerPresentationService`.
4. Create a `PendingAnnouncement` and enqueue in `AnnouncementQueue`.

### BannerPresentationService
Displays notification banners on the CarPlay screen.

| Operation | Description |
|-----------|-------------|
| `show(banner: NotificationBanner)` | Display the banner on the CarPlay UI |
| `dismiss(notificationId: NotificationId)` | Programmatically dismiss a banner |

**Behavior:** Shows the banner, schedules auto-dismiss after `BannerDuration`, emits `BannerDisplayed` and `BannerAutoDismissed`.

**Note:** Infrastructure-dependent — wraps CarPlay UI framework APIs.

### TTSService
Text-to-speech engine wrapper.

| Operation | Description |
|-----------|-------------|
| `speak(utterance: TTSUtterance, completion: () → Void)` | Speak text through the car's speakers |
| `stopImmediately()` | Cancel any in-progress speech |
| `isNavigationGuidanceActive() → Bool` | Check if nav guidance is currently playing |

**Note:** Infrastructure-dependent — wraps `AVSpeechSynthesizer` and the CarPlay audio session.

---

## Aggregate Boundary Diagram

```
┌───────────────────────────────────────────┐
│         CarPlaySession (AR)               │
│                                           │
│  - id               ← SessionId (VO)     │
│  - connectionState  ← ConnectionState    │
│  - connectedAt                            │
│  - disconnectedAt                         │
└───────────────────────────────────────────┘

┌───────────────────────────────────────────────────┐
│         AnnouncementQueue (AR)                     │
│                                                   │
│  ┌─────────────────────────────┐                  │
│  │   PendingAnnouncement       │  ← Entity        │
│  │   - notificationId          │                  │
│  │   - utterance (TTSUtterance)│  ← VO            │
│  │   - queuedAt                │                  │
│  └─────────────────────────────┘                  │
│       (0..N instances, ordered)                   │
│                                                   │
│  - currentAnnouncement                            │
│  - isActive                                       │
└───────────────────────────────────────────────────┘
```

---

## Integration with Other Units

| Direction | Unit | Mechanism |
|-----------|------|-----------|
| Inbound ← | Unit 2 (Notification Engine) | Subscribes to `NotificationCaptured` events for real-time display and TTS. |
| Sibling ↔ | Unit 4 (CarPlay Notification Management) | Both operate on the CarPlay UI but on different screens/flows. Minimal direct coupling — Unit 3 handles real-time banners, Unit 4 handles the list view. |
