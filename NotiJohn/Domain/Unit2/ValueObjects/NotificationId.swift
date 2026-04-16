import Foundation

/// Strongly-typed UUID identifier for a `Notification` aggregate.
/// Crosses unit boundaries (Unit 4 references it for management operations).
public struct NotificationId: Hashable, Codable, Sendable {
    public let value: UUID

    /// Generates a fresh identifier — used by `Notification.capture`.
    public init() {
        self.value = UUID()
    }

    /// Re-hydrates an identifier from persisted storage.
    public init(_ uuid: UUID) {
        self.value = uuid
    }
}
