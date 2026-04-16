import Foundation

/// Published when an inbound `NotificationCaptured` event is dropped from the
/// banner pipeline because the same fingerprint was already shown inside the
/// `DuplicateWindow`. The notification is still persisted by Unit 2.
public struct DuplicateNotificationSuppressed: DomainEvent, Sendable {
    public let notificationId: NotificationId
    public let fingerprint: NotificationFingerprint
    public let occurredAt: Date

    public init(
        notificationId: NotificationId,
        fingerprint: NotificationFingerprint,
        occurredAt: Date
    ) {
        self.notificationId = notificationId
        self.fingerprint = fingerprint
        self.occurredAt = occurredAt
    }
}
