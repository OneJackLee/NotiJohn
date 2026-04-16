# CLAUDE.md

Guide for future Claude Code sessions in this repo. Read this first; consult `construction/` and `plan.md` before any non-trivial change.

## 1. Project at a glance

NotiJohn is an iOS 17+ app with a CarPlay scene. The iPhone side is a configuration UI; the CarPlay side displays and manages notifications captured from user-selected apps. Capture is currently stubbed (see Gotchas).

## 2. Architecture

Four vertical-slice **units**, each with its own Domain / Application / Infrastructure / Presentation layers (Clean Architecture):

1. **Unit 1 — iPhone Companion**: onboarding, app selection, settings.
2. **Unit 2 — Notification Engine**: capture, filter, persist, prune. Owns the canonical `Notification` aggregate and `NotificationRepository`.
3. **Unit 3 — CarPlay Presentation**: CarPlay session lifecycle, incoming-notification banners, duplicate suppression.
4. **Unit 4 — CarPlay Notification Management**: list/detail templates, mark-as-read, dismiss, clear-all. Mutates Unit 2's notifications via the shared `NotificationRepository`.

**Cross-unit integration is event-bus only.** Units do **not** import each other's app services. Communication flows through a single shared `DomainEventBus` (Combine `PassthroughSubject`):

- Publish: `eventBus.publish(SomeEvent(...))` from an app service.
- Subscribe: `eventBus.subscribe(to: SomeEvent.self)` returns `AnyPublisher<SomeEvent, Never>`. Wire subscriptions inside per-unit container `startEventSubscriptions()`.

Two exceptions to the no-direct-call rule:

- Unit 4 reads/writes Unit 2's `NotificationRepository` and `NotificationQueryService` directly (shared instances injected by `AppContainer`).
- Unit 3 owns `CarPlaySceneDelegate`; Unit 4 owns the CarPlay template stack. They coordinate via a static `sceneServices` property on `CarPlaySceneDelegate` populated in `AppContainer.init` (UIKit instantiates the scene delegate, so DI cannot reach it directly).

**Persistence**:

- `NotificationModel` (SwiftData `@Model`) for notifications. Single shared `ModelContainer`; `ModelContext` is **not Sendable** — touch only on the main actor.
- `UserDefaults` (App Group `group.com.onejacklee.notijohn`) for monitored-app settings and onboarding progress.

## 3. Repository layout

```
construction/                         - Authoritative logical designs and function specs (READ FIRST)
  unit_{1..4}_*/logical_design.md     - Per-unit architecture
inception/                            - Product overview and user stories
  overview_user_stories.md
NotiJohn/                             - App source
  App/                                - @main entry, RootView routing
  Domain/Shared/                      - DomainEvent, DomainEventBus, BundleIdentifier
  Domain/Unit{1..4}/                  - Aggregates, value objects, events, policies, protocols
  Application/Unit{1..4}/             - Use case orchestration (app services)
  Infrastructure/Unit{1..4}/          - Repositories, OS adapters, persistence models
  Presentation/Unit{1..4}/            - SwiftUI views (Unit 1) or CarPlay templates (Units 3, 4)
  DI/                                 - AppContainer + per-unit containers
  Info.plist, NotiJohn.entitlements
NotiJohnNSE/                          - UNNotificationServiceExtension target
project.yml                           - xcodegen project spec (regenerate after add/remove)
plan.md                               - Living implementation plan with confirmed decisions
```

## 4. Build / Run

```bash
brew install xcodegen           # one-time
xcodegen generate               # regenerate .xcodeproj from project.yml
open NotiJohn.xcodeproj
```

Or headless:

```bash
xcodebuild -scheme NotiJohn -destination 'platform=iOS Simulator,name=iPhone 15' build
```

Notes:

- iOS 17.0 deployment target, Swift 5.9.
- Bundle IDs: `com.onejacklee.notijohn` (app), `com.onejacklee.notijohn.nse` (extension).
- App Group: `group.com.onejacklee.notijohn`.
- CarPlay entitlement key (`com.apple.developer.carplay-communication`) is declared but not provisioned. The Simulator's CarPlay window does **not** show NotiJohn either — Apple gates third-party CarPlay scenes on the entitlement on both Simulator and hardware. Use the iPhone-side `Presentation/Debug/DebugNotificationListView` to validate the pipeline end-to-end. See `README.md` "Known blockers → B-1".

## 5. Conventions

- Swift 5.9. Use `@Observable` (Observation framework), **not** `ObservableObject`.
- All cross-unit types are `public`.
- Domain events conform to `DomainEvent` and are published only via `DomainEventBus.publish`.
- Aggregates are `final class` (identity); value objects are `struct`.
- Repository methods are `async` / `async throws`.
- SwiftUI uses ViewModels; CarPlay uses template builders coordinated by `CarPlayTemplateManager`.
- DI is constructor injection through per-unit containers wired in `AppContainer`. No third-party DI framework.
- No marketing-copy comments. No emojis in code or docs.

## 6. Adding a new file

1. Create the file in the correct unit/layer under `NotiJohn/`.
2. Run `xcodegen generate` — the `sources` glob auto-discovers it; no manual project edits needed.
3. Re-build.

## 7. Gotchas

- **Notification capture is a stub.** `IOSNotificationListenerService` does not exist; only `StubNotificationListenerService` does. iOS sandboxing prevents reading other apps' notifications directly. See `plan.md` DD-I2 — real mechanism is deferred. Use the Debug panel "Simulate Notification" to drive the pipeline.
- **App enumeration is curated.** `IOSAppDiscoveryService` returns a hardcoded list of common messaging apps. Dynamic discovery is deferred.
- **CarPlay scene delegate is UIKit-instantiated.** It is **not** created by DI. Pass dependencies via the static `CarPlaySceneDelegate.sceneServices` property, which `AppContainer.init` populates at launch.
- **TTS is out of scope.** Removed from Unit 3 in initial design; do not add it without revisiting `plan.md` DD-L4.
- **SwiftData `ModelContext` is not Sendable.** All access goes through the main actor.
- **No direct cross-unit imports.** If you find yourself importing a sibling unit's app service, stop and add a domain event instead. The two sanctioned exceptions are documented in section 2.
- **SwiftData migrations are not set up.** Schema changes to `NotificationModel` require manual handling.

## 8. Where to look when…

- Adding a new domain event → `Domain/Unit{N}/Events/`, then publish from the relevant app service and subscribe in the consuming unit's container.
- Adding an iPhone UI screen → `Presentation/Unit1/Views/` (+ ViewModel in `Presentation/Unit1/ViewModels/`).
- Adding a CarPlay screen → `Presentation/Unit4/` (template builder + register in `CarPlayTemplateManager`).
- Changing persistence schema → `Infrastructure/Unit2/Persistence/NotificationModel.swift`.
- Changing capture/filter/prune logic → `Application/Unit2/NotificationCaptureAppService.swift` and Unit 2 policies.
- Reviewing product intent → `inception/overview_user_stories.md` and `inception/units/`.
- Reviewing authoritative design → `construction/unit_{1..4}_*/logical_design.md`.
- Tracking implementation status → `plan.md` (Phase 4 step checklist).
