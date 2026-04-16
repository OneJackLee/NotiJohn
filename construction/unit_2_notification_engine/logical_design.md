# Unit 2: Notification Engine — Logical Design

## Overview

This document translates the Unit 2 domain model into an implementable Swift/iOS architecture. Unit 2 is the core background service: capturing notifications from user-selected apps, filtering, persisting, and forwarding them to the CarPlay UI. It has no user-facing UI.

**Note:** The `Notification` aggregate defined here is the canonical owner. Unit 4 operates on the same aggregate for management actions (read/unread, dismiss).

---

## Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│  (No Presentation Layer — Unit 2 has no UI)             │
├─────────────────────────────────────────────────────────┤
│  Application Layer (Use Cases / App Services)           │
│  - NotificationCaptureService                           │
│  - NotificationQueryService (shared with Unit 4)        │
├─────────────────────────────────────────────────────────┤
│  Domain Layer (Aggregates, VOs, Events, Policies)       │
│  - Notification, MonitoredAppFilter                     │
│  - AppFilterPolicy, StorageCapPolicy                    │
├─────────────────────────────────────────────────────────┤
│  Infrastructure Layer (Persistence, OS APIs, Event Bus) │
│  - SwiftDataNotificationRepository                      │
│  - IOSNotificationListenerService                       │
│  - NotificationDispatcherImpl                           │
│  - CombineDomainEventBus (shared)                       │
└─────────────────────────────────────────────────────────┘
```

---

## Module Structure

```
NotiJohn/
├── Domain/
│   ├── Unit2/
│   │   ├── Aggregates/
│   │   │   ├── Notification.swift
│   │   │   └── MonitoredAppFilter.swift
│   │   ├── ValueObjects/
│   │   │   ├── NotificationId.swift
│   │   │   ├── SourceApp.swift
│   │   │   ├── NotificationContent.swift
│   │   │   ├── CaptureTimestamp.swift
│   │   │   ├── NotificationFingerprint.swift
│   │   │   └── ReadStatus.swift
│   │   ├── Events/
│   │   │   ├── NotificationCaptured.swift
│   │   │   └── NotificationsPruned.swift
│   │   ├── Policies/
│   │   │   ├── AppFilterPolicy.swift
│   │   │   └── StorageCapPolicy.swift
│   │   └── Protocols/
│   │       ├── NotificationRepository.swift
│   │       ├── NotificationListenerService.swift
│   │       └── NotificationDispatcher.swift
│   └── Shared/
│       └── BundleIdentifier.swift               ← shared VO
├── Application/
│   └── Unit2/
│       ├── NotificationCaptureAppService.swift
│       └── NotificationQueryService.swift        ← shared with Unit 4
├── Infrastructure/
│   └── Unit2/
│       ├── SwiftDataNotificationRepository.swift
│       ├── IOSNotificationListenerService.swift
│       ├── NotificationDispatcherImpl.swift
│       └── Persistence/
│           └── NotificationModel.swift           ← SwiftData @Model
└── DI/
    └── Unit2Container.swift
```

---

## Domain Layer

### Aggregate: Notification (Canonical — shared with Unit 4)

```swift
// Notification.swift
final class Notification {
    let id: NotificationId
    let sourceApp: SourceApp
    let content: NotificationContent
    let capturedAt: CaptureTimestamp
    let fingerprint: NotificationFingerprint
    private(set) var readStatus: ReadStatus

    // Factory method (Unit 2 owns creation)
    static func capture(
        sourceApp: SourceApp,
        content: NotificationContent,
        timestamp: Date
    ) -> (notification: Notification, event: NotificationCaptured)

    // Commands owned by Unit 4 (defined here, invoked by Unit 4's services)
    func markAsRead() -> NotificationMarkedAsRead?    // nil if already read
    func dismiss() -> NotificationDismissed
}
```

**Implementation notes:**
- Factory method generates `NotificationId` (UUID), computes `NotificationFingerprint`, sets `readStatus = .unread`, returns both the aggregate and the domain event.
- `markAsRead()` returns `nil` if already `.read` (idempotent).
- `dismiss()` always returns the event — actual deletion is handled by the repository.

### Aggregate: MonitoredAppFilter

```swift
// MonitoredAppFilter.swift
final class MonitoredAppFilter {
    private(set) var enabledBundleIds: Set<BundleIdentifier>

    func addApp(bundleId: BundleIdentifier)
    func removeApp(bundleId: BundleIdentifier)
    func shouldCapture(bundleId: BundleIdentifier) -> Bool
}
```

**Implementation notes:**
- In-memory aggregate — no persistence needed. Rebuilt on launch from `MonitoredAppSettings` (Unit 1) via the repository or event replay.
- `shouldCapture` is a pure query — returns `enabledBundleIds.contains(bundleId)`.

### Value Objects

```swift
struct NotificationId: Hashable, Codable {
    let value: UUID
    init() { self.value = UUID() }
}

struct SourceApp: Hashable, Codable {
    let bundleId: BundleIdentifier
    let appName: String
    let appIcon: Data?
}

struct NotificationContent: Hashable, Codable {
    let title: String
    let body: String
}

struct CaptureTimestamp: Hashable, Codable, Comparable {
    let value: Date
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.value < rhs.value }
}

struct NotificationFingerprint: Hashable, Codable {
    let value: String

    /// Deterministic hash from bundleId + title + body
    static func compute(bundleId: BundleIdentifier, title: String, body: String) -> NotificationFingerprint {
        let input = "\(bundleId.value)|\(title)|\(body)"
        // Use SHA256 or a simpler hash for fingerprinting
        return NotificationFingerprint(value: input.sha256Hash)
    }
}

enum ReadStatus: String, Codable {
    case unread
    case read
}
```

### Domain Events

```swift
struct NotificationCaptured: DomainEvent {
    let notificationId: NotificationId
    let sourceApp: SourceApp
    let content: NotificationContent
    let capturedAt: CaptureTimestamp
    let fingerprint: NotificationFingerprint
    let occurredAt: Date
}

struct NotificationsPruned: DomainEvent {
    let prunedCount: Int
    let oldestRemainingTimestamp: CaptureTimestamp
    let occurredAt: Date
}

// Events owned by Unit 4 but defined on the Notification aggregate
struct NotificationMarkedAsRead: DomainEvent {
    let notificationId: NotificationId
    let occurredAt: Date
}

struct NotificationDismissed: DomainEvent {
    let notificationId: NotificationId
    let occurredAt: Date
}

struct AllNotificationsCleared: DomainEvent {
    let clearedCount: Int
    let occurredAt: Date
}
```

### Policies

#### AppFilterPolicy

```swift
// AppFilterPolicy.swift
struct AppFilterPolicy {
    private let filter: MonitoredAppFilter

    /// Returns true if a notification from this bundle ID should be captured.
    func shouldCapture(bundleId: BundleIdentifier) -> Bool {
        filter.shouldCapture(bundleId: bundleId)
    }
}
```

**Implementation notes:** Thin wrapper — exists as a named policy for documentation clarity. The `NotificationCaptureAppService` consults this before creating a `Notification`.

#### StorageCapPolicy

```swift
// StorageCapPolicy.swift
struct StorageCapPolicy {
    let maxNotifications: Int  // default: 100

    /// Returns the number of notifications to prune, or 0 if within cap.
    func prunableCount(currentCount: Int) -> Int {
        max(0, currentCount - maxNotifications)
    }
}
```

### Repository Protocol

```swift
protocol NotificationRepository {
    func save(_ notification: Notification) async throws
    func findById(_ id: NotificationId) async -> Notification?
    func findAll(sortedBy: NotificationSortOrder) async -> [Notification]
    func findAllUnread() async -> [Notification]
    func count() async -> Int
    func pruneOldest(exceeding limit: Int) async throws -> Int  // returns pruned count
    func delete(_ id: NotificationId) async throws
    func deleteAll() async throws -> Int  // returns deleted count
}

enum NotificationSortOrder {
    case mostRecent
}
```

### Domain Service Protocols

```swift
protocol NotificationListenerService {
    func startListening()
    func stopListening()
}

protocol NotificationDispatcher {
    func dispatch(event: NotificationCaptured)
}
```

---

## Application Layer

### NotificationCaptureAppService

Orchestrates the notification capture pipeline.

```swift
final class NotificationCaptureAppService {
    private let filter: MonitoredAppFilter
    private let filterPolicy: AppFilterPolicy
    private let storageCapPolicy: StorageCapPolicy
    private let repository: NotificationRepository
    private let eventBus: DomainEventBus
    private let dispatcher: NotificationDispatcher

    /// Called by the NotificationListenerService when a raw notification arrives.
    func handleIncomingNotification(
        bundleId: BundleIdentifier,
        appName: String,
        appIcon: Data?,
        title: String,
        body: String
    ) async throws {
        // 1. Check AppFilterPolicy
        guard filterPolicy.shouldCapture(bundleId: bundleId) else { return }

        // 2. Create Notification aggregate
        let sourceApp = SourceApp(bundleId: bundleId, appName: appName, appIcon: appIcon)
        let content = NotificationContent(title: title, body: body)
        let (notification, event) = Notification.capture(
            sourceApp: sourceApp,
            content: content,
            timestamp: Date()
        )

        // 3. Persist
        try await repository.save(notification)

        // 4. Enforce StorageCapPolicy
        let currentCount = await repository.count()
        let toPrune = storageCapPolicy.prunableCount(currentCount: currentCount)
        if toPrune > 0 {
            let pruned = try await repository.pruneOldest(exceeding: storageCapPolicy.maxNotifications)
            if pruned > 0 {
                eventBus.publish(NotificationsPruned(
                    prunedCount: pruned,
                    oldestRemainingTimestamp: /* query from repo */,
                    occurredAt: Date()
                ))
            }
        }

        // 5. Publish event + dispatch to Unit 3
        eventBus.publish(event)
        dispatcher.dispatch(event: event)
    }
}
```

### NotificationQueryService (shared with Unit 4)

Read-only query service used by Unit 4's presentation layer to fetch notification data.

```swift
final class NotificationQueryService {
    private let repository: NotificationRepository

    func fetchAll() async -> [Notification] {
        await repository.findAll(sortedBy: .mostRecent)
    }

    func fetchById(_ id: NotificationId) async -> Notification? {
        await repository.findById(id)
    }

    func fetchUnreadCount() async -> Int {
        let unread = await repository.findAllUnread()
        return unread.count
    }
}
```

---

## Infrastructure Layer

### SwiftData Persistence

#### SwiftData Model

```swift
// NotificationModel.swift
import SwiftData

@Model
final class NotificationModel {
    @Attribute(.unique) var id: UUID
    var sourceBundleId: String
    var sourceAppName: String
    @Attribute(.externalStorage) var sourceAppIcon: Data?
    var title: String
    var body: String
    var capturedAt: Date
    var fingerprint: String
    var readStatus: String  // "unread" or "read"

    // Indexes for efficient queries
    // Sorted by capturedAt DESC for list display
}
```

#### SwiftDataNotificationRepository

```swift
final class SwiftDataNotificationRepository: NotificationRepository {
    private let modelContext: ModelContext

    func save(_ notification: Notification) async throws {
        let model = NotificationModel(from: notification)
        modelContext.insert(model)
        try modelContext.save()
    }

    func findAll(sortedBy: NotificationSortOrder) async -> [Notification] {
        let descriptor = FetchDescriptor<NotificationModel>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        let models = try? modelContext.fetch(descriptor)
        return (models ?? []).map { $0.toDomain() }
    }

    func pruneOldest(exceeding limit: Int) async throws -> Int {
        let descriptor = FetchDescriptor<NotificationModel>(
            sortBy: [SortDescriptor(\.capturedAt, order: .forward)]
        )
        let all = try modelContext.fetch(descriptor)
        let toPrune = max(0, all.count - limit)
        for model in all.prefix(toPrune) {
            modelContext.delete(model)
        }
        try modelContext.save()
        return toPrune
    }

    // ... remaining operations follow the same pattern
}
```

**Mapping:** `NotificationModel` ↔ `Notification` domain aggregate via `toDomain()` and `init(from:)` extension methods.

### IOSNotificationListenerService

```swift
final class IOSNotificationListenerService: NotificationListenerService {
    private let captureService: NotificationCaptureAppService

    func startListening() {
        // Approach: Notification Service Extension
        // The app uses a UNNotificationServiceExtension to intercept
        // incoming push/local notifications from other apps.
        //
        // Alternative: UNUserNotificationCenter delegate for local observation.
        //
        // When a notification is intercepted:
        //   1. Extract bundleId, title, body, appName, icon
        //   2. Call captureService.handleIncomingNotification(...)
    }

    func stopListening() {
        // Deactivate the listener
    }
}
```

**iOS constraint note:** Capturing notifications from _other_ apps requires special entitlements or a Notification Service Extension approach. The exact mechanism depends on the iOS version and entitlements available. This is an infrastructure concern isolated behind the protocol.

### NotificationDispatcherImpl

```swift
final class NotificationDispatcherImpl: NotificationDispatcher {
    private let eventBus: DomainEventBus

    func dispatch(event: NotificationCaptured) {
        // The event is already published on the eventBus by the capture service.
        // Unit 3 subscribes to NotificationCaptured on the same bus.
        // This dispatcher exists for explicit intent — in a multi-process scenario
        // it could use IPC (e.g., Darwin notifications, App Groups shared state).
        //
        // In the single-process case, this is effectively a no-op since the
        // eventBus.publish() in the capture service already reaches Unit 3.
    }
}
```

**Note:** If the Notification Service Extension runs in a separate process, `NotificationDispatcherImpl` would use App Groups + Darwin notifications to signal the main app process. For the single-process case, the shared `DomainEventBus` is sufficient and the dispatcher serves as a documented integration point.

---

## Event Subscription Setup

```swift
// In Unit2Container or app startup
func setupEventSubscriptions() {
    // Subscribe to Unit 1 events to maintain MonitoredAppFilter
    eventBus.subscribe(to: AppMonitoringEnabled.self)
        .sink { [weak filter] event in
            filter?.addApp(bundleId: event.bundleId)
        }
        .store(in: &cancellables)

    eventBus.subscribe(to: AppMonitoringDisabled.self)
        .sink { [weak filter] event in
            filter?.removeApp(bundleId: event.bundleId)
        }
        .store(in: &cancellables)
}
```

---

## Dependency Injection

```swift
final class Unit2Container {
    let eventBus: DomainEventBus  // shared app-wide
    let modelContext: ModelContext  // shared SwiftData context

    // Domain
    lazy var monitoredAppFilter = MonitoredAppFilter(enabledBundleIds: [])
    lazy var appFilterPolicy = AppFilterPolicy(filter: monitoredAppFilter)
    lazy var storageCapPolicy = StorageCapPolicy(maxNotifications: 100)

    // Infrastructure
    lazy var notificationRepo: NotificationRepository = SwiftDataNotificationRepository(modelContext: modelContext)
    lazy var dispatcher: NotificationDispatcher = NotificationDispatcherImpl(eventBus: eventBus)
    lazy var listener: NotificationListenerService = IOSNotificationListenerService(captureService: captureService)

    // Application
    lazy var captureService = NotificationCaptureAppService(
        filter: monitoredAppFilter,
        filterPolicy: appFilterPolicy,
        storageCapPolicy: storageCapPolicy,
        repository: notificationRepo,
        eventBus: eventBus,
        dispatcher: dispatcher
    )

    lazy var queryService = NotificationQueryService(repository: notificationRepo)
}
```

---

## Persistence Strategy Summary

| Data | Store | Rationale |
|------|-------|-----------|
| `Notification` aggregates | SwiftData (`NotificationModel`) | Structured data, needs sorting/filtering/pagination, survives app restarts |
| `MonitoredAppFilter` | In-memory (rebuilt from events/settings) | Derived state, small, changes infrequently |
| `StorageCapPolicy.maxNotifications` | Hardcoded constant (or `UserDefaults` if configurable) | Single value |

---

## Cross-Unit Integration

| Direction | Target | Mechanism |
|-----------|--------|-----------|
| Inbound ← Unit 1 | `MonitoredAppFilter` | Subscribes to `AppMonitoringEnabled` / `AppMonitoringDisabled` on the shared `DomainEventBus` |
| Outbound → Unit 3 | Banner display | Publishes `NotificationCaptured` on the shared `DomainEventBus` |
| Outbound → Unit 4 | Shared repository | Unit 4 reads/writes the same `NotificationRepository` instance (injected from `Unit2Container.notificationRepo`) |

**Data flow:**
```
iOS Notification arrives
  → IOSNotificationListenerService intercepts
    → NotificationCaptureAppService.handleIncomingNotification()
      → AppFilterPolicy.shouldCapture() → YES
      → Notification.capture() → (aggregate, NotificationCaptured event)
      → repository.save()
      → StorageCapPolicy check → prune if needed
      → eventBus.publish(NotificationCaptured)
        → Unit 3 subscriber: show banner (if CarPlay connected)
        → Unit 4 subscriber: refresh list (if list view visible)
```
