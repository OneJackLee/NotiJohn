import Foundation

/// Handles the explicit notification-management commands: mark as read,
/// dismiss, and clear all. Each command loads (when needed), mutates,
/// persists, and publishes the resulting domain event.
///
/// The "clear all" command assumes the UI has already obtained user
/// confirmation (see `ClearAllConfirmationPolicy`).
public final class NotificationManagementAppService {
    private let repository: NotificationRepository
    private let eventBus: DomainEventBus

    public init(
        repository: NotificationRepository,
        eventBus: DomainEventBus
    ) {
        self.repository = repository
        self.eventBus = eventBus
    }

    /// Marks a single notification as read. Silently no-ops if the
    /// notification is missing (e.g., dismissed concurrently) or is already
    /// read (the aggregate's `markAsRead` returns `nil` in that case).
    public func markAsRead(id: NotificationId) async throws {
        guard let notification = await repository.findById(id) else { return }
        if let event = notification.markAsRead() {
            try await repository.save(notification)
            eventBus.publish(event)
        }
    }

    /// Permanently deletes a single notification. The aggregate's
    /// `dismiss()` always emits an event — the repository performs the
    /// actual deletion before the event is published.
    public func dismiss(id: NotificationId) async throws {
        guard let notification = await repository.findById(id) else { return }
        let event = notification.dismiss()
        try await repository.delete(id)
        eventBus.publish(event)
    }

    /// Deletes every stored notification. Skips the work (and the event)
    /// if the store was already empty so observers don't see a noisy
    /// `clearedCount: 0` notification.
    public func clearAll() async throws {
        let count = await repository.count()
        guard count > 0 else { return }
        let deletedCount = try await repository.deleteAll()
        eventBus.publish(
            AllNotificationsCleared(clearedCount: deletedCount, occurredAt: Date())
        )
    }
}
