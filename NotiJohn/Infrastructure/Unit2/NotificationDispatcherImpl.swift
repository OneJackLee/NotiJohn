import Foundation

/// Single-process implementation of `NotificationDispatcher`.
///
/// In the current architecture the capture service publishes
/// `NotificationCaptured` directly on the shared `DomainEventBus`, which is
/// already observed by Units 3 and 4. There is therefore nothing for the
/// dispatcher to do — the type exists as a documented integration seam so a
/// future multi-process build (e.g. Notification Service Extension forwarding
/// via App Groups + Darwin notifications) can swap in a real implementation
/// without touching `NotificationCaptureAppService`.
public final class NotificationDispatcherImpl: NotificationDispatcher {
    private let eventBus: DomainEventBus

    public init(eventBus: DomainEventBus) {
        self.eventBus = eventBus
    }

    public func dispatch(event: NotificationCaptured) {
        // Intentional no-op. See type-level documentation.
    }
}
