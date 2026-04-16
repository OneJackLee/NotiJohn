import Foundation

/// Tri-state representation of the user's notification permission grant.
public enum PermissionStatus: String, Codable, Sendable {
    case notDetermined
    case granted
    case denied
}
