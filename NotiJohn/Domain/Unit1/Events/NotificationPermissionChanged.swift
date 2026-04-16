import Foundation

/// Published when the user-facing notification permission status changes,
/// either as a result of the iOS system prompt or after returning from
/// the iOS Settings app.
public struct NotificationPermissionChanged: DomainEvent, Sendable {
    public let newStatus: PermissionStatus
    public let occurredAt: Date

    public init(newStatus: PermissionStatus, occurredAt: Date = Date()) {
        self.newStatus = newStatus
        self.occurredAt = occurredAt
    }
}
