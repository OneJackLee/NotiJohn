import Foundation

/// Tracks whether the user has viewed a notification on the CarPlay UI.
/// Persisted as the raw string ("unread" / "read") via SwiftData.
public enum ReadStatus: String, Codable, Sendable {
    case unread
    case read
}
