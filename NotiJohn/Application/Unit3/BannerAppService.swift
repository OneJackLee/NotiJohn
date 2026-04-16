import Foundation

/// Schedules auto-dismissal of displayed banners. Each scheduled task sleeps
/// for the configured `BannerDuration`, then asks the presentation service to
/// remove the delivered notification and publishes `BannerAutoDismissed`.
///
/// The work is performed in detached `Task`s — there is no need to retain
/// them: cancellation is not required (early dismissal is harmless because
/// `removeDeliveredNotifications` is a no-op if the card is already gone).
public final class BannerAppService {
    private let bannerService: BannerPresentationService
    private let eventBus: DomainEventBus

    public init(
        bannerService: BannerPresentationService,
        eventBus: DomainEventBus
    ) {
        self.bannerService = bannerService
        self.eventBus = eventBus
    }

    /// Schedules dismissal of `notificationId` after `duration` elapses.
    /// Off-main: uses `Task` with `Task.sleep` so the call site is non-blocking.
    public func scheduleBannerDismissal(
        notificationId: NotificationId,
        after duration: BannerDuration
    ) {
        let bannerService = self.bannerService
        let eventBus = self.eventBus
        Task {
            try? await Task.sleep(for: .seconds(duration.seconds))
            await bannerService.dismiss(notificationId: notificationId)
            eventBus.publish(BannerAutoDismissed(
                notificationId: notificationId,
                occurredAt: Date()
            ))
        }
    }
}
