import Foundation

/// Published once a `NotificationBanner` has been handed to the system for
/// display on the CarPlay screen.
public struct BannerDisplayed: DomainEvent, Sendable {
    public let notificationId: NotificationId
    public let occurredAt: Date

    public init(notificationId: NotificationId, occurredAt: Date) {
        self.notificationId = notificationId
        self.occurredAt = occurredAt
    }
}
