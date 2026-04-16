import Foundation

/// Caps total persisted notifications. Default cap is 100 (set by the DI
/// container). Pure value type — `prunableCount` is a stateless calculation.
public struct StorageCapPolicy {
    public let maxNotifications: Int

    public init(maxNotifications: Int) {
        self.maxNotifications = maxNotifications
    }

    /// Returns how many notifications must be removed to satisfy the cap.
    public func prunableCount(currentCount: Int) -> Int {
        max(0, currentCount - maxNotifications)
    }
}
