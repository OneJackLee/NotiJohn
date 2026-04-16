# Unit 1: iPhone Companion App — Data Binding

## Overview

This document describes how domain data flows between the UI layer (SwiftUI views) and the domain/application layers via ViewModels using the Swift Observation framework (`@Observable`).

---

## ViewModel → View Binding

### OnboardingViewModel

| Property | Type | Bound To | Update Trigger |
|----------|------|----------|----------------|
| `currentStep` | `OnboardingStep` | Onboarding container (which step view to show) | `onAppear`, `completeStep()`, `skipStep()` |
| `permissionStatus` | `PermissionStatus` | Permission step UI state (S1.2) | `requestPermission()`, `onAppear`, `scenePhase` change |
| `installedApps` | `[AppInfo]` | App selection list (S1.3) | `onAppear` (discovered once) |
| `selectedBundleIds` | `Set<BundleIdentifier>` | Toggle state for each app row | `toggleApp()` |
| `isComplete` | `Bool` | Navigation root (show settings vs onboarding) | `finishOnboarding()` |
| `isLoading` | `Bool` | Loading indicator | During async operations |

**Binding pattern:**
```swift
@Observable
final class OnboardingViewModel {
    // State (observed by SwiftUI)
    var currentStep: OnboardingStep = .welcome
    var permissionStatus: PermissionStatus = .notDetermined
    var installedApps: [AppInfo] = []
    var selectedBundleIds: Set<BundleIdentifier> = []
    var isComplete: Bool = false
    var isLoading: Bool = false

    // SwiftUI reads these directly — @Observable triggers re-render on change
}
```

### AppSelectionViewModel

| Property | Type | Bound To | Update Trigger |
|----------|------|----------|----------------|
| `monitoredApps` | `[MonitoredApp]` | App list rows with toggles (S1.5) | `onAppear`, `toggleApp()` |
| `permissionStatus` | `PermissionStatus` | Permission status section (S1.5) | `onAppear`, `scenePhase` change |
| `isLoading` | `Bool` | Loading indicator | During async operations |

---

## View → ViewModel Actions

### Onboarding Flow

| View Event | ViewModel Method | Domain Operation |
|------------|-----------------|------------------|
| S1.1 "Continue" tapped | `advanceStep()` | `onboardingService.completeStep(.welcome)` |
| S1.2 "Allow" tapped | `requestPermission()` | `onboardingService.requestNotificationPermission()` |
| S1.2 "Continue" tapped | `advanceStep()` | `onboardingService.completeStep(.permissionRequest)` |
| S1.3 toggle changed | `toggleApp(bundleId:, enabled:)` | `appMonitoringService.enableApp()` / `.disableApp()` |
| S1.3 "Continue" tapped | `advanceStep()` | `onboardingService.completeStep(.appSelection)` |
| S1.3 "Skip" tapped | `skipCurrentStep()` | `onboardingService.skipStep(.appSelection)` |
| S1.4 "Get Started" tapped | `finishOnboarding()` | `onboardingService.finishOnboarding()` |

### Settings Screen

| View Event | ViewModel Method | Domain Operation |
|------------|-----------------|------------------|
| Screen appears | `onAppear()` | `appMonitoringService.loadSettings()` + `permissionService.checkCurrentStatus()` |
| Toggle changed | `toggleApp(app:)` | `appMonitoringService.enableApp()` / `.disableApp()` |
| "Open Settings" tapped | `openSystemSettings()` | `UIApplication.shared.open(settingsURL)` |
| App returns to foreground | `refreshPermissionStatus()` | `permissionService.checkCurrentStatus()` |

---

## Reactive Data Flow

### Toggle → Domain Event → Unit 2

```
SwiftUI Toggle(isOn: $binding)
  │
  ▼
AppSelectionViewModel.toggleApp(app)
  │
  ▼
AppMonitoringAppService.enableApp(appInfo)
  │
  ├── MonitoredAppSettings.enableApp() → AppMonitoringEnabled event
  ├── settingsRepo.save()
  └── eventBus.publish(AppMonitoringEnabled)
        │
        ▼
      Unit 2 subscriber: MonitoredAppFilter.addApp()
```

### Permission Status → View Update

```
iOS Settings change / requestPermission() result
  │
  ▼
NotificationPermissionService.checkCurrentStatus()
  │
  ▼
OnboardingViewModel.permissionStatus = newStatus
  │
  ▼
SwiftUI re-renders:
  - .notDetermined → "Allow Notifications" button
  - .granted       → Success checkmark
  - .denied        → "Open Settings" + explanation
```

### Onboarding Progress → Navigation

```
OnboardingViewModel.advanceStep()
  │
  ▼
OnboardingAppService.completeStep(step)
  │
  ├── OnboardingProgress.completeStep() → advances currentStep
  └── onboardingRepo.save()
  │
  ▼
OnboardingViewModel.currentStep = newStep
  │
  ▼
SwiftUI onboarding container renders new step view
```

---

## Data Loading Strategy

| Screen | Load Trigger | Data Source | Caching |
|--------|-------------|-------------|---------|
| Onboarding (S1.1-S1.4) | `onAppear` of container | `OnboardingProgressRepository` | In-memory (ViewModel lifetime) |
| Permission step (S1.2) | `onAppear` + `scenePhase` | `NotificationPermissionService` | None (always fresh) |
| App selection (S1.3, S1.5) | `onAppear` | `InstalledAppDiscoveryService` + `MonitoredAppSettingsRepository` | In-memory (ViewModel lifetime) |
| Settings (S1.5) | `onAppear` | Same as above | In-memory (ViewModel lifetime) |

**All data loading is async** — ViewModels use `Task { }` blocks triggered by `onAppear`. Views show a loading state (`ProgressView`) until data is available.

---

## Error Handling

| Error | View Response |
|-------|--------------|
| Repository save fails | Revert optimistic toggle, show brief error toast |
| Permission request interrupted | Re-check status on next `onAppear` |
| App discovery returns empty list | Show "No apps found" empty state with explanation |
