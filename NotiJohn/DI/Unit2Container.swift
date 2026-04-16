import Foundation
import Combine
import SwiftData

/// DI container for Unit 2 (Notification Engine).
///
/// Wires the in-memory `MonitoredAppFilter`, the SwiftData-backed repository,
/// the capture/query services, and the development listener stub. Also
/// subscribes to Unit 1's `AppMonitoringEnabled` / `AppMonitoringDisabled`
/// events so the filter stays in sync with the user's app selections.
public final class Unit2Container {
    public let eventBus: DomainEventBus
    public let modelContext: ModelContext

    /// Combine cancellables for the Unit 1 → Unit 2 event subscriptions.
    /// Held for the lifetime of the container.
    private var cancellables = Set<AnyCancellable>()

    public init(eventBus: DomainEventBus, modelContext: ModelContext) {
        self.eventBus = eventBus
        self.modelContext = modelContext
    }

    // MARK: - Domain

    public lazy var monitoredAppFilter: MonitoredAppFilter = MonitoredAppFilter()
    public lazy var storageCapPolicy: StorageCapPolicy = StorageCapPolicy(maxNotifications: 100)

    // MARK: - Infrastructure

    public lazy var notificationRepo: NotificationRepository = SwiftDataNotificationRepository(modelContext: modelContext)
    public lazy var listener: NotificationListenerService = StubNotificationListenerService(captureService: captureService)

    // MARK: - Application

    public lazy var captureService: NotificationCaptureAppService = NotificationCaptureAppService(
        filter: monitoredAppFilter,
        storageCapPolicy: storageCapPolicy,
        repository: notificationRepo,
        eventBus: eventBus
    )

    public lazy var queryService: NotificationQueryService = NotificationQueryService(repository: notificationRepo)

    // MARK: - Event subscriptions

    /// Wires subscriptions to Unit 1 events (`AppMonitoringEnabled` /
    /// `AppMonitoringDisabled`) to keep `MonitoredAppFilter` in sync with
    /// the user's app selections. Idempotent only in the sense that calling
    /// it twice produces duplicate subscriptions — invoke once at startup.
    public func startEventSubscriptions() {
        let filter = monitoredAppFilter

        eventBus.subscribe(to: AppMonitoringEnabled.self)
            .sink { [weak filter] event in
                filter?.addApp(bundleId: event.bundleId)
            }
            .store(in: &cancellables)

        eventBus.subscribe(to: AppMonitoringDisabled.self)
            .sink { [weak filter] event in
                filter?.removeApp(bundleId: event.bundleId)
            }
            .store(in: &cancellables)
    }
}
