import Foundation

/// DI container for Unit 4 (CarPlay Notification Management).
///
/// Receives the shared `DomainEventBus` plus Unit 2's `NotificationRepository`
/// and `NotificationQueryService` from `AppContainer` — Unit 4 owns no
/// persistence of its own. Lazily wires the policy, three application
/// services, three template builders, and the coordinating
/// `CarPlayTemplateManager`.
///
/// The `templateManager` lazy initializer assigns itself back into
/// `listBuilder.templateManager` (a `weak` property) so the list's tap and
/// "Clear All" handlers can drive navigation without a retain cycle.
public final class Unit4Container {
    public let eventBus: DomainEventBus
    public let repository: NotificationRepository
    public let queryService: NotificationQueryService

    public init(
        eventBus: DomainEventBus,
        repository: NotificationRepository,
        queryService: NotificationQueryService
    ) {
        self.eventBus = eventBus
        self.repository = repository
        self.queryService = queryService
    }

    // MARK: - Domain

    public lazy var markAsReadPolicy: AutoMarkAsReadOnViewPolicy = AutoMarkAsReadOnViewPolicy()

    // MARK: - Application

    public lazy var listService: NotificationListAppService = NotificationListAppService(
        queryService: queryService,
        eventBus: eventBus
    )

    public lazy var detailService: NotificationDetailAppService = NotificationDetailAppService(
        repository: repository,
        markAsReadPolicy: markAsReadPolicy,
        eventBus: eventBus
    )

    public lazy var managementService: NotificationManagementAppService = NotificationManagementAppService(
        repository: repository,
        eventBus: eventBus
    )

    // MARK: - Presentation

    public lazy var listBuilder: NotificationListTemplateBuilder = NotificationListTemplateBuilder(
        listService: listService,
        managementService: managementService
    )

    public lazy var detailBuilder: NotificationDetailTemplateBuilder = NotificationDetailTemplateBuilder(
        detailService: detailService
    )

    public lazy var clearAllBuilder: ClearAllConfirmationBuilder = ClearAllConfirmationBuilder(
        managementService: managementService
    )

    /// Closure-based lazy init so that `listBuilder.templateManager = manager`
    /// runs immediately after construction. The back-reference is `weak`, so
    /// the manager's lifetime is governed solely by this container.
    public lazy var templateManager: CarPlayTemplateManager = {
        let manager = CarPlayTemplateManager(
            listBuilder: listBuilder,
            detailBuilder: detailBuilder,
            clearAllBuilder: clearAllBuilder
        )
        listBuilder.templateManager = manager
        return manager
    }()
}
