# Unit 4: CarPlay Notification Management — Data Binding

## Overview

Unit 4 uses CarPlay `CPTemplate` objects rather than SwiftUI views. Data binding follows an imperative pattern: application services fetch data, template builders render it into `CPListItem`/`CPInformationItem` objects, and Combine subscriptions trigger re-renders.

---

## Data Flow Architecture

```
NotificationRepository (SwiftData)
        │
        ▼
NotificationQueryService (read-only)
        │
        ▼
NotificationListAppService / NotificationDetailAppService
        │
        ├── fetchNotificationList() → [NotificationSummary]
        │         │
        │         ▼
        │   NotificationListTemplateBuilder
        │         │
        │         ├── map to [CPListItem]
        │         └── CPListTemplate.updateSections()
        │
        └── viewNotificationDetail(id:) → NotificationDetail
                  │
                  ▼
            NotificationDetailTemplateBuilder
                  │
                  ├── map to [CPInformationItem]
                  └── CPInformationTemplate(items:)
```

---

## Repository → Template Binding

### Notification List (S4.1)

**Data source:** `NotificationListAppService.fetchNotificationList()`

**Transformation chain:**
```
Notification (aggregate)
  → NotificationSummary.from(notification)  // Domain projection
    → CPListItem mapping                     // Template rendering
```

**CPListItem mapping:**

| NotificationSummary field | CPListItem property | Notes |
|--------------------------|---------------------|-------|
| `title` | `text` | Primary text |
| `sourceAppName` | `detailText` | Secondary text below title |
| `capturedAt` | Appended to `detailText` or accessory | Formatted as relative time |
| `readStatus` | Visual styling | See unread indicator below |
| `notificationId` | `userInfo` dictionary | Stored for tap handler reference |

**Unread indicator binding:**
```swift
let item = CPListItem(text: summary.title, detailText: summary.sourceAppName)

if summary.readStatus == .unread {
    // Option 1: Use a dot image as the accessory
    item.accessoryImage = UIImage(systemName: "circle.fill")
    // Option 2: Prefix title with "● " for text-based indication
}
```

### Notification Detail (S4.2)

**Data source:** `NotificationDetailAppService.viewNotificationDetail(id:)`

**Transformation chain:**
```
Notification (aggregate)
  → AutoMarkAsReadOnViewPolicy applied      // Side effect
  → NotificationDetail.from(notification)   // Domain projection
    → [CPInformationItem] mapping           // Template rendering
```

**CPInformationItem mapping:**

| NotificationDetail field | CPInformationItem | Notes |
|-------------------------|-------------------|-------|
| `sourceAppName` | `title: "From", detail: sourceAppName` | |
| `title` | `title: "Title", detail: title` | |
| `body` | `title: "Message", detail: body` | Full text, system handles wrapping |
| `capturedAt` | `title: "Received", detail: formatted` | RelativeDateTimeFormatter |

---

## Real-Time Update Binding

### Event → List Refresh Pipeline

```
DomainEventBus
  │
  ├── NotificationCaptured ──────┐
  ├── NotificationMarkedAsRead ──┤
  ├── NotificationDismissed ─────┤──→ merge ──→ debounce(300ms)
  ├── AllNotificationsCleared ───┤              │
  └── NotificationsPruned ───────┘              ▼
                                         refreshList()
                                              │
                                              ▼
                                   fetchNotificationList()
                                              │
                                              ▼
                                   CPListTemplate.updateSections()
```

**Implementation:**
```swift
// In CarPlayTemplateManager
listService.observeListChanges()
    .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
    .sink { [weak self] in
        self?.refreshList()
    }
    .store(in: &cancellables)
```

**Why debounce:** Multiple events can fire in rapid succession (e.g., `NotificationCaptured` + `NotificationsPruned` when a notification is captured and the storage cap is exceeded). Debouncing ensures we only re-fetch once.

### What Each Event Changes

| Event | List Effect | Detail Effect |
|-------|------------|--------------|
| `NotificationCaptured` | New item at top | N/A (detail is for a specific item) |
| `NotificationMarkedAsRead` | Remove unread indicator from item | N/A (already showing as read) |
| `NotificationDismissed` | Remove item from list | Pop to list (if viewing dismissed item) |
| `AllNotificationsCleared` | Replace with empty state | Pop to list (empty) |
| `NotificationsPruned` | Remove oldest items from bottom | Pop if viewing pruned item |

---

## State Management

Unit 4 does not use SwiftUI `@Observable` ViewModels. State is managed imperatively:

### CarPlayTemplateManager State

```swift
final class CarPlayTemplateManager {
    private var interfaceController: CPInterfaceController?  // set on connect, nil on disconnect
    private var cancellables = Set<AnyCancellable>()         // Combine subscriptions

    // No observable state — template updates are pushed imperatively
}
```

### NotificationListTemplateBuilder State

```swift
final class NotificationListTemplateBuilder {
    private var listTemplate: CPListTemplate?   // reference to the live template
    private var currentSummaries: [NotificationSummary] = []  // last fetched data

    func refresh() async {
        let summaries = await listService.fetchNotificationList()
        self.currentSummaries = summaries
        let items = summaries.map { mapToListItem($0) }
        let section = CPListSection(items: items)
        listTemplate?.updateSections([section])
    }
}
```

---

## Data Loading Strategy

| Screen | Load Trigger | Data Source | Caching |
|--------|-------------|-------------|---------|
| List (S4.1) | Initial build + event refresh | `NotificationQueryService.fetchAll()` | `currentSummaries` in builder |
| Detail (S4.2) | On push | `NotificationRepository.findById()` | None (always fresh) |
| Clear All (S4.3) | On present | N/A (static template) | N/A |

**Full re-fetch on refresh:** On each list refresh, the entire notification list is re-fetched from SwiftData. This is simpler than incremental updates and performant for the expected data size (max 100 notifications). If performance becomes an issue, incremental updates can be added later.

---

## Thread Safety

| Component | Thread | Notes |
|-----------|--------|-------|
| `CarPlayTemplateManager` | Main thread | CarPlay template updates must happen on main |
| `NotificationListAppService` | Async (background) | Fetches from SwiftData off-main |
| Template updates | `.receive(on: DispatchQueue.main)` | Combine pipeline dispatches to main before updating templates |

```swift
// Ensure template updates are on main thread
listService.observeListChanges()
    .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
    .sink { [weak self] in
        Task { @MainActor in
            await self?.listBuilder.refresh()
        }
    }
    .store(in: &cancellables)
```

---

## Error Handling

| Error | Response |
|-------|---------|
| `findById` returns nil (notification deleted between tap and load) | Do not push detail, silently handle |
| `deleteAll` fails | Log error, list does not change (user can retry) |
| SwiftData fetch fails | Show/keep current list, log error |
| Template push fails (stack limit) | Log, do not crash |
