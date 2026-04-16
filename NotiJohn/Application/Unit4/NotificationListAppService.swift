import Foundation
import Combine

/// Provides data and change notifications for the CarPlay notification list.
///
/// Reads through Unit 2's `NotificationQueryService` (no direct repository
/// access) and merges the five notification-affecting domain events into a
/// single `Void` publisher that the template builder can subscribe to.
public final class NotificationListAppService {
    private let queryService: NotificationQueryService
    private let eventBus: DomainEventBus

    public init(
        queryService: NotificationQueryService,
        eventBus: DomainEventBus
    ) {
        self.queryService = queryService
        self.eventBus = eventBus
    }

    /// Loads all notifications and projects them to summaries for list display.
    /// Sort order is owned by the query service (most-recent-first per Unit 2).
    public func fetchNotificationList() async -> [NotificationSummary] {
        let notifications = await queryService.fetchAll()
        return notifications.map { NotificationSummary.from($0) }
    }

    /// Single `Void` stream emitted whenever the list's contents may have
    /// changed. Subscribers re-fetch in response — payloads are intentionally
    /// dropped because the template builder always renders the full list.
    public func observeListChanges() -> AnyPublisher<Void, Never> {
        // Erase each typed stream to `AnyPublisher<Void, Never>` so they share a
        // common type — `MergeMany` requires all inputs to be the same Publisher.
        let captured = eventBus.subscribe(to: NotificationCaptured.self).map { _ in () }.eraseToAnyPublisher()
        let read = eventBus.subscribe(to: NotificationMarkedAsRead.self).map { _ in () }.eraseToAnyPublisher()
        let dismissed = eventBus.subscribe(to: NotificationDismissed.self).map { _ in () }.eraseToAnyPublisher()
        let cleared = eventBus.subscribe(to: AllNotificationsCleared.self).map { _ in () }.eraseToAnyPublisher()
        let pruned = eventBus.subscribe(to: NotificationsPruned.self).map { _ in () }.eraseToAnyPublisher()

        return Publishers.MergeMany([captured, read, dismissed, cleared, pruned])
            .eraseToAnyPublisher()
    }
}
