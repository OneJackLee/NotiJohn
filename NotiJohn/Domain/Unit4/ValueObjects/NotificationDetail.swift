import Foundation

/// Read-optimized projection of a `Notification` aggregate for the CarPlay
/// detail view. Includes the body text and the source-app icon so the
/// `CPInformationTemplate` can render everything without re-querying.
public struct NotificationDetail {
    public let notificationId: NotificationId
    public let sourceAppName: String
    public let appIcon: Data?
    public let title: String
    public let body: String
    public let capturedAt: Date
    public let readStatus: ReadStatus

    public init(
        notificationId: NotificationId,
        sourceAppName: String,
        appIcon: Data?,
        title: String,
        body: String,
        capturedAt: Date,
        readStatus: ReadStatus
    ) {
        self.notificationId = notificationId
        self.sourceAppName = sourceAppName
        self.appIcon = appIcon
        self.title = title
        self.body = body
        self.capturedAt = capturedAt
        self.readStatus = readStatus
    }

    /// Projects a `Notification` aggregate to the detail view's flat shape.
    public static func from(_ notification: Notification) -> NotificationDetail {
        NotificationDetail(
            notificationId: notification.id,
            sourceAppName: notification.sourceApp.appName,
            appIcon: notification.sourceApp.appIcon,
            title: notification.content.title,
            body: notification.content.body,
            capturedAt: notification.capturedAt.value,
            readStatus: notification.readStatus
        )
    }
}
