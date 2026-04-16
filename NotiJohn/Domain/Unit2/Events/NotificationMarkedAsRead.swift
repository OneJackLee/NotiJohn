import Foundation

/// Emitted by `Notification.markAsRead()` when the status actually transitions
/// from `.unread` to `.read`. Defined in Unit 2 because it belongs to the
/// `Notification` aggregate, but published by Unit 4's services.
public struct NotificationMarkedAsRead: DomainEvent, Sendable {
    public let notificationId: NotificationId
    public let occurredAt: Date

    public init(notificationId: NotificationId, occurredAt: Date) {
        self.notificationId = notificationId
        self.occurredAt = occurredAt
    }
}
