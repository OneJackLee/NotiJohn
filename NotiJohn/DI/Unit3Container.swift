import Foundation
import Combine

/// DI container for Unit 3 (CarPlay Presentation).
///
/// Owns the CarPlay session aggregate, the duplicate-suppression policy, the
/// banner presentation service, and the application-layer services that wire
/// inbound `NotificationCaptured` events to transient banner display.
///
/// `startEventSubscriptions()` must be called once after construction (the
/// `AppContainer` does this) to install the Combine pipelines.
public final class Unit3Container {
    public let eventBus: DomainEventBus

    public init(eventBus: DomainEventBus) {
        self.eventBus = eventBus
    }

    // MARK: - Domain

    public lazy var session: CarPlaySession = CarPlaySession()

    public lazy var recentLog: RecentAnnouncementLog = InMemoryRecentAnnouncementLog()

    public lazy var duplicatePolicy: DuplicateSuppressionPolicy = DuplicateSuppressionPolicy(
        recentLog: recentLog,
        window: .default
    )

    // MARK: - Infrastructure

    public lazy var bannerService: BannerPresentationService = CarPlayBannerPresentationService()

    // MARK: - Application

    public lazy var sessionService: CarPlaySessionAppService = CarPlaySessionAppService(
        session: session,
        eventBus: eventBus,
        bannerService: bannerService
    )

    public lazy var bannerAppService: BannerAppService = BannerAppService(
        bannerService: bannerService,
        eventBus: eventBus
    )

    public lazy var incomingHandler: IncomingNotificationHandler = IncomingNotificationHandler(
        session: session,
        duplicatePolicy: duplicatePolicy,
        bannerService: bannerService,
        bannerAppService: bannerAppService,
        eventBus: eventBus
    )

    // MARK: - Presentation bridge

    public lazy var lifecycleAdapter: CarPlaySceneLifecycleAdapter = CarPlaySceneLifecycleAdapter(
        sessionService: sessionService
    )

    // MARK: - Subscription bag

    /// Retains the long-lived Combine subscriptions so they live as long as
    /// the container does (i.e. for the app lifetime).
    private var cancellables = Set<AnyCancellable>()

    /// Wires:
    ///   - `NotificationCaptured` (from Unit 2) → `incomingHandler.handle(...)`
    ///   - a 60-second purge timer that prunes the duplicate log
    public func startEventSubscriptions() {
        // Inbound notification capture → banner pipeline.
        eventBus.subscribe(to: NotificationCaptured.self)
            .sink { [incomingHandler] event in
                Task {
                    await incomingHandler.handle(event: event)
                }
            }
            .store(in: &cancellables)

        // Periodic purge of expired duplicate-log entries.
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [recentLog] _ in
                recentLog.purgeExpired(window: .default)
            }
            .store(in: &cancellables)
    }
}
