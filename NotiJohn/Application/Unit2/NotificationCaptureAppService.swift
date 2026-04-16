import Foundation

/// Orchestrates the notification capture pipeline:
///   filter check → aggregate creation → persist → enforce cap → publish.
///
/// The constructor signature is fixed by `Unit2Container`: do not add or
/// rearrange required parameters. The `AppFilterPolicy` is built internally
/// from the supplied `MonitoredAppFilter`. A `NotificationDispatcher` is
/// instantiated as a documented integration seam — in single-process mode it
/// is a no-op because `eventBus.publish` already reaches Units 3 and 4.
public final class NotificationCaptureAppService {
    private let filter: MonitoredAppFilter
    private let filterPolicy: AppFilterPolicy
    private let storageCapPolicy: StorageCapPolicy
    private let repository: NotificationRepository
    private let eventBus: DomainEventBus
    private let dispatcher: NotificationDispatcher

    public init(
        filter: MonitoredAppFilter,
        storageCapPolicy: StorageCapPolicy,
        repository: NotificationRepository,
        eventBus: DomainEventBus
    ) {
        self.filter = filter
        self.filterPolicy = AppFilterPolicy(filter: filter)
        self.storageCapPolicy = storageCapPolicy
        self.repository = repository
        self.eventBus = eventBus
        self.dispatcher = NotificationDispatcherImpl(eventBus: eventBus)
    }

    /// Entry point invoked by `NotificationListenerService` whenever a raw
    /// notification arrives. Errors are propagated so callers can decide
    /// whether to log/retry.
    public func handleIncomingNotification(
        bundleId: BundleIdentifier,
        appName: String,
        appIcon: Data?,
        title: String,
        body: String
    ) async throws {
        // 1. App filter — drop notifications from apps the user hasn't enabled.
        guard filterPolicy.shouldCapture(bundleId: bundleId) else {
            #if DEBUG
            print("[NotiJohn] Capture rejected — \(bundleId.value) not in MonitoredAppFilter. Enable it in Settings, or it'll never appear.")
            #endif
            return
        }

        // 2. Build the aggregate + the corresponding domain event.
        let sourceApp = SourceApp(bundleId: bundleId, appName: appName, appIcon: appIcon)
        let content = NotificationContent(title: title, body: body)
        let (notification, event) = Notification.capture(
            sourceApp: sourceApp,
            content: content,
            timestamp: Date()
        )

        // 3. Persist before announcing — Units 3/4 must be able to read it.
        try await repository.save(notification)

        // 4. Enforce the storage cap. Pruning is best-effort: if it succeeds
        //    we publish so Unit 4 can refresh; failure is rethrown.
        let currentCount = await repository.count()
        let toPrune = storageCapPolicy.prunableCount(currentCount: currentCount)
        if toPrune > 0 {
            let pruned = try await repository.pruneOldest(exceeding: storageCapPolicy.maxNotifications)
            if pruned > 0 {
                let oldestRemaining = await repository.oldestRemainingTimestamp()
                eventBus.publish(NotificationsPruned(
                    prunedCount: pruned,
                    oldestRemainingTimestamp: oldestRemaining,
                    occurredAt: Date()
                ))
            }
        }

        // 5. Announce capture. Single-process dispatcher is a no-op; the bus
        //    publish above is what actually reaches Units 3 and 4.
        eventBus.publish(event)
        dispatcher.dispatch(event: event)
    }
}
