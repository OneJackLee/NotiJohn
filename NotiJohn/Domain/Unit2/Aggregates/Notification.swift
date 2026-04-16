import Foundation

/// Canonical Notification aggregate. Owned by Unit 2 (capture/persistence) and
/// mutated by Unit 4 (management actions). All cross-unit consumers reference
/// this type, so it is `public` and reference-typed for shared identity.
public final class Notification {
    public let id: NotificationId
    public let sourceApp: SourceApp
    public let content: NotificationContent
    public let capturedAt: CaptureTimestamp
    public let fingerprint: NotificationFingerprint
    public private(set) var readStatus: ReadStatus

    /// Designated initializer used by the repository to re-hydrate a persisted
    /// aggregate without re-running invariants (id/fingerprint are trusted).
    public init(
        id: NotificationId,
        sourceApp: SourceApp,
        content: NotificationContent,
        capturedAt: CaptureTimestamp,
        fingerprint: NotificationFingerprint,
        readStatus: ReadStatus
    ) {
        self.id = id
        self.sourceApp = sourceApp
        self.content = content
        self.capturedAt = capturedAt
        self.fingerprint = fingerprint
        self.readStatus = readStatus
    }

    /// Factory invoked by `NotificationCaptureAppService`. Generates a fresh id,
    /// computes the fingerprint, defaults read status to `.unread`, and emits the
    /// `NotificationCaptured` event so the caller can publish it on the bus.
    public static func capture(
        sourceApp: SourceApp,
        content: NotificationContent,
        timestamp: Date
    ) -> (notification: Notification, event: NotificationCaptured) {
        let id = NotificationId()
        let capturedAt = CaptureTimestamp(timestamp)
        let fingerprint = NotificationFingerprint.compute(
            bundleId: sourceApp.bundleId,
            title: content.title,
            body: content.body
        )
        let notification = Notification(
            id: id,
            sourceApp: sourceApp,
            content: content,
            capturedAt: capturedAt,
            fingerprint: fingerprint,
            readStatus: .unread
        )
        let event = NotificationCaptured(
            notificationId: id,
            sourceApp: sourceApp,
            content: content,
            capturedAt: capturedAt,
            fingerprint: fingerprint,
            occurredAt: timestamp
        )
        return (notification, event)
    }

    /// Idempotent — returns `nil` if the notification was already read so the
    /// caller can skip publishing a redundant `NotificationMarkedAsRead`.
    public func markAsRead() -> NotificationMarkedAsRead? {
        guard readStatus == .unread else { return nil }
        readStatus = .read
        return NotificationMarkedAsRead(notificationId: id, occurredAt: Date())
    }

    /// Always emits the dismissal event. The repository performs the actual
    /// deletion in response.
    public func dismiss() -> NotificationDismissed {
        NotificationDismissed(notificationId: id, occurredAt: Date())
    }
}
