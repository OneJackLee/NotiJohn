# Unit 3: CarPlay Presentation — Logical Design

## Overview

This document translates the Unit 3 domain model into an implementable Swift/iOS architecture. Unit 3 handles the real-time CarPlay experience: displaying incoming notification banners, suppressing duplicate banner displays, and managing the CarPlay connection lifecycle.

**Scope change:** TTS (text-to-speech) has been removed from scope. All TTS-related components (`AnnouncementQueue`, `PendingAnnouncement`, `TTSUtterance`, `TTSService`, `NavigationGuidanceRespectPolicy`) are excluded from this design. The `DuplicateSuppressionPolicy` is retained for banner suppression.

---

## Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Presentation Layer (CarPlay Scene Delegate)            │
│  - CarPlaySceneDelegate                                 │
│  - Banner rendering (via CarPlay system notifications)  │
├─────────────────────────────────────────────────────────┤
│  Application Layer (Use Cases / App Services)           │
│  - CarPlaySessionAppService                             │
│  - BannerAppService                                     │
├─────────────────────────────────────────────────────────┤
│  Domain Layer (Aggregates, VOs, Events, Policies)       │
│  - CarPlaySession                                       │
│  - DuplicateSuppressionPolicy                           │
├─────────────────────────────────────────────────────────┤
│  Infrastructure Layer (CarPlay Framework, Event Bus)    │
│  - CarPlaySceneLifecycleAdapter                         │
│  - CarPlayBannerPresentationService                     │
│  - InMemoryRecentAnnouncementLog                        │
│  - CombineDomainEventBus (shared)                       │
└─────────────────────────────────────────────────────────┘
```

---

## Module Structure

```
NotiJohn/
├── Domain/
│   └── Unit3/
│       ├── Aggregates/
│       │   └── CarPlaySession.swift
│       ├── ValueObjects/
│       │   ├── SessionId.swift
│       │   ├── ConnectionState.swift
│       │   ├── NotificationBanner.swift
│       │   ├── BannerDuration.swift
│       │   └── DuplicateWindow.swift
│       ├── Events/
│       │   ├── CarPlaySessionStarted.swift
│       │   ├── CarPlaySessionEnded.swift
│       │   ├── BannerDisplayed.swift
│       │   ├── BannerAutoDismissed.swift
│       │   └── DuplicateNotificationSuppressed.swift
│       ├── Policies/
│       │   └── DuplicateSuppressionPolicy.swift
│       └── Protocols/
│           ├── BannerPresentationService.swift
│           └── RecentAnnouncementLog.swift
├── Application/
│   └── Unit3/
│       ├── CarPlaySessionAppService.swift
│       ├── BannerAppService.swift
│       └── IncomingNotificationHandler.swift
├── Infrastructure/
│   └── Unit3/
│       ├── CarPlaySceneLifecycleAdapter.swift
│       ├── CarPlayBannerPresentationService.swift
│       └── InMemoryRecentAnnouncementLog.swift
├── Presentation/
│   └── Unit3/
│       └── CarPlaySceneDelegate.swift
└── DI/
    └── Unit3Container.swift
```

---

## Domain Layer

### Aggregate: CarPlaySession

```swift
// CarPlaySession.swift
final class CarPlaySession {
    let id: SessionId
    private(set) var connectionState: ConnectionState
    private(set) var connectedAt: Date?
    private(set) var disconnectedAt: Date?

    init() {
        self.id = SessionId()
        self.connectionState = .disconnected
    }

    // Commands
    func start() -> CarPlaySessionStarted {
        connectionState = .connected
        connectedAt = Date()
        disconnectedAt = nil
        return CarPlaySessionStarted(sessionId: id, connectedAt: connectedAt!, occurredAt: Date())
    }

    func end() -> CarPlaySessionEnded {
        connectionState = .disconnected
        disconnectedAt = Date()
        return CarPlaySessionEnded(sessionId: id, disconnectedAt: disconnectedAt!, occurredAt: Date())
    }

    var isConnected: Bool { connectionState == .connected }
}
```

**Implementation notes:**
- Singleton per app lifecycle — only one `CarPlaySession` instance at a time.
- `start()` creates a new `SessionId` (or reuses the instance). Previous session data is overwritten.
- No persistence needed — session state is transient and tied to the OS CarPlay connection.

### Value Objects

```swift
struct SessionId: Hashable {
    let value: UUID
    init() { self.value = UUID() }
}

enum ConnectionState: String {
    case connected
    case disconnected
}

struct NotificationBanner {
    let notificationId: NotificationId
    let sourceAppName: String
    let title: String
    let bodyPreview: String
    let displayDuration: BannerDuration

    /// Factory: create from a NotificationCaptured event
    static func from(event: NotificationCaptured, duration: BannerDuration = .default) -> NotificationBanner {
        NotificationBanner(
            notificationId: event.notificationId,
            sourceAppName: event.sourceApp.appName,
            title: event.content.title,
            bodyPreview: String(event.content.body.prefix(100)),
            displayDuration: duration
        )
    }
}

struct BannerDuration {
    let seconds: TimeInterval
    static let `default` = BannerDuration(seconds: 5)

    init(seconds: TimeInterval) {
        precondition(seconds > 0, "Banner duration must be positive")
        self.seconds = seconds
    }
}

struct DuplicateWindow {
    let seconds: TimeInterval
    static let `default` = DuplicateWindow(seconds: 30)

    init(seconds: TimeInterval) {
        precondition(seconds > 0, "Duplicate window must be positive")
        self.seconds = seconds
    }
}
```

### Domain Events

```swift
struct CarPlaySessionStarted: DomainEvent {
    let sessionId: SessionId
    let connectedAt: Date
    let occurredAt: Date
}

struct CarPlaySessionEnded: DomainEvent {
    let sessionId: SessionId
    let disconnectedAt: Date
    let occurredAt: Date
}

struct BannerDisplayed: DomainEvent {
    let notificationId: NotificationId
    let occurredAt: Date
}

struct BannerAutoDismissed: DomainEvent {
    let notificationId: NotificationId
    let occurredAt: Date
}

struct DuplicateNotificationSuppressed: DomainEvent {
    let notificationId: NotificationId
    let fingerprint: NotificationFingerprint
    let occurredAt: Date
}
```

### Policies

#### DuplicateSuppressionPolicy

```swift
// DuplicateSuppressionPolicy.swift
struct DuplicateSuppressionPolicy {
    private let recentLog: RecentAnnouncementLog
    private let window: DuplicateWindow

    /// Returns true if this fingerprint has already been displayed within the window.
    func isDuplicate(fingerprint: NotificationFingerprint, at timestamp: Date) -> Bool {
        recentLog.hasBeenAnnounced(fingerprint: fingerprint, within: window)
    }

    /// Record that this fingerprint was displayed.
    func recordDisplay(fingerprint: NotificationFingerprint, at timestamp: Date) {
        recentLog.record(fingerprint: fingerprint, at: timestamp)
    }
}
```

### Repository/Store Protocols

```swift
protocol RecentAnnouncementLog {
    func record(fingerprint: NotificationFingerprint, at timestamp: Date)
    func hasBeenAnnounced(fingerprint: NotificationFingerprint, within window: DuplicateWindow) -> Bool
    func purgeExpired(window: DuplicateWindow)
}

protocol BannerPresentationService {
    func show(banner: NotificationBanner) async
    func dismiss(notificationId: NotificationId) async
}
```

---

## Application Layer

### IncomingNotificationHandler

The central orchestrator: responds to `NotificationCaptured` events from Unit 2.

```swift
final class IncomingNotificationHandler {
    private let session: CarPlaySession
    private let duplicatePolicy: DuplicateSuppressionPolicy
    private let bannerService: BannerPresentationService
    private let eventBus: DomainEventBus

    /// Called when a NotificationCaptured event is received from Unit 2.
    func handle(event: NotificationCaptured) async {
        // 1. Check CarPlay connection
        guard session.isConnected else { return }

        // 2. Check duplicate suppression
        let now = Date()
        if duplicatePolicy.isDuplicate(fingerprint: event.fingerprint, at: now) {
            eventBus.publish(DuplicateNotificationSuppressed(
                notificationId: event.notificationId,
                fingerprint: event.fingerprint,
                occurredAt: now
            ))
            return
        }

        // 3. Display banner
        let banner = NotificationBanner.from(event: event)
        await bannerService.show(banner: banner)

        // 4. Record for duplicate suppression
        duplicatePolicy.recordDisplay(fingerprint: event.fingerprint, at: now)

        // 5. Emit banner displayed event
        eventBus.publish(BannerDisplayed(notificationId: event.notificationId, occurredAt: now))
    }
}
```

### CarPlaySessionAppService

Manages the CarPlay session lifecycle.

```swift
final class CarPlaySessionAppService {
    private let session: CarPlaySession
    private let eventBus: DomainEventBus
    private let bannerService: BannerPresentationService

    func onCarPlayConnect() {
        let event = session.start()
        eventBus.publish(event)
    }

    func onCarPlayDisconnect() {
        let event = session.end()
        eventBus.publish(event)
        // Disconnect cleanup: no pending banners matter anymore
    }
}
```

### BannerAppService

Manages banner auto-dismiss scheduling.

```swift
final class BannerAppService {
    private let bannerService: BannerPresentationService
    private let eventBus: DomainEventBus

    func scheduleBannerDismissal(notificationId: NotificationId, after duration: BannerDuration) {
        Task {
            try await Task.sleep(for: .seconds(duration.seconds))
            await bannerService.dismiss(notificationId: notificationId)
            eventBus.publish(BannerAutoDismissed(notificationId: notificationId, occurredAt: Date()))
        }
    }
}
```

---

## Infrastructure Layer

### CarPlaySceneLifecycleAdapter

Bridges the CarPlay framework's `CPTemplateApplicationSceneDelegate` to the domain.

```swift
final class CarPlaySceneLifecycleAdapter: NSObject {
    private let sessionService: CarPlaySessionAppService

    // Called by CarPlaySceneDelegate
    func didConnect(interfaceController: CPInterfaceController, window: CPWindow) {
        sessionService.onCarPlayConnect()
    }

    func didDisconnect(interfaceController: CPInterfaceController) {
        sessionService.onCarPlayDisconnect()
    }
}
```

### CarPlayBannerPresentationService

```swift
final class CarPlayBannerPresentationService: BannerPresentationService {

    func show(banner: NotificationBanner) async {
        // CarPlay does not support custom overlay banners.
        // Options:
        // 1. Use UNUserNotificationCenter to post a local notification
        //    that appears on the CarPlay screen as a system notification.
        // 2. Use CPInformationTemplate or CPAlertTemplate as a transient banner.
        //
        // Recommended: Post a local UNNotification styled with the banner data.
        // This leverages the native CarPlay notification UI.
    }

    func dismiss(notificationId: NotificationId) async {
        // Remove the delivered local notification via
        // UNUserNotificationCenter.removeDeliveredNotifications(withIdentifiers:)
    }
}
```

**Implementation approach — Local Notification as Banner:**
```swift
func show(banner: NotificationBanner) async {
    let content = UNMutableNotificationContent()
    content.title = "\(banner.sourceAppName)"
    content.subtitle = banner.title
    content.body = banner.bodyPreview
    content.categoryIdentifier = "NOTIJOHN_BANNER"

    let request = UNNotificationRequest(
        identifier: banner.notificationId.value.uuidString,
        content: content,
        trigger: nil  // immediate delivery
    )
    try? await UNUserNotificationCenter.current().add(request)
}
```

### InMemoryRecentAnnouncementLog

```swift
final class InMemoryRecentAnnouncementLog: RecentAnnouncementLog {
    private var entries: [NotificationFingerprint: Date] = [:]

    func record(fingerprint: NotificationFingerprint, at timestamp: Date) {
        entries[fingerprint] = timestamp
    }

    func hasBeenAnnounced(fingerprint: NotificationFingerprint, within window: DuplicateWindow) -> Bool {
        guard let lastSeen = entries[fingerprint] else { return false }
        return Date().timeIntervalSince(lastSeen) <= window.seconds
    }

    func purgeExpired(window: DuplicateWindow) {
        let cutoff = Date().addingTimeInterval(-window.seconds)
        entries = entries.filter { $0.value > cutoff }
    }
}
```

**Note:** In-memory only. Cleared on app restart. Periodic `purgeExpired()` called by a background timer or on each `record` call to prevent unbounded growth.

---

## Presentation Layer

### CarPlaySceneDelegate

```swift
// CarPlaySceneDelegate.swift
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private let lifecycleAdapter: CarPlaySceneLifecycleAdapter  // injected via DI

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        lifecycleAdapter.didConnect(interfaceController: interfaceController, window: window)

        // Set up root template (Unit 4's notification list)
        // Unit 3 does not own any persistent CarPlay template — it only shows transient banners.
        // The root template is provided by Unit 4.
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        lifecycleAdapter.didDisconnect(interfaceController: interfaceController)
        self.interfaceController = nil
    }
}
```

**Note:** The `CarPlaySceneDelegate` is the single entry point for CarPlay. It coordinates both Unit 3 (banners/lifecycle) and Unit 4 (list templates). The root template stack is owned by Unit 4; Unit 3 only pushes transient banner notifications.

---

## Event Subscription Setup

```swift
func setupEventSubscriptions() {
    // Subscribe to NotificationCaptured from Unit 2
    eventBus.subscribe(to: NotificationCaptured.self)
        .sink { [weak handler] event in
            Task { await handler?.handle(event: event) }
        }
        .store(in: &cancellables)

    // Periodic purge of expired duplicate entries
    Timer.publish(every: 60, on: .main, in: .common)
        .autoconnect()
        .sink { [weak recentLog, window] _ in
            recentLog?.purgeExpired(window: window)
        }
        .store(in: &cancellables)
}
```

---

## Dependency Injection

```swift
final class Unit3Container {
    let eventBus: DomainEventBus  // shared app-wide

    // Domain
    lazy var session = CarPlaySession()
    lazy var duplicateWindow = DuplicateWindow.default
    lazy var recentLog: RecentAnnouncementLog = InMemoryRecentAnnouncementLog()
    lazy var duplicatePolicy = DuplicateSuppressionPolicy(recentLog: recentLog, window: duplicateWindow)

    // Infrastructure
    lazy var bannerService: BannerPresentationService = CarPlayBannerPresentationService()

    // Application
    lazy var sessionService = CarPlaySessionAppService(
        session: session,
        eventBus: eventBus,
        bannerService: bannerService
    )
    lazy var bannerAppService = BannerAppService(
        bannerService: bannerService,
        eventBus: eventBus
    )
    lazy var incomingHandler = IncomingNotificationHandler(
        session: session,
        duplicatePolicy: duplicatePolicy,
        bannerService: bannerService,
        eventBus: eventBus
    )

    // Presentation
    lazy var lifecycleAdapter = CarPlaySceneLifecycleAdapter(sessionService: sessionService)
}
```

---

## Persistence Strategy Summary

| Data | Store | Rationale |
|------|-------|-----------|
| `CarPlaySession` | In-memory only | Transient — tied to OS connection lifecycle |
| `RecentAnnouncementLog` | In-memory dictionary | Short-lived cache, no need to survive restart |

No persistent storage needed for Unit 3.

---

## Cross-Unit Integration

| Direction | Target | Mechanism |
|-----------|--------|-----------|
| Inbound ← Unit 2 | `IncomingNotificationHandler` | Subscribes to `NotificationCaptured` on the shared `DomainEventBus` |
| Sibling ↔ Unit 4 | CarPlay template stack | Unit 3 owns the `CarPlaySceneDelegate` and session lifecycle; Unit 4 provides the root `CPListTemplate`. Coordinated via the app-level DI container. |

**Event flow:**
```
NotificationCaptured (from Unit 2, via DomainEventBus)
  → IncomingNotificationHandler.handle()
    → session.isConnected? → YES
    → duplicatePolicy.isDuplicate()? → NO
    → NotificationBanner.from(event)
    → bannerService.show(banner)
    → duplicatePolicy.recordDisplay()
    → eventBus.publish(BannerDisplayed)
    → bannerAppService.scheduleBannerDismissal()
      → (after 5s) bannerService.dismiss()
      → eventBus.publish(BannerAutoDismissed)
```
