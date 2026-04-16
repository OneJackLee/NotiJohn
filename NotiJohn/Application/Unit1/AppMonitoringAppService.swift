import Foundation

/// Orchestrates the app-selection use cases. Mediates between the
/// presentation layer and the `MonitoredAppSettings` aggregate, handling
/// persistence and event publication.
public final class AppMonitoringAppService {
    private let settingsRepo: MonitoredAppSettingsRepository
    private let discoveryService: InstalledAppDiscoveryService
    private let eventBus: DomainEventBus

    public init(
        settingsRepo: MonitoredAppSettingsRepository,
        discoveryService: InstalledAppDiscoveryService,
        eventBus: DomainEventBus
    ) {
        self.settingsRepo = settingsRepo
        self.discoveryService = discoveryService
        self.eventBus = eventBus
    }

    /// Returns the curated list of apps the user may choose to monitor.
    public func loadInstalledApps() async -> [AppInfo] {
        await discoveryService.discoverApps()
    }

    /// Returns the persisted `MonitoredAppSettings`.
    public func loadSettings() async -> MonitoredAppSettings {
        await settingsRepo.get()
    }

    /// Enables monitoring for the given app: load → mutate → save → publish.
    public func enableApp(_ appInfo: AppInfo) async throws {
        let settings = await settingsRepo.get()
        let event = settings.enableApp(appInfo: appInfo)
        try await settingsRepo.save(settings)
        if let event {
            eventBus.publish(event)
        }
    }

    /// Disables monitoring for the given bundle id.
    public func disableApp(_ bundleId: BundleIdentifier) async throws {
        let settings = await settingsRepo.get()
        let event = settings.disableApp(bundleId: bundleId)
        try await settingsRepo.save(settings)
        if let event {
            eventBus.publish(event)
        }
    }

    /// Re-broadcasts `AppMonitoringEnabled` for every app currently flagged as
    /// enabled in persisted settings. Must be called once at app launch so
    /// `MonitoredAppFilter` (in-memory, lives only for the process lifetime)
    /// gets populated to match the user's previous selections — otherwise
    /// every incoming notification is silently dropped on cold start.
    public func republishCurrentSettings() async {
        let settings = await settingsRepo.get()
        let now = Date()
        for app in settings.monitoredApps where app.isEnabled {
            eventBus.publish(AppMonitoringEnabled(
                bundleId: app.bundleId,
                appName: app.appInfo.displayName,
                occurredAt: now
            ))
        }
    }

    /// Reconciles the persisted selection with the currently-installed apps,
    /// publishing `AppMonitoringDisabled` events for any uninstalled apps.
    @discardableResult
    public func syncWithInstalledApps() async throws -> MonitoredAppSettings {
        let installed = await discoveryService.discoverApps()
        let settings = await settingsRepo.get()
        let events = settings.syncInstalledApps(installed: installed)
        try await settingsRepo.save(settings)
        for event in events {
            eventBus.publish(event)
        }
        return settings
    }
}
