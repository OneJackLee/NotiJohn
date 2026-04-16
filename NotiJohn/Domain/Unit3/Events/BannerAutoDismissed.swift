import Foundation

/// Published after the `BannerDuration` timer fires and the delivered system
/// notification has been removed from the CarPlay screen.
public struct BannerAutoDismissed: DomainEvent, Sendable {
    public let notificationId: NotificationId
    public let occurredAt: Date

    public init(notificationId: NotificationId, occurredAt: Date) {
        self.notificationId = notificationId
        self.occurredAt = occurredAt
    }
}
