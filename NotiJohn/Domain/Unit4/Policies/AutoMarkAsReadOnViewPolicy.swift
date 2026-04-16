import Foundation

/// Side-effect policy applied when the user opens a notification's detail.
/// Wraps `Notification.markAsRead()` in a named domain concept so that the
/// detail use case reads as `policy.apply(to: notification)` rather than
/// touching the aggregate's command directly.
///
/// Returns the `NotificationMarkedAsRead` event when the status actually
/// transitioned from `.unread` to `.read`, or `nil` when the notification
/// was already read (idempotent — no event published).
public struct AutoMarkAsReadOnViewPolicy {
    public init() {}

    public func apply(to notification: Notification) -> NotificationMarkedAsRead? {
        notification.markAsRead()
    }
}
