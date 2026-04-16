import Foundation

/// Read-optimized projection of a `Notification` aggregate for the CarPlay
/// list view. Strips the body text and other detail-only fields so that the
/// list builder never needs to hold full notification payloads in memory.
public struct NotificationSummary: Identifiable {
    public let notificationId: NotificationId
    public let sourceAppName: String
    public let title: String
    public let capturedAt: Date
    public let readStatus: ReadStatus

    public var id: NotificationId { notificationId }

    public init(
        notificationId: NotificationId,
        sourceAppName: String,
        title: String,
        capturedAt: Date,
        readStatus: ReadStatus
    ) {
        self.notificationId = notificationId
        self.sourceAppName = sourceAppName
        self.title = title
        self.capturedAt = capturedAt
        self.readStatus = readStatus
    }

    /// Projects a `Notification` aggregate down to the fields the list view needs.
    public static func from(_ notification: Notification) -> NotificationSummary {
        NotificationSummary(
            notificationId: notification.id,
            sourceAppName: notification.sourceApp.appName,
            title: notification.content.title,
            capturedAt: notification.capturedAt.value,
            readStatus: notification.readStatus
        )
    }
}
