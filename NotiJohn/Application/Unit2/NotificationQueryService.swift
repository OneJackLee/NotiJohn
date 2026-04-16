import Foundation

/// Read-only convenience facade over `NotificationRepository`.
/// Shared with Unit 4 (CarPlay management UI) via `Unit2Container.queryService`.
public final class NotificationQueryService {
    private let repository: NotificationRepository

    public init(repository: NotificationRepository) {
        self.repository = repository
    }

    /// Most-recent-first list for the CarPlay notification list template.
    public func fetchAll() async -> [Notification] {
        await repository.findAll(sortedBy: .mostRecent)
    }

    public func fetchById(_ id: NotificationId) async -> Notification? {
        await repository.findById(id)
    }

    public func fetchUnreadCount() async -> Int {
        let unread = await repository.findAllUnread()
        return unread.count
    }
}
