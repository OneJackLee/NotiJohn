import Foundation

/// Title + body text of a captured notification. Both fields are user-visible
/// and may be empty for content-less alerts.
public struct NotificationContent: Hashable, Codable, Sendable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}
