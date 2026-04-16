import Foundation

/// Thrown when the requested notification is no longer in the repository
/// (deleted between the user's tap on the list and the detail load).
public struct NotificationNotFoundError: Error {
    public let id: NotificationId

    public init(id: NotificationId) {
        self.id = id
    }
}

/// Loads a single notification's detail and applies the
/// `AutoMarkAsReadOnViewPolicy` as a side effect.
///
/// The flow is: `findById` → `policy.apply` → (if newly read) `save` +
/// publish `NotificationMarkedAsRead` → return projection. The projection is
/// returned regardless of whether a status transition occurred.
public final class NotificationDetailAppService {
    private let repository: NotificationRepository
    private let markAsReadPolicy: AutoMarkAsReadOnViewPolicy
    private let eventBus: DomainEventBus

    public init(
        repository: NotificationRepository,
        markAsReadPolicy: AutoMarkAsReadOnViewPolicy,
        eventBus: DomainEventBus
    ) {
        self.repository = repository
        self.markAsReadPolicy = markAsReadPolicy
        self.eventBus = eventBus
    }

    /// Loads the notification, transparently marks it as read, and returns
    /// the read-optimized `NotificationDetail` for the template builder.
    public func viewNotificationDetail(id: NotificationId) async throws -> NotificationDetail {
        guard let notification = await repository.findById(id) else {
            throw NotificationNotFoundError(id: id)
        }

        if let event = markAsReadPolicy.apply(to: notification) {
            try await repository.save(notification)
            eventBus.publish(event)
        }

        return NotificationDetail.from(notification)
    }
}
