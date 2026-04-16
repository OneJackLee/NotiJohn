import Foundation

/// Domain-facing wrapper around the iOS notification permission system.
public protocol NotificationPermissionService: AnyObject, Sendable {
    /// Triggers the iOS permission prompt (if not yet determined) and
    /// returns the resulting status.
    func requestPermission() async -> PermissionStatus

    /// Returns the current authorization status without prompting the user.
    func checkCurrentStatus() async -> PermissionStatus
}
