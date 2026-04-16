import Foundation

/// Emitted by `Notification.dismiss()`. Unit 4 publishes the event and the
/// repository performs the actual delete in response.
public struct NotificationDismissed: DomainEvent, Sendable {
    public let notificationId: NotificationId
    public let occurredAt: Date

    public init(notificationId: NotificationId, occurredAt: Date) {
        self.notificationId = notificationId
        self.occurredAt = occurredAt
    }
}
