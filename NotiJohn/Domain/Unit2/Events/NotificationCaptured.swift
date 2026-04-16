import Foundation

/// Published when a notification has been filtered, persisted, and is ready to
/// be presented. Consumed by Unit 3 (CarPlay banner) and Unit 4 (list refresh).
public struct NotificationCaptured: DomainEvent, Sendable {
    public let notificationId: NotificationId
    public let sourceApp: SourceApp
    public let content: NotificationContent
    public let capturedAt: CaptureTimestamp
    public let fingerprint: NotificationFingerprint
    public let occurredAt: Date

    public init(
        notificationId: NotificationId,
        sourceApp: SourceApp,
        content: NotificationContent,
        capturedAt: CaptureTimestamp,
        fingerprint: NotificationFingerprint,
        occurredAt: Date
    ) {
        self.notificationId = notificationId
        self.sourceApp = sourceApp
        self.content = content
        self.capturedAt = capturedAt
        self.fingerprint = fingerprint
        self.occurredAt = occurredAt
    }
}
