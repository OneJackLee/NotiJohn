import Foundation

/// Published after the storage cap policy has trimmed the oldest notifications.
/// Unit 4 listens to refresh its list. `oldestRemainingTimestamp` is `nil` only
/// in the edge case where pruning emptied the store entirely.
public struct NotificationsPruned: DomainEvent, Sendable {
    public let prunedCount: Int
    public let oldestRemainingTimestamp: CaptureTimestamp?
    public let occurredAt: Date

    public init(
        prunedCount: Int,
        oldestRemainingTimestamp: CaptureTimestamp?,
        occurredAt: Date
    ) {
        self.prunedCount = prunedCount
        self.oldestRemainingTimestamp = oldestRemainingTimestamp
        self.occurredAt = occurredAt
    }
}
