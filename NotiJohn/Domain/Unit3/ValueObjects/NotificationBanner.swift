import Foundation

/// View-model-style snapshot of a notification ready for transient CarPlay
/// presentation. Built from a Unit 2 `NotificationCaptured` event.
public struct NotificationBanner: Hashable, Sendable {
    public let notificationId: NotificationId
    public let sourceAppName: String
    public let title: String
    public let bodyPreview: String
    public let displayDuration: BannerDuration

    /// Maximum body length surfaced on screen — keeps the system banner card
    /// from being clipped or pushing other UI off-screen.
    public static let bodyPreviewLimit = 100

    public init(
        notificationId: NotificationId,
        sourceAppName: String,
        title: String,
        bodyPreview: String,
        displayDuration: BannerDuration
    ) {
        self.notificationId = notificationId
        self.sourceAppName = sourceAppName
        self.title = title
        self.bodyPreview = bodyPreview
        self.displayDuration = displayDuration
    }

    /// Factory: derives a banner from an inbound `NotificationCaptured` event.
    /// Truncates the body to `bodyPreviewLimit` characters.
    public static func from(
        event: NotificationCaptured,
        duration: BannerDuration = .default
    ) -> NotificationBanner {
        NotificationBanner(
            notificationId: event.notificationId,
            sourceAppName: event.sourceApp.appName,
            title: event.content.title,
            bodyPreview: String(event.content.body.prefix(bodyPreviewLimit)),
            displayDuration: duration
        )
    }
}
