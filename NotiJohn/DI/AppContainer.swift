import Foundation
import SwiftData
import Observation

/// Top-level DI container. Owns the single shared `DomainEventBus`, the
/// SwiftData `ModelContainer`, and instantiates all per-unit containers,
/// wiring cross-unit dependencies.
@Observable
public final class AppContainer {
    public let eventBus: DomainEventBus
    public let modelContainer: ModelContainer

    public let unit1: Unit1Container
    public let unit2: Unit2Container
    public let unit3: Unit3Container
    public let unit4: Unit4Container

    public init() {
        let bus = CombineDomainEventBus()
        self.eventBus = bus

        // SwiftData container — schema includes Unit 2's NotificationModel.
        do {
            self.modelContainer = try ModelContainer(
                for: NotificationModel.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        let modelContext = ModelContext(self.modelContainer)

        self.unit1 = Unit1Container(eventBus: bus)
        self.unit2 = Unit2Container(eventBus: bus, modelContext: modelContext)
        self.unit3 = Unit3Container(eventBus: bus)
        self.unit4 = Unit4Container(
            eventBus: bus,
            repository: unit2.notificationRepo,
            queryService: unit2.queryService
        )

        // Wire cross-unit subscriptions.
        unit2.startEventSubscriptions()
        unit3.startEventSubscriptions()

        // Rehydrate Unit 2's in-memory `MonitoredAppFilter` from Unit 1's
        // persisted selections. Without this, every cold launch starts with
        // an empty filter and silently drops all incoming notifications.
        // Fire-and-forget — completes in microseconds; no UI work depends
        // on it before the user can interact.
        Task { await unit1.appMonitoringService.republishCurrentSettings() }

        // Register the CarPlay-eligible notification category. Must happen
        // before any banner is posted, otherwise the system will fall back to
        // the default category which is not surfaced on the CarPlay screen.
        unit3.bannerService.registerCategories()

        // Hand the CarPlay scene delegate (instantiated by UIKit, not DI) the
        // collaborators it needs. Must run before CarPlay connects.
        CarPlaySceneDelegate.sceneServices = .init(
            lifecycleAdapter: unit3.lifecycleAdapter,
            templateManager: unit4.templateManager
        )

        // Start the (stub) notification listener so the engine begins capturing.
        unit2.listener.startListening()
    }
}
