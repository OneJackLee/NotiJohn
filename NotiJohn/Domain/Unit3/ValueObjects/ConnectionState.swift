import Foundation

/// Whether the app is currently presenting on a CarPlay head unit.
/// `IncomingNotificationHandler` consults this on every captured notification
/// so banners are silently dropped when the car display is not active.
public enum ConnectionState: String, Sendable {
    case connected
    case disconnected
}
