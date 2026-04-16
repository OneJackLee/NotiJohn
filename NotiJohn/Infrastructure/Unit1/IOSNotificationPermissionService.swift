import Foundation
import UserNotifications

/// `UNUserNotificationCenter`-backed implementation of the permission domain
/// service. All work is dispatched to the notification center's own queues.
public final class IOSNotificationPermissionService: NotificationPermissionService, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func requestPermission() async -> PermissionStatus {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            // Re-query so we observe the canonical post-prompt status.
            return await checkCurrentStatus().resolved(forRequestedGrant: granted)
        } catch {
            return .denied
        }
    }

    public func checkCurrentStatus() async -> PermissionStatus {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            return .granted
        @unknown default:
            return .notDetermined
        }
    }
}

private extension PermissionStatus {
    /// If the OS reports `.notDetermined` immediately after a request (rare),
    /// fall back to the boolean grant returned by `requestAuthorization`.
    func resolved(forRequestedGrant granted: Bool) -> PermissionStatus {
        if self == .notDetermined {
            return granted ? .granted : .denied
        }
        return self
    }
}
