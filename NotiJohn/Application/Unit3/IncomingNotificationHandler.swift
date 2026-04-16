import Foundation

/// Central use-case for transient banner display. Subscribed (by
/// `Unit3Container.startEventSubscriptions`) to Unit 2's `NotificationCaptured`
/// stream and orchestrates the connection check, duplicate suppression, and
/// presentation pipeline documented in `data_binding.md`.
public final class IncomingNotificationHandler {
    private let session: CarPlaySession
    private let duplicatePolicy: DuplicateSuppressionPolicy
    private let bannerService: BannerPresentationService
    private let bannerAppService: BannerAppService
    private let eventBus: DomainEventBus

    public init(
        session: CarPlaySession,
        duplicatePolicy: DuplicateSuppressionPolicy,
        bannerService: BannerPresentationService,
        bannerAppService: BannerAppService,
        eventBus: DomainEventBus
    ) {
        self.session = session
        self.duplicatePolicy = duplicatePolicy
        self.bannerService = bannerService
        self.bannerAppService = bannerAppService
        self.eventBus = eventBus
    }

    /// Pipeline:
    ///   1. drop if CarPlay is not connected,
    ///   2. drop and emit `DuplicateNotificationSuppressed` if recently shown,
    ///   3. otherwise build a banner, present it, record the fingerprint,
    ///      emit `BannerDisplayed`, and schedule auto-dismissal.
    public func handle(event: NotificationCaptured) async {
        // 1. Connection gate.
        guard session.isConnected else { return }

        // 2. Duplicate gate.
        let now = Date()
        if duplicatePolicy.isDuplicate(fingerprint: event.fingerprint, at: now) {
            eventBus.publish(DuplicateNotificationSuppressed(
                notificationId: event.notificationId,
                fingerprint: event.fingerprint,
                occurredAt: now
            ))
            return
        }

        // 3. Build and show.
        let banner = NotificationBanner.from(event: event)
        await bannerService.show(banner: banner)

        // 4. Record the display so subsequent duplicates within the window
        //    are suppressed.
        duplicatePolicy.recordDisplay(fingerprint: event.fingerprint, at: now)

        // 5. Notify other units that a banner just went up.
        eventBus.publish(BannerDisplayed(
            notificationId: event.notificationId,
            occurredAt: now
        ))

        // 6. Schedule the auto-dismiss tick.
        bannerAppService.scheduleBannerDismissal(
            notificationId: banner.notificationId,
            after: banner.displayDuration
        )
    }
}
