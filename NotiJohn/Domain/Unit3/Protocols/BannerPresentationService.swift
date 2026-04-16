import Foundation

/// Abstraction over the platform mechanism used to render a transient banner
/// on the CarPlay screen. The production implementation routes through
/// `UNUserNotificationCenter`; tests can substitute a recording double.
public protocol BannerPresentationService: AnyObject, Sendable {
    /// Shows the banner. Implementations should return as soon as the system
    /// has accepted the request — actual rendering is OS-driven.
    func show(banner: NotificationBanner) async

    /// Removes a previously displayed banner identified by `notificationId`.
    /// Safe to call even if the banner has already been dismissed.
    func dismiss(notificationId: NotificationId) async
}
