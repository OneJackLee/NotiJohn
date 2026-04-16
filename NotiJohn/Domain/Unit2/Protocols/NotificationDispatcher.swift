import Foundation

/// Hook for cross-process delivery of `NotificationCaptured` events. In a
/// multi-process deployment (e.g. Notification Service Extension + main app)
/// this would bridge via App Groups + Darwin notifications. The single-process
/// implementation is a no-op because the shared `DomainEventBus` already
/// reaches Units 3 and 4.
public protocol NotificationDispatcher: AnyObject {
    func dispatch(event: NotificationCaptured)
}
