# Unit 1: iPhone Companion App — Domain Model

## Bounded Context: App Configuration

This bounded context covers the iPhone-side experience: first-launch onboarding, notification permission acquisition, and app selection for monitoring. There is no notification list on the iPhone — only settings and setup.

---

## Aggregates

### 1. MonitoredAppSettings (Aggregate Root)

Represents the user's overall app monitoring configuration. Owns the collection of monitored apps and enforces invariants on the selection.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `SettingsId` | Singleton identity (one per device) |
| `monitoredApps` | `[MonitoredApp]` | Collection of apps with their monitoring state |

**Invariants:**
- Each `BundleIdentifier` appears at most once in the collection.
- Toggling an app on/off takes effect immediately (no deferred application).

**Commands:**
| Command | Description | Emits |
|---------|-------------|-------|
| `enableApp(appInfo: AppInfo)` | Add or enable an app for monitoring | `AppMonitoringEnabled` |
| `disableApp(bundleId: BundleIdentifier)` | Disable an app from monitoring | `AppMonitoringDisabled` |
| `syncInstalledApps(installed: [AppInfo])` | Reconcile with currently installed apps — remove uninstalled, add newly discovered | `AppMonitoringDisabled` (for removed apps) |

---

### 2. OnboardingProgress (Aggregate Root)

Tracks the user's progress through the first-launch onboarding flow.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `OnboardingId` | Singleton identity (one per device) |
| `currentStep` | `OnboardingStep` | The step the user is currently on |
| `completedSteps` | `Set<OnboardingStep>` | Steps that have been completed |
| `skippedSteps` | `Set<OnboardingStep>` | Steps that the user chose to skip |
| `isComplete` | `Bool` | Whether the onboarding flow has been finished |

**Invariants:**
- Steps progress in a defined order: `welcome → permissionRequest → appSelection → completion`.
- A step can only be completed or skipped once.
- The `completion` step cannot be skipped.

**Commands:**
| Command | Description | Emits |
|---------|-------------|-------|
| `completeStep(step: OnboardingStep)` | Mark a step as completed and advance | `OnboardingStepCompleted` |
| `skipStep(step: OnboardingStep)` | Mark an optional step as skipped and advance | `OnboardingStepSkipped` |
| `finish()` | Finalize the onboarding flow | `OnboardingCompleted` |

---

## Entities

### MonitoredApp

An app that has been discovered and may be selected for notification monitoring.

| Field | Type | Description |
|-------|------|-------------|
| `bundleId` | `BundleIdentifier` | Unique identity of the app within the aggregate |
| `appInfo` | `AppInfo` | Display name and icon snapshot |
| `isEnabled` | `Bool` | Whether monitoring is currently active for this app |

**Note:** `MonitoredApp` is an entity within the `MonitoredAppSettings` aggregate — it is never accessed independently.

---

## Value Objects

### BundleIdentifier
| Field | Type | Description |
|-------|------|-------------|
| `value` | `String` | iOS app bundle ID (e.g., `"com.apple.MobileSMS"`) |

**Validation:** Must be a non-empty string matching reverse-DNS format.

### AppInfo
| Field | Type | Description |
|-------|------|-------------|
| `bundleId` | `BundleIdentifier` | The app's bundle identifier |
| `displayName` | `String` | Human-readable app name |
| `iconData` | `Data?` | App icon image data (optional, may be unavailable) |

### OnboardingStep (Enum)
| Case | Description | Skippable? |
|------|-------------|------------|
| `welcome` | Welcome / intro screen | No |
| `permissionRequest` | Request notification access permission | No |
| `appSelection` | Guide user to select apps to monitor | Yes |
| `completion` | Setup complete confirmation | No |

### PermissionStatus (Enum)
| Case | Description |
|------|-------------|
| `notDetermined` | User has not yet been prompted |
| `granted` | Permission has been granted |
| `denied` | Permission was denied or revoked |

---

## Domain Events

| Event | Payload | Triggered By |
|-------|---------|--------------|
| `AppMonitoringEnabled` | `bundleId: BundleIdentifier, appName: String` | `MonitoredAppSettings.enableApp()` |
| `AppMonitoringDisabled` | `bundleId: BundleIdentifier` | `MonitoredAppSettings.disableApp()` |
| `OnboardingStepCompleted` | `step: OnboardingStep` | `OnboardingProgress.completeStep()` |
| `OnboardingStepSkipped` | `step: OnboardingStep` | `OnboardingProgress.skipStep()` |
| `OnboardingCompleted` | _(none)_ | `OnboardingProgress.finish()` |
| `NotificationPermissionChanged` | `newStatus: PermissionStatus` | `NotificationPermissionService` |

### Event Consumers

| Event | Consumer | Reaction |
|-------|----------|----------|
| `AppMonitoringEnabled` | **Unit 2 (Notification Engine)** | Start capturing notifications from this app |
| `AppMonitoringDisabled` | **Unit 2 (Notification Engine)** | Stop capturing notifications from this app |
| `NotificationPermissionChanged(denied)` | `OnboardingProgress` | Guide user to Settings to re-enable |

---

## Policies

### ImmediateEffectPolicy
- **Rule:** Any change to the monitored app list takes effect immediately without requiring an app restart.
- **Enforcement:** The `MonitoredAppSettings` aggregate publishes domain events on every toggle; downstream consumers (Unit 2) react in real time.

---

## Repositories

### MonitoredAppSettingsRepository
| Operation | Description |
|-----------|-------------|
| `get() → MonitoredAppSettings` | Load the singleton settings aggregate |
| `save(settings: MonitoredAppSettings)` | Persist the current state |

**Implementation note:** Backed by `UserDefaults` or a lightweight local store (e.g., Core Data / SwiftData). Singleton — only one instance per device.

### OnboardingProgressRepository
| Operation | Description |
|-----------|-------------|
| `get() → OnboardingProgress` | Load the onboarding progress |
| `save(progress: OnboardingProgress)` | Persist the current progress |

**Implementation note:** Backed by `UserDefaults`. Reset only on app reinstall.

---

## Domain Services

### InstalledAppDiscoveryService
Discovers all apps installed on the device that have notification permissions.

| Operation | Description |
|-----------|-------------|
| `discoverApps() → [AppInfo]` | Returns list of installed apps with notification capability |

**Note:** This is an infrastructure-dependent service that wraps iOS APIs. The domain depends on its interface (protocol), not its implementation.

### NotificationPermissionService
Manages the iOS notification access permission lifecycle.

| Operation | Description |
|-----------|-------------|
| `requestPermission() → PermissionStatus` | Trigger the iOS system permission prompt |
| `checkCurrentStatus() → PermissionStatus` | Query the current permission state |

**Emits:** `NotificationPermissionChanged` when the status changes (e.g., user revokes in Settings).

---

## Aggregate Boundary Diagram

```
┌─────────────────────────────────────────────┐
│         MonitoredAppSettings (AR)            │
│                                             │
│  ┌──────────────────┐                       │
│  │  MonitoredApp    │  ← Entity             │
│  │  - bundleId (ID) │                       │
│  │  - appInfo       │  ← VO                 │
│  │  - isEnabled     │                       │
│  └──────────────────┘                       │
│       (0..N instances)                      │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│         OnboardingProgress (AR)             │
│                                             │
│  - currentStep      ← OnboardingStep (VO)  │
│  - completedSteps   ← Set<OnboardingStep>  │
│  - skippedSteps     ← Set<OnboardingStep>  │
│  - isComplete                               │
└─────────────────────────────────────────────┘
```

---

## Integration with Other Units

| Direction | Unit | Mechanism |
|-----------|------|-----------|
| Outbound → | Unit 2 (Notification Engine) | Domain events `AppMonitoringEnabled` / `AppMonitoringDisabled` communicate the current monitored app list. Unit 2 subscribes to these events to update its filter. |
