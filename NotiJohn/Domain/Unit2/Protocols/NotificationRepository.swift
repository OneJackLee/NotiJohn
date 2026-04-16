import Foundation

/// Sort order for repository queries. Currently only `.mostRecent` is needed,
/// but the enum keeps the API extensible without changing call sites.
public enum NotificationSortOrder: Sendable {
    case mostRecent
}

/// Persistence boundary for `Notification` aggregates. Implemented by
/// `SwiftDataNotificationRepository` and shared with Unit 4 via `Unit2Container`.
public protocol NotificationRepository: AnyObject {
    // Write operations (capture pipeline)
    func save(_ notification: Notification) async throws
    func pruneOldest(exceeding limit: Int) async throws -> Int

    // Read operations (Unit 4 / query service)
    func findById(_ id: NotificationId) async -> Notification?
    func findAll(sortedBy: NotificationSortOrder) async -> [Notification]
    func findAllUnread() async -> [Notification]
    func count() async -> Int

    /// Returns the timestamp of the oldest surviving notification — used to
    /// populate `NotificationsPruned.oldestRemainingTimestamp`.
    func oldestRemainingTimestamp() async -> CaptureTimestamp?

    // Delete operations (Unit 4 management)
    func delete(_ id: NotificationId) async throws
    func deleteAll() async throws -> Int
}
