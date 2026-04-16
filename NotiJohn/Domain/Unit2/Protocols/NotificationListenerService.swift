import Foundation

/// Boundary for the OS-side notification source. Production implementations
/// would observe `UNUserNotificationCenter` or a Notification Service Extension;
/// the in-app stub simply exposes `simulateNotification` for development.
public protocol NotificationListenerService: AnyObject {
    func startListening()
    func stopListening()
}
