import Foundation

/// Coordinates `CarPlaySession` mutations with event publication. Invoked by
/// `CarPlaySceneLifecycleAdapter` when the OS reports connection changes.
public final class CarPlaySessionAppService {
    private let session: CarPlaySession
    private let eventBus: DomainEventBus
    private let bannerService: BannerPresentationService

    public init(
        session: CarPlaySession,
        eventBus: DomainEventBus,
        bannerService: BannerPresentationService
    ) {
        self.session = session
        self.eventBus = eventBus
        self.bannerService = bannerService
    }

    /// Starts the session and publishes `CarPlaySessionStarted`.
    public func onCarPlayConnect() {
        let event = session.start()
        eventBus.publish(event)
    }

    /// Ends the session and publishes `CarPlaySessionEnded`. No banner cleanup
    /// is performed — when CarPlay disconnects the head-unit display is gone,
    /// so any in-flight delivered notifications become moot.
    public func onCarPlayDisconnect() {
        let event = session.end()
        eventBus.publish(event)
    }
}
