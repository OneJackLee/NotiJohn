import Foundation

/// Published by Unit 4 after the user confirms "Clear All". The count lets
/// observers (analytics, UI badges) know the magnitude of the clear.
public struct AllNotificationsCleared: DomainEvent, Sendable {
    public let clearedCount: Int
    public let occurredAt: Date

    public init(clearedCount: Int, occurredAt: Date) {
        self.clearedCount = clearedCount
        self.occurredAt = occurredAt
    }
}
