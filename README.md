# NotiJohn — iOS notification forwarding for CarPlay

## What it does

NotiJohn is an iOS companion app that forwards notifications from a user-selected set of apps to the CarPlay screen, so drivers can see and hear messages without taking their eyes off the road. Notifications appear as CarPlay banners (with optional text-to-speech) and are persisted to a browsable list that supports read/unread status, dismissal, and clear-all.

## Status

Early development — not yet App Store-ready. Real notification capture from third-party apps is currently **stubbed** behind a `NotificationListenerService` protocol; only simulated notifications can be injected during development. See `plan.md` decision **DD-I2** for the rationale and deferred options.

## Architecture

NotiJohn is split into four units, each owning a bounded slice of the product:

| Unit | Responsibility |
|------|---------------|
| Unit 1 — iPhone Companion | Onboarding, notification permission, app-selection settings |
| Unit 2 — Notification Engine | Listening, filtering, capture, persistence, pruning |
| Unit 3 — CarPlay Presentation | Real-time banners, TTS, duplicate suppression, session lifecycle |
| Unit 4 — CarPlay Notification Management | List, detail, mark-as-read, dismiss, clear-all |

Each unit follows **DDD + Clean Architecture** with strict layering:

```
Domain  →  Application  →  Infrastructure  →  Presentation
                       ↘            ↗
                    DI (AppContainer, Unit{1..4}Container)
```

Cross-unit integration uses a **Combine-based domain event bus** (`CombineDomainEventBus`) — units publish/subscribe to `DomainEvent`s rather than calling each other directly.

```
 +-----------+     events      +--------------------+     events     +------------------+
 |  Unit 1   | --------------> |      Unit 2        | -------------> |     Unit 3       |
 | Settings  |  AppMonitoring  | Notification       | Notification   | CarPlay banners  |
 |           |     Enabled     |   Engine           |   Captured     |   + TTS          |
 +-----------+                 +--------------------+                +------------------+
                                          |                                    |
                                          | shared store                       |
                                          v                                    |
                                 +--------------------+                        |
                                 |      Unit 4        | <----------------------+
                                 | List / Detail /    |    sibling on CarPlay
                                 |   Manage           |
                                 +--------------------+
```

Persistence:

- **SwiftData** — captured notifications (`NotificationModel`)
- **UserDefaults** — onboarding progress and monitored-app settings (JSON-encoded)

## Project Layout

```
NotiJohn/
  App/                       # @main entry, RootView routing
  DI/                        # AppContainer + Unit{1..4}Container
  Domain/
    Shared/                  # DomainEvent, DomainEventBus, BundleIdentifier
    Unit1/                   # MonitoredAppSettings, OnboardingProgress, ...
    Unit2/                   # Notification, MonitoredAppFilter, policies
    Unit3/                   # CarPlaySession, banner VOs, suppression policy
    Unit4/                   # NotificationSummary, NotificationDetail, policies
  Application/
    Unit1/                   # AppMonitoringAppService, OnboardingAppService
    Unit2/                   # NotificationCaptureAppService, NotificationQueryService
    Unit3/                   # CarPlaySessionAppService, BannerAppService, IncomingNotificationHandler
    Unit4/                   # List/Detail/Management app services
  Infrastructure/
    Unit1/                   # UserDefaults repos, iOS permission/discovery services
    Unit2/                   # SwiftData repo, dispatcher, StubNotificationListenerService
    Unit3/                   # CarPlay banner service, RecentAnnouncementLog, scene adapter
  Presentation/
    Unit1/                   # SwiftUI Onboarding + Settings views and view models
    Unit3/                   # CarPlaySceneDelegate
    Unit4/                   # CarPlay template builders + CarPlayTemplateManager
  Resources/
NotiJohnNSE/                 # UNNotificationServiceExtension target
construction/                # Per-unit logical_design.md, domain_model.md, function specs
inception/                   # Product vision, user stories, per-unit briefs
plan.md                      # Implementation plan + deferred decisions
project.yml                  # xcodegen project definition
```

## Requirements

- macOS with **Xcode 15+**
- **iOS 17+** deployment target
- **Swift 5.9**
- Apple Developer account — required for the **CarPlay entitlement** (`com.apple.developer.carplay-messaging`) when running on a real CarPlay head unit or submitting to the App Store. The iOS / CarPlay **Simulator works without it**.

## Setup

```bash
# 1. Clone the repo
git clone <repo-url> NotiJohn
cd NotiJohn

# 2. Install xcodegen
brew install xcodegen

# 3. Generate the Xcode project
xcodegen generate

# 4. Open the project
open NotiJohn.xcodeproj
```

Then in Xcode, select the **`NotiJohn`** scheme and build & run on an iOS Simulator (iPhone or CarPlay).

## Development workflow

- **Design lives in `inception/` and `construction/`.** `inception/` holds product vision and user stories; `construction/<unit>/` holds the logical design, domain model, and function specs for each unit.
- **Implementation status is tracked in `plan.md`.** Phases 1–3 (design) are complete; Phase 4 (implementation) is in progress.
- **Adding or removing source files:** edit `project.yml`, then re-run `xcodegen generate`. Do not hand-edit `NotiJohn.xcodeproj`.

## Testing the CarPlay flow (dev)

Because real third-party notification capture is stubbed, end-to-end testing uses a manual injection path:

1. Run NotiJohn on the iOS Simulator and complete onboarding.
2. In `SettingsView` there is a `#if DEBUG`-only **"Simulate Notification"** button, wired to `StubNotificationListenerService.simulateNotification(...)`.
3. Tapping it drives the full pipeline:

   ```
   Stub listener → AppFilterPolicy → Notification.capture →
     SwiftData save → StorageCapPolicy prune → eventBus.publish(NotificationCaptured)
       → Unit 3 (banner + TTS)
       → Unit 4 (list refresh)
   ```

4. To exercise the CarPlay UI, launch the CarPlay simulator from Xcode:

   **Simulator → I/O → External Displays → CarPlay**

   Verify that simulated notifications appear as CarPlay banners and in the CarPlay list template.

## Known limitations

- **No real third-party notification capture.** iOS sandboxing prevents an app from reading other apps' notifications directly. The current build ships only `StubNotificationListenerService`; the real capture mechanism is deferred (see `plan.md` **DD-I2**, options A–D).
- **Curated app list.** The "installed apps" surfaced in app-selection come from a fixed, curated list of common messaging apps. Dynamic discovery is not yet implemented.
- **CarPlay entitlement not provisioned.** The entitlement key is declared in `NotiJohn.entitlements`, but Apple approval has not been requested. CarPlay Simulator works; running on a real CarPlay head unit or submitting to the App Store requires the entitlement to be granted.

## License

TBD.
