# NotiJohn — iOS notification forwarding for CarPlay

## What it does

NotiJohn is an iOS companion app that forwards notifications from a user-selected set of apps to the CarPlay screen, so drivers can see messages without taking their eyes off the road. Notifications appear as CarPlay banners and are persisted to a browsable list that supports read/unread status, dismissal, and clear-all.

## Status

Early development — not yet App Store-ready. Real notification capture from third-party apps is currently **stubbed** behind a `NotificationListenerService` protocol; only simulated notifications can be injected during development. See `plan.md` decision **DD-I2** for the rationale and deferred options.

## Architecture

NotiJohn is split into four units, each owning a bounded slice of the product:

| Unit | Responsibility |
|------|---------------|
| Unit 1 — iPhone Companion | Onboarding, notification permission, app-selection settings |
| Unit 2 — Notification Engine | Listening, filtering, capture, persistence, pruning |
| Unit 3 — CarPlay Presentation | Real-time banners, duplicate suppression, session lifecycle (TTS removed from scope, see plan.md DD-L4) |
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
 |           |     Enabled     |   Engine           |   Captured     |                  |
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
    Debug/                   # #if DEBUG iPhone-side mirror of Unit 4's CarPlay list
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
- Apple Developer account — required for the **CarPlay entitlement** (`com.apple.developer.carplay-communication`) when running on a real CarPlay head unit, surfacing the app on the CarPlay screen, or submitting to the App Store. See **Known blockers** below for the full impact on Simulator testing.

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

## Testing the pipeline (dev)

Because real third-party notification capture is stubbed and the CarPlay screen is currently inaccessible (see **Known blockers**), end-to-end validation runs on the iPhone simulator using a built-in debug surface.

1. Run NotiJohn on the iOS Simulator and complete onboarding.
2. In `SettingsView`, scroll to **Debug — Simulate Notification** (visible in `#if DEBUG` builds only). Tap **Send Simulated Notification**. The button auto-adds the bundle ID to the in-memory `MonitoredAppFilter` so it always succeeds, regardless of whether you've toggled the corresponding row in "Monitored Apps".
3. This drives the full Unit 2 pipeline:

   ```
   captureService.handleIncomingNotification →
     AppFilterPolicy → Notification.capture →
       SwiftData save → StorageCapPolicy prune →
         eventBus.publish(NotificationCaptured)
           → Unit 3 IncomingNotificationHandler (banner attempt)
           → Unit 4 NotificationListAppService (list refresh)
   ```

4. Then in `SettingsView`, tap **Debug — Captured Notifications → View captured notifications**. This pushes the iPhone-side `DebugNotificationListView`, which is wired to the **same** Unit 4 application services that drive CarPlay. Use it to:
   - confirm captured notifications appear (live-updating via `observeListChanges()`);
   - tap a row to push the detail view (auto-marks-as-read via `AutoMarkAsReadOnViewPolicy`);
   - swipe a row to dismiss;
   - use the **Clear All** toolbar button (with confirmation) to delete everything.

If the list is empty, check the Xcode console for `[NotiJohn] Capture rejected — <bundleId> not in MonitoredAppFilter` lines — they fire whenever the filter drops a notification.

> **Note on the CarPlay window.** `Simulator → I/O → External Displays → CarPlay` *does* render a CarPlay screen, but NotiJohn will not appear on it under the current state of the project — see **Known blockers** for why.

## Known blockers

### B-1: CarPlay surface is currently inaccessible

NotiJohn's CarPlay scene, banners, and notification list **do not appear on the CarPlay screen** today. Root cause:

- **No Apple-issued CarPlay entitlement.** The `com.apple.developer.carplay-communication` key is declared in `NotiJohn.entitlements`, but the entitlement itself has not been requested from Apple. CarPlay enforces this at runtime: the system silently refuses to instantiate a third-party app's CarPlay scene unless the matching entitlement is present in the provisioning profile. This is true on **both physical hardware and the iOS Simulator** — Apple's Simulator has no "trust" path for unprovisioned third-party CarPlay apps. Apple's own apps (Maps, Music, Podcasts) appear in the Simulator's CarPlay window because they're signed by Apple; ours is not.
- **Notifications also gated by the entitlement.** `CarPlayBannerPresentationService` posts local notifications with a `UNNotificationCategory` flagged `.allowInCarPlay`, but the system only routes those to the CarPlay screen when the posting app is recognised as a CarPlay-eligible app — i.e., has the entitlement.

**Workaround for development:** the iPhone-side **Debug — Captured Notifications** screen (added under `Presentation/Debug/`) reuses Unit 4's `NotificationListAppService`, `NotificationDetailAppService`, and `NotificationManagementAppService` — the exact same code paths that back the CarPlay templates. It exercises capture, persistence, the change-event stream, auto-mark-as-read, dismiss, and clear-all. If the pipeline works there, it works in CarPlay too — only the rendering surface is missing.

**Resolution path (to unblock real CarPlay testing):**
1. Submit the CarPlay request form: <https://developer.apple.com/contact/carplay/>. NotiJohn fits the **Communication** category roughly; expect Apple to scrutinise the use case (notification aggregator is not a standard CarPlay category).
2. Once Apple grants the entitlement, regenerate the provisioning profile in Xcode.
3. Test on a real CarPlay-capable head unit (factory or aftermarket — Pioneer, Kenwood, etc.) over USB. The iOS Simulator's CarPlay window may *also* start showing the app once the entitlement is in the active profile, but real-hardware testing is the supported path.

### B-2: No real third-party notification capture

iOS sandboxing prevents an app from reading other apps' notifications directly. The current build ships only `StubNotificationListenerService`; the real capture mechanism is deferred. See `plan.md` **DD-I2** for the four options under consideration (NSE-based, UN delegate, backend relay, or continued stub).

### B-3: Curated app list

The "installed apps" surfaced in app-selection come from a fixed, curated list of common messaging apps (`IOSAppDiscoveryService`). Dynamic discovery is not implemented; the design suggests NSE-driven discovery as a future addition.

## License

TBD.
