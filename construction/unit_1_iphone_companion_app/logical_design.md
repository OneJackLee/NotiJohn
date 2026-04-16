# Unit 1: iPhone Companion App — Logical Design

## Overview

This document translates the Unit 1 domain model into an implementable Swift/iOS architecture. Unit 1 is the iPhone-side experience: first-launch onboarding, notification permission acquisition, and app-selection settings. It has no notification list — only configuration and setup screens, built with SwiftUI.

---

## Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Presentation Layer (SwiftUI Views + ViewModels)        │
│  - OnboardingView, AppSelectionView, SettingsView       │
│  - OnboardingViewModel, AppSelectionViewModel           │
├─────────────────────────────────────────────────────────┤
│  Application Layer (Use Cases / App Services)           │
│  - OnboardingService, AppMonitoringService              │
├─────────────────────────────────────────────────────────┤
│  Domain Layer (Aggregates, VOs, Events, Policies)       │
│  - MonitoredAppSettings, OnboardingProgress             │
│  - Domain Events, ImmediateEffectPolicy                 │
├─────────────────────────────────────────────────────────┤
│  Infrastructure Layer (Persistence, OS APIs)            │
│  - UserDefaultsSettingsRepository                       │
│  - UserDefaultsOnboardingRepository                     │
│  - IOSAppDiscoveryService                               │
│  - IOSNotificationPermissionService                     │
│  - CombineDomainEventBus                                │
└─────────────────────────────────────────────────────────┘
```

---

## Module Structure

```
NotiJohn/
├── Domain/
│   ├── Unit1/
│   │   ├── Aggregates/
│   │   │   ├── MonitoredAppSettings.swift
│   │   │   └── OnboardingProgress.swift
│   │   ├── Entities/
│   │   │   └── MonitoredApp.swift
│   │   ├── ValueObjects/
│   │   │   ├── BundleIdentifier.swift        ← shared across units
│   │   │   ├── AppInfo.swift
│   │   │   ├── OnboardingStep.swift
│   │   │   └── PermissionStatus.swift
│   │   ├── Events/
│   │   │   ├── AppMonitoringEnabled.swift
│   │   │   ├── AppMonitoringDisabled.swift
│   │   │   ├── OnboardingStepCompleted.swift
│   │   │   ├── OnboardingStepSkipped.swift
│   │   │   ├── OnboardingCompleted.swift
│   │   │   └── NotificationPermissionChanged.swift
│   │   └── Protocols/
│   │       ├── MonitoredAppSettingsRepository.swift
│   │       ├── OnboardingProgressRepository.swift
│   │       ├── InstalledAppDiscoveryService.swift
│   │       └── NotificationPermissionService.swift
│   └── Shared/
│       ├── DomainEvent.swift                 ← base protocol
│       └── DomainEventBus.swift              ← event bus protocol
├── Application/
│   └── Unit1/
│       ├── OnboardingAppService.swift
│       └── AppMonitoringAppService.swift
├── Infrastructure/
│   └── Unit1/
│       ├── UserDefaultsSettingsRepository.swift
│       ├── UserDefaultsOnboardingRepository.swift
│       ├── IOSAppDiscoveryService.swift
│       └── IOSNotificationPermissionService.swift
├── Presentation/
│   └── Unit1/
│       ├── ViewModels/
│       │   ├── OnboardingViewModel.swift
│       │   └── AppSelectionViewModel.swift
│       └── Views/
│           ├── OnboardingView.swift
│           ├── WelcomeStepView.swift
│           ├── PermissionStepView.swift
│           ├── AppSelectionStepView.swift
│           ├── CompletionStepView.swift
│           └── SettingsView.swift
└── DI/
    └── Unit1Container.swift
```

---

## Domain Layer

### Aggregate: MonitoredAppSettings

```swift
// MonitoredAppSettings.swift
final class MonitoredAppSettings {
    let id: SettingsId
    private(set) var monitoredApps: [MonitoredApp]

    // Commands
    func enableApp(appInfo: AppInfo) -> AppMonitoringEnabled
    func disableApp(bundleId: BundleIdentifier) -> AppMonitoringDisabled
    func syncInstalledApps(installed: [AppInfo]) -> [DomainEvent]
}
```

**Implementation notes:**
- `MonitoredAppSettings` is a reference type (`class`) because it's an aggregate root with identity and mutable state.
- `SettingsId` is a singleton — hardcoded or generated once per device.
- Commands return domain events directly. The application service is responsible for publishing them to the event bus.
- `syncInstalledApps` may return multiple `AppMonitoringDisabled` events for uninstalled apps.

### Aggregate: OnboardingProgress

```swift
// OnboardingProgress.swift
final class OnboardingProgress {
    let id: OnboardingId
    private(set) var currentStep: OnboardingStep
    private(set) var completedSteps: Set<OnboardingStep>
    private(set) var skippedSteps: Set<OnboardingStep>
    private(set) var isComplete: Bool

    // Commands
    func completeStep(_ step: OnboardingStep) throws -> OnboardingStepCompleted
    func skipStep(_ step: OnboardingStep) throws -> OnboardingStepSkipped
    func finish() throws -> OnboardingCompleted
}
```

**Implementation notes:**
- `completeStep` and `skipStep` throw if the step is not the `currentStep` or if it's already been completed/skipped.
- `finish()` throws if `currentStep != .completion`.
- Step progression order is enforced: `welcome → permissionRequest → appSelection → completion`.

### Entity: MonitoredApp

```swift
// MonitoredApp.swift
struct MonitoredApp: Identifiable {
    let bundleId: BundleIdentifier   // identity within aggregate
    var appInfo: AppInfo
    var isEnabled: Bool

    var id: BundleIdentifier { bundleId }
}
```

**Implementation notes:**
- `MonitoredApp` is a `struct` (value semantics) since it lives inside the aggregate and is identified by `bundleId`.
- Marked `Identifiable` for SwiftUI list rendering.

### Value Objects

All value objects are implemented as `struct` with `Equatable` and `Hashable` conformance:

```swift
struct BundleIdentifier: Hashable, Codable {
    let value: String

    init?(_ value: String) {
        guard !value.isEmpty else { return nil }
        // Optional: validate reverse-DNS format
        self.value = value
    }
}

struct AppInfo: Hashable {
    let bundleId: BundleIdentifier
    let displayName: String
    let iconData: Data?
}

enum OnboardingStep: String, CaseIterable, Codable, Comparable {
    case welcome
    case permissionRequest
    case appSelection
    case completion

    var isSkippable: Bool {
        switch self {
        case .appSelection: return true
        default: return false
        }
    }
}

enum PermissionStatus: String, Codable {
    case notDetermined
    case granted
    case denied
}
```

### Domain Events

```swift
// Base protocol (shared)
protocol DomainEvent {
    var occurredAt: Date { get }
}

struct AppMonitoringEnabled: DomainEvent {
    let bundleId: BundleIdentifier
    let appName: String
    let occurredAt: Date
}

struct AppMonitoringDisabled: DomainEvent {
    let bundleId: BundleIdentifier
    let occurredAt: Date
}

struct OnboardingStepCompleted: DomainEvent {
    let step: OnboardingStep
    let occurredAt: Date
}

struct OnboardingStepSkipped: DomainEvent {
    let step: OnboardingStep
    let occurredAt: Date
}

struct OnboardingCompleted: DomainEvent {
    let occurredAt: Date
}

struct NotificationPermissionChanged: DomainEvent {
    let newStatus: PermissionStatus
    let occurredAt: Date
}
```

### Repository Protocols

```swift
protocol MonitoredAppSettingsRepository {
    func get() async -> MonitoredAppSettings
    func save(_ settings: MonitoredAppSettings) async throws
}

protocol OnboardingProgressRepository {
    func get() async -> OnboardingProgress
    func save(_ progress: OnboardingProgress) async throws
}
```

### Domain Service Protocols

```swift
protocol InstalledAppDiscoveryService {
    func discoverApps() async -> [AppInfo]
}

protocol NotificationPermissionService {
    func requestPermission() async -> PermissionStatus
    func checkCurrentStatus() async -> PermissionStatus
}
```

---

## Domain Event Bus

```swift
// DomainEventBus.swift (shared infrastructure)
protocol DomainEventBus {
    func publish(_ event: DomainEvent)
    func subscribe<T: DomainEvent>(to eventType: T.Type) -> AnyPublisher<T, Never>
}
```

**Implementation:** `CombineDomainEventBus` using a `PassthroughSubject<DomainEvent, Never>` with type-filtered subscriptions via `compactMap`.

```swift
final class CombineDomainEventBus: DomainEventBus {
    private let subject = PassthroughSubject<DomainEvent, Never>()

    func publish(_ event: DomainEvent) {
        subject.send(event)
    }

    func subscribe<T: DomainEvent>(to eventType: T.Type) -> AnyPublisher<T, Never> {
        subject.compactMap { $0 as? T }.eraseToAnyPublisher()
    }
}
```

**Cross-unit integration:** The same `CombineDomainEventBus` instance is shared across all units via the DI container. Unit 1 publishes `AppMonitoringEnabled`/`AppMonitoringDisabled`; Unit 2 subscribes.

---

## Application Layer

### AppMonitoringAppService

Orchestrates the app selection use cases. Mediates between the presentation layer and the domain.

```swift
final class AppMonitoringAppService {
    private let settingsRepo: MonitoredAppSettingsRepository
    private let discoveryService: InstalledAppDiscoveryService
    private let eventBus: DomainEventBus

    // Use cases
    func loadInstalledApps() async -> [AppInfo]
    func loadSettings() async -> MonitoredAppSettings
    func enableApp(_ appInfo: AppInfo) async throws
    func disableApp(_ bundleId: BundleIdentifier) async throws
    func syncWithInstalledApps() async throws
}
```

**Behavior:**
- `enableApp` / `disableApp`: Load settings → execute command on aggregate → save → publish domain event.
- `syncWithInstalledApps`: Discover installed apps → call `syncInstalledApps()` on aggregate → save → publish events for any removed apps.

### OnboardingAppService

Orchestrates the onboarding flow.

```swift
final class OnboardingAppService {
    private let onboardingRepo: OnboardingProgressRepository
    private let permissionService: NotificationPermissionService
    private let eventBus: DomainEventBus

    // Use cases
    func loadProgress() async -> OnboardingProgress
    func completeStep(_ step: OnboardingStep) async throws
    func skipStep(_ step: OnboardingStep) async throws
    func requestNotificationPermission() async -> PermissionStatus
    func finishOnboarding() async throws
    func isOnboardingComplete() async -> Bool
}
```

**Behavior:**
- `completeStep` / `skipStep`: Load progress → execute command → save → publish event.
- `requestNotificationPermission`: Delegates to `NotificationPermissionService`, publishes `NotificationPermissionChanged`.
- `isOnboardingComplete`: Used at app launch to decide whether to show onboarding or settings.

---

## Infrastructure Layer

### UserDefaultsSettingsRepository

```swift
final class UserDefaultsSettingsRepository: MonitoredAppSettingsRepository {
    private let defaults: UserDefaults
    private let key = "monitored_app_settings"

    func get() async -> MonitoredAppSettings { /* decode from UserDefaults or return empty default */ }
    func save(_ settings: MonitoredAppSettings) async throws { /* encode and persist */ }
}
```

**Serialization:** `MonitoredAppSettings` and its children conform to `Codable`. Stored as JSON data in `UserDefaults`.

### UserDefaultsOnboardingRepository

```swift
final class UserDefaultsOnboardingRepository: OnboardingProgressRepository {
    private let defaults: UserDefaults
    private let key = "onboarding_progress"

    func get() async -> OnboardingProgress { /* decode or return fresh progress */ }
    func save(_ progress: OnboardingProgress) async throws { /* encode and persist */ }
}
```

### IOSAppDiscoveryService

```swift
final class IOSAppDiscoveryService: InstalledAppDiscoveryService {
    func discoverApps() async -> [AppInfo] {
        // Wraps iOS APIs to enumerate installed apps with notification capability
        // Note: iOS does not provide a public API to list installed apps.
        // Implementation approach: use a curated list of common messaging/social apps
        // OR rely on the Notification Service Extension to discover apps dynamically
        // as notifications arrive.
    }
}
```

**Implementation note:** iOS sandboxing restricts app enumeration. Realistic approaches:
1. **Curated default list** of popular apps (WhatsApp, Messages, Telegram, etc.) pre-populated.
2. **Dynamic discovery** via the Notification Service Extension — as notifications arrive from new apps, they are added to the discovered list.
3. Both approaches combined.

### IOSNotificationPermissionService

```swift
final class IOSNotificationPermissionService: NotificationPermissionService {
    func requestPermission() async -> PermissionStatus {
        // Wraps UNUserNotificationCenter.requestAuthorization()
    }

    func checkCurrentStatus() async -> PermissionStatus {
        // Wraps UNUserNotificationCenter.getNotificationSettings()
    }
}
```

---

## Presentation Layer

### ViewModels

ViewModels are `@Observable` classes (Swift 5.9 Observation framework) that expose state for SwiftUI views and delegate actions to application services.

#### OnboardingViewModel

```swift
@Observable
final class OnboardingViewModel {
    private let onboardingService: OnboardingAppService
    private let appMonitoringService: AppMonitoringAppService

    // Published state
    var currentStep: OnboardingStep = .welcome
    var permissionStatus: PermissionStatus = .notDetermined
    var installedApps: [AppInfo] = []
    var isComplete: Bool = false

    // Actions
    func onAppear() async              // Load progress, set currentStep
    func advanceStep() async           // Complete current step, move to next
    func skipCurrentStep() async       // Skip current step
    func requestPermission() async     // Trigger permission prompt
    func finishOnboarding() async      // Finalize
}
```

#### AppSelectionViewModel

```swift
@Observable
final class AppSelectionViewModel {
    private let appMonitoringService: AppMonitoringAppService

    // Published state
    var monitoredApps: [MonitoredApp] = []
    var isLoading: Bool = false

    // Actions
    func onAppear() async              // Load settings + sync with installed
    func toggleApp(_ app: MonitoredApp) async   // Enable or disable
}
```

### View Hierarchy

```
App Launch
  └── if !onboardingComplete → OnboardingView
        ├── WelcomeStepView
        ├── PermissionStepView
        ├── AppSelectionStepView (reuses AppSelectionView components)
        └── CompletionStepView
  └── if onboardingComplete → SettingsView
        └── AppSelectionView (list of apps with toggles)
```

---

## Dependency Injection

```swift
final class Unit1Container {
    // Shared
    let eventBus: DomainEventBus

    // Repositories
    lazy var settingsRepo: MonitoredAppSettingsRepository = UserDefaultsSettingsRepository()
    lazy var onboardingRepo: OnboardingProgressRepository = UserDefaultsOnboardingRepository()

    // Domain services
    lazy var discoveryService: InstalledAppDiscoveryService = IOSAppDiscoveryService()
    lazy var permissionService: NotificationPermissionService = IOSNotificationPermissionService()

    // Application services
    lazy var appMonitoringService = AppMonitoringAppService(
        settingsRepo: settingsRepo,
        discoveryService: discoveryService,
        eventBus: eventBus
    )
    lazy var onboardingService = OnboardingAppService(
        onboardingRepo: onboardingRepo,
        permissionService: permissionService,
        eventBus: eventBus
    )

    // ViewModels (factory — new instance per view)
    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            onboardingService: onboardingService,
            appMonitoringService: appMonitoringService
        )
    }

    func makeAppSelectionViewModel() -> AppSelectionViewModel {
        AppSelectionViewModel(appMonitoringService: appMonitoringService)
    }
}
```

**Note:** `eventBus` is injected from the app-level DI container (shared across all units).

---

## Persistence Strategy Summary

| Data | Store | Rationale |
|------|-------|-----------|
| `MonitoredAppSettings` | `UserDefaults` (JSON) | Small, singleton, read frequently |
| `OnboardingProgress` | `UserDefaults` (JSON) | Small, singleton, write-once-per-step |

No SwiftData/Core Data needed for Unit 1 — all data fits comfortably in `UserDefaults`.

---

## Cross-Unit Integration

| Direction | Target | Mechanism |
|-----------|--------|-----------|
| Outbound → Unit 2 | `MonitoredAppFilter` | Unit 1 publishes `AppMonitoringEnabled` / `AppMonitoringDisabled` on the shared `DomainEventBus`. Unit 2 subscribes and updates its `MonitoredAppFilter` aggregate. |

**Event flow:**
```
User toggles app ON in SettingsView
  → AppSelectionViewModel.toggleApp()
    → AppMonitoringAppService.enableApp()
      → MonitoredAppSettings.enableApp() → returns AppMonitoringEnabled
      → settingsRepo.save()
      → eventBus.publish(AppMonitoringEnabled)
        → Unit 2 subscriber → MonitoredAppFilter.addApp()
```
