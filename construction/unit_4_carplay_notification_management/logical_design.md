# Unit 4: CarPlay Notification Management — Logical Design

## Overview

This document translates the Unit 4 domain model into an implementable Swift/iOS architecture. Unit 4 covers the CarPlay screens where drivers browse, inspect, and manage stored notifications: list view, detail view, mark as read, dismiss, and clear all. It is state-driven (CRUD operations) rather than event-driven.

**Note:** This unit operates on the same `Notification` aggregate defined in Unit 2. Unit 2 owns creation/storage; this unit owns read status management and dismissal.

---

## Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Presentation Layer (CarPlay Templates)                 │
│  - NotificationListTemplate (CPListTemplate)            │
│  - NotificationDetailTemplate (CPInformationTemplate)   │
│  - ClearAllConfirmationAlert (CPAlertTemplate)          │
├─────────────────────────────────────────────────────────┤
│  Application Layer (Use Cases / App Services)           │
│  - NotificationListAppService                           │
│  - NotificationDetailAppService                         │
│  - NotificationManagementAppService                     │
├─────────────────────────────────────────────────────────┤
│  Domain Layer (Commands on shared Notification, VOs,    │
│  Events, Policies)                                      │
│  - Notification (shared aggregate — Unit 2)             │
│  - AutoMarkAsReadOnViewPolicy                           │
│  - ClearAllConfirmationPolicy                           │
├─────────────────────────────────────────────────────────┤
│  Infrastructure Layer (shared NotificationRepository)   │
│  - SwiftDataNotificationRepository (from Unit 2)        │
│  - CombineDomainEventBus (shared)                       │
└─────────────────────────────────────────────────────────┘
```

---

## Module Structure

```
NotiJohn/
├── Domain/
│   └── Unit4/
│       ├── ValueObjects/
│       │   ├── NotificationSummary.swift
│       │   └── NotificationDetail.swift
│       ├── Events/
│       │   ├── NotificationMarkedAsRead.swift    ← defined in Unit 2
│       │   ├── NotificationDismissed.swift       ← defined in Unit 2
│       │   └── AllNotificationsCleared.swift      ← defined in Unit 2
│       └── Policies/
│           ├── AutoMarkAsReadOnViewPolicy.swift
│           └── ClearAllConfirmationPolicy.swift
├── Application/
│   └── Unit4/
│       ├── NotificationListAppService.swift
│       ├── NotificationDetailAppService.swift
│       └── NotificationManagementAppService.swift
├── Presentation/
│   └── Unit4/
│       ├── CarPlayTemplateManager.swift
│       ├── NotificationListTemplateBuilder.swift
│       ├── NotificationDetailTemplateBuilder.swift
│       └── ClearAllConfirmationBuilder.swift
└── DI/
    └── Unit4Container.swift
```

**Note:** Unit 4 does not have its own Infrastructure layer for persistence — it reuses `Unit2Container.notificationRepo` and `Unit2Container.queryService`.

---

## Domain Layer

### Shared Aggregate: Notification

Unit 4 invokes these commands on the `Notification` aggregate (defined in Unit 2):

```swift
// Already defined in Domain/Unit2/Aggregates/Notification.swift
extension Notification {
    func markAsRead() -> NotificationMarkedAsRead? {
        guard readStatus == .unread else { return nil }  // idempotent
        readStatus = .read
        return NotificationMarkedAsRead(notificationId: id, occurredAt: Date())
    }

    func dismiss() -> NotificationDismissed {
        return NotificationDismissed(notificationId: id, occurredAt: Date())
    }
}
```

### Value Objects (Projections)

```swift
// NotificationSummary.swift — Read-optimized projection for list display
struct NotificationSummary: Identifiable {
    let notificationId: NotificationId
    let sourceAppName: String
    let title: String
    let capturedAt: Date
    let readStatus: ReadStatus

    var id: NotificationId { notificationId }

    static func from(_ notification: Notification) -> NotificationSummary {
        NotificationSummary(
            notificationId: notification.id,
            sourceAppName: notification.sourceApp.appName,
            title: notification.content.title,
            capturedAt: notification.capturedAt.value,
            readStatus: notification.readStatus
        )
    }
}

// NotificationDetail.swift — Read-optimized projection for detail display
struct NotificationDetail {
    let notificationId: NotificationId
    let sourceAppName: String
    let appIcon: Data?
    let title: String
    let body: String
    let capturedAt: Date
    let readStatus: ReadStatus

    static func from(_ notification: Notification) -> NotificationDetail {
        NotificationDetail(
            notificationId: notification.id,
            sourceAppName: notification.sourceApp.appName,
            appIcon: notification.sourceApp.appIcon,
            title: notification.content.title,
            body: notification.content.body,
            capturedAt: notification.capturedAt.value,
            readStatus: notification.readStatus
        )
    }
}
```

### Policies

#### AutoMarkAsReadOnViewPolicy

```swift
// AutoMarkAsReadOnViewPolicy.swift
struct AutoMarkAsReadOnViewPolicy {
    /// Applied as a side-effect when the user views a notification's detail.
    /// Returns the event if the notification was newly marked as read, nil if already read.
    func apply(to notification: Notification) -> NotificationMarkedAsRead? {
        return notification.markAsRead()
    }
}
```

#### ClearAllConfirmationPolicy

```swift
// ClearAllConfirmationPolicy.swift
// This policy is enforced at the UI layer — the domain service assumes
// confirmation has already been obtained.
// Documented here for completeness; implementation is in the template builder.
enum ClearAllConfirmationPolicy {
    /// The UI must present a confirmation dialog before calling clearAll.
    /// The domain service does NOT check for confirmation.
    static let requiresConfirmation = true
}
```

---

## Application Layer

### NotificationListAppService

Provides data for the notification list view.

```swift
final class NotificationListAppService {
    private let queryService: NotificationQueryService  // from Unit 2
    private let eventBus: DomainEventBus

    /// Load all notifications as summaries for list display.
    func fetchNotificationList() async -> [NotificationSummary] {
        let notifications = await queryService.fetchAll()
        return notifications.map { NotificationSummary.from($0) }
    }

    /// Subscribe to real-time list updates.
    func observeListChanges() -> AnyPublisher<Void, Never> {
        // Merge all events that affect the list
        let captured = eventBus.subscribe(to: NotificationCaptured.self).map { _ in () }
        let read = eventBus.subscribe(to: NotificationMarkedAsRead.self).map { _ in () }
        let dismissed = eventBus.subscribe(to: NotificationDismissed.self).map { _ in () }
        let cleared = eventBus.subscribe(to: AllNotificationsCleared.self).map { _ in () }
        let pruned = eventBus.subscribe(to: NotificationsPruned.self).map { _ in () }

        return Publishers.MergeMany(captured, read, dismissed, cleared, pruned)
            .eraseToAnyPublisher()
    }
}
```

### NotificationDetailAppService

Handles the detail view use case including auto-mark-as-read.

```swift
final class NotificationDetailAppService {
    private let repository: NotificationRepository  // from Unit 2
    private let markAsReadPolicy: AutoMarkAsReadOnViewPolicy
    private let eventBus: DomainEventBus

    /// Load a notification detail and automatically mark as read.
    func viewNotificationDetail(id: NotificationId) async throws -> NotificationDetail {
        guard let notification = await repository.findById(id) else {
            throw NotificationNotFoundError(id: id)
        }

        // Apply AutoMarkAsReadOnViewPolicy
        if let event = markAsReadPolicy.apply(to: notification) {
            try await repository.save(notification)
            eventBus.publish(event)
        }

        return NotificationDetail.from(notification)
    }
}

struct NotificationNotFoundError: Error {
    let id: NotificationId
}
```

### NotificationManagementAppService

Handles mark-as-read, dismiss, and clear-all commands.

```swift
final class NotificationManagementAppService {
    private let repository: NotificationRepository  // from Unit 2
    private let eventBus: DomainEventBus

    /// Mark a single notification as read (from list action).
    func markAsRead(id: NotificationId) async throws {
        guard let notification = await repository.findById(id) else { return }
        if let event = notification.markAsRead() {
            try await repository.save(notification)
            eventBus.publish(event)
        }
    }

    /// Dismiss (permanently delete) a single notification.
    func dismiss(id: NotificationId) async throws {
        guard let notification = await repository.findById(id) else { return }
        let event = notification.dismiss()
        try await repository.delete(id)
        eventBus.publish(event)
    }

    /// Clear all notifications. Assumes UI confirmation has already been obtained.
    func clearAll() async throws {
        let count = await repository.count()
        guard count > 0 else { return }
        let deletedCount = try await repository.deleteAll()
        eventBus.publish(AllNotificationsCleared(clearedCount: deletedCount, occurredAt: Date()))
    }
}
```

---

## Presentation Layer (CarPlay Templates)

### CarPlayTemplateManager

Coordinates the CarPlay template stack for Unit 4. Manages the `CPInterfaceController` push/pop.

```swift
final class CarPlayTemplateManager {
    private var interfaceController: CPInterfaceController?
    private let listBuilder: NotificationListTemplateBuilder
    private let detailBuilder: NotificationDetailTemplateBuilder
    private let clearAllBuilder: ClearAllConfirmationBuilder

    private var cancellables = Set<AnyCancellable>()

    func setup(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        let rootTemplate = listBuilder.build()
        interfaceController.setRootTemplate(rootTemplate, animated: false)
        observeListChanges()
    }

    private func observeListChanges() {
        listBuilder.observeChanges()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.refreshList()
            }
            .store(in: &cancellables)
    }

    func refreshList() {
        Task {
            await listBuilder.refresh()
        }
    }

    func pushDetail(for notificationId: NotificationId) {
        Task {
            if let template = await detailBuilder.build(for: notificationId) {
                interfaceController?.pushTemplate(template, animated: true)
            }
        }
    }

    func showClearAllConfirmation() {
        let alert = clearAllBuilder.build()
        interfaceController?.presentTemplate(alert, animated: true)
    }
}
```

### NotificationListTemplateBuilder

Builds and manages the `CPListTemplate` for the notification list.

```swift
final class NotificationListTemplateBuilder {
    private let listService: NotificationListAppService
    private let managementService: NotificationManagementAppService
    private weak var templateManager: CarPlayTemplateManager?

    private var listTemplate: CPListTemplate?

    func build() -> CPListTemplate {
        let template = CPListTemplate(title: "Notifications", sections: [])
        // Add "Clear All" bar button
        template.trailingNavigationBarButtons = [
            CPBarButton(title: "Clear All") { [weak self] _ in
                self?.templateManager?.showClearAllConfirmation()
            }
        ]
        self.listTemplate = template
        Task { await refresh() }
        return template
    }

    func refresh() async {
        let summaries = await listService.fetchNotificationList()
        let items = summaries.map { summary -> CPListItem in
            let item = CPListItem(
                text: summary.title,
                detailText: summary.sourceAppName
            )
            // Visual distinction for unread
            if summary.readStatus == .unread {
                // Bold text or accessory indicator for unread state
                // CPListItem supports .isEnabled and image accessories
            }
            item.handler = { [weak self] _, completion in
                self?.templateManager?.pushDetail(for: summary.notificationId)
                completion()
            }
            return item
        }
        let section = CPListSection(items: items)
        listTemplate?.updateSections([section])
    }

    func observeChanges() -> AnyPublisher<Void, Never> {
        listService.observeListChanges()
    }
}
```

### NotificationDetailTemplateBuilder

Builds the `CPInformationTemplate` for notification detail.

```swift
final class NotificationDetailTemplateBuilder {
    private let detailService: NotificationDetailAppService

    func build(for notificationId: NotificationId) async -> CPInformationTemplate? {
        guard let detail = try? await detailService.viewNotificationDetail(id: notificationId) else {
            return nil
        }

        let items: [CPInformationItem] = [
            CPInformationItem(title: "From", detail: detail.sourceAppName),
            CPInformationItem(title: "Title", detail: detail.title),
            CPInformationItem(title: "Message", detail: detail.body),
            CPInformationItem(title: "Received", detail: Self.formatDate(detail.capturedAt)),
        ]

        let template = CPInformationTemplate(
            title: detail.title,
            layout: .leading,
            items: items,
            actions: []
        )

        return template
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
```

### ClearAllConfirmationBuilder

Builds the `CPAlertTemplate` for clear-all confirmation.

```swift
final class ClearAllConfirmationBuilder {
    private let managementService: NotificationManagementAppService

    func build() -> CPAlertTemplate {
        let confirmAction = CPAlertAction(title: "Clear All", style: .destructive) { [weak self] _ in
            Task {
                try? await self?.managementService.clearAll()
            }
        }

        let cancelAction = CPAlertAction(title: "Cancel", style: .cancel) { _ in
            // Dismiss happens automatically
        }

        return CPAlertTemplate(
            titleVariants: ["Clear all notifications?"],
            actions: [confirmAction, cancelAction]
        )
    }
}
```

---

## Dependency Injection

```swift
final class Unit4Container {
    let eventBus: DomainEventBus          // shared app-wide
    let repository: NotificationRepository // from Unit2Container
    let queryService: NotificationQueryService // from Unit2Container

    // Policies
    lazy var markAsReadPolicy = AutoMarkAsReadOnViewPolicy()

    // Application services
    lazy var listService = NotificationListAppService(
        queryService: queryService,
        eventBus: eventBus
    )
    lazy var detailService = NotificationDetailAppService(
        repository: repository,
        markAsReadPolicy: markAsReadPolicy,
        eventBus: eventBus
    )
    lazy var managementService = NotificationManagementAppService(
        repository: repository,
        eventBus: eventBus
    )

    // Presentation
    lazy var listBuilder = NotificationListTemplateBuilder(
        listService: listService,
        managementService: managementService
    )
    lazy var detailBuilder = NotificationDetailTemplateBuilder(detailService: detailService)
    lazy var clearAllBuilder = ClearAllConfirmationBuilder(managementService: managementService)

    lazy var templateManager: CarPlayTemplateManager = {
        let manager = CarPlayTemplateManager(
            listBuilder: listBuilder,
            detailBuilder: detailBuilder,
            clearAllBuilder: clearAllBuilder
        )
        listBuilder.templateManager = manager
        return manager
    }()
}
```

---

## Persistence Strategy Summary

| Data | Store | Rationale |
|------|-------|-----------|
| `Notification` aggregates | SwiftData (shared with Unit 2) | Same repository instance — Unit 2 writes, Unit 4 reads and updates |

No additional persistence beyond what Unit 2 provides.

---

## CarPlay Template Navigation Flow

```
CarPlay Connected (via Unit 3 CarPlaySceneDelegate)
  │
  └── Root: CPListTemplate (Notification List)
        │   - Shows all notifications, most recent first
        │   - Unread indicators (bold / dot)
        │   - "Clear All" button in navigation bar
        │
        ├── Tap item → Push: CPInformationTemplate (Detail)
        │     - Shows full notification content
        │     - Auto-marks as read (side effect)
        │     - Back button returns to list
        │
        └── Tap "Clear All" → Present: CPAlertTemplate (Confirmation)
              - "Clear all notifications?"
              - [Clear All (destructive)] / [Cancel]
              - On confirm → deleteAll → list refreshes to empty
```

---

## Cross-Unit Integration

| Direction | Target | Mechanism |
|-----------|--------|-----------|
| Inbound ← Unit 2 | Shared `NotificationRepository` | Same instance injected from `Unit2Container`. Unit 4 reads with `findAll`/`findById`, writes with `save`/`delete`/`deleteAll`. |
| Inbound ← Unit 2 | Real-time updates | Subscribes to `NotificationCaptured` on `DomainEventBus` to refresh the list when new notifications arrive. |
| Sibling ↔ Unit 3 | CarPlay template coordination | Unit 3 owns the `CarPlaySceneDelegate` and calls `Unit4Container.templateManager.setup(interfaceController:)` on connect. Unit 4 provides the root template. |

**Use case flows:**

```
View List (US-4.1, US-4.3):
  CarPlay connected
    → templateManager.setup() → listBuilder.build()
      → listService.fetchNotificationList()
        → queryService.fetchAll() → repository.findAll()
      → map to NotificationSummary[]
      → render CPListTemplate with unread indicators

View Detail (US-4.2):
  Tap list item
    → templateManager.pushDetail(id)
      → detailService.viewNotificationDetail(id)
        → repository.findById(id)
        → markAsReadPolicy.apply() → notification.markAsRead()
        → repository.save() → eventBus.publish(NotificationMarkedAsRead)
      → build CPInformationTemplate → push

Dismiss (US-4.5):
  Swipe/action on list item
    → managementService.dismiss(id)
      → notification.dismiss() → repository.delete(id)
      → eventBus.publish(NotificationDismissed)
    → list refreshes (via observeListChanges subscription)

Clear All (US-4.6):
  Tap "Clear All" → CPAlertTemplate → Confirm
    → managementService.clearAll()
      → repository.deleteAll()
      → eventBus.publish(AllNotificationsCleared)
    → list refreshes to empty
```
