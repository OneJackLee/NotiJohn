import Foundation
import UserNotifications

/// Presents banners by posting local user notifications. CarPlay surfaces
/// these as native notification cards on the head-unit display.
///
/// The notification's `identifier` is the `NotificationId.value.uuidString`,
/// which lets `dismiss(notificationId:)` remove the exact delivered card.
public final class CarPlayBannerPresentationService: BannerPresentationService, @unchecked Sendable {
    /// Custom category, declared so we can attach actions later if needed.
    public static let categoryIdentifier = "NOTIJOHN_BANNER"

    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func show(banner: NotificationBanner) async {
        let content = UNMutableNotificationContent()
        content.title = banner.sourceAppName
        content.subtitle = banner.title
        content.body = banner.bodyPreview
        content.categoryIdentifier = Self.categoryIdentifier

        let request = UNNotificationRequest(
            identifier: banner.notificationId.value.uuidString,
            content: content,
            trigger: nil // immediate delivery
        )

        do {
            try await center.add(request)
        } catch {
            // Silent failure — banner display is best-effort. The notification
            // is still persisted by Unit 2, so the driver can find it in the
            // CarPlay list owned by Unit 4.
        }
    }

    public func dismiss(notificationId: NotificationId) async {
        center.removeDeliveredNotifications(
            withIdentifiers: [notificationId.value.uuidString]
        )
    }
}
