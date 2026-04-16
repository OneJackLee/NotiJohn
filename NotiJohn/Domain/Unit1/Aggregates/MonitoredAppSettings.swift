import Foundation

/// Aggregate root that owns the user's selection of apps to monitor for
/// notifications. Mutations return the domain events they produced; the
/// application service is responsible for publishing them on the bus.
public final class MonitoredAppSettings: Codable {
    public private(set) var monitoredApps: [MonitoredApp]

    public init(monitoredApps: [MonitoredApp] = []) {
        self.monitoredApps = monitoredApps
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case monitoredApps
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.monitoredApps = try container.decode([MonitoredApp].self, forKey: .monitoredApps)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(monitoredApps, forKey: .monitoredApps)
    }

    // MARK: - Queries

    /// Apps whose monitoring toggle is currently `true`.
    public var enabledApps: [MonitoredApp] {
        monitoredApps.filter { $0.isEnabled }
    }

    public func app(for bundleId: BundleIdentifier) -> MonitoredApp? {
        monitoredApps.first { $0.bundleId == bundleId }
    }

    // MARK: - Commands

    /// Enables monitoring for the given app, inserting it if it was not
    /// previously known. Returns the produced event, or `nil` if the app was
    /// already enabled (idempotent no-op).
    @discardableResult
    public func enableApp(appInfo: AppInfo) -> AppMonitoringEnabled? {
        if let index = monitoredApps.firstIndex(where: { $0.bundleId == appInfo.bundleId }) {
            // Refresh metadata in case display name / icon changed.
            monitoredApps[index].appInfo = appInfo
            guard !monitoredApps[index].isEnabled else { return nil }
            monitoredApps[index].isEnabled = true
        } else {
            monitoredApps.append(
                MonitoredApp(bundleId: appInfo.bundleId, appInfo: appInfo, isEnabled: true)
            )
        }
        return AppMonitoringEnabled(bundleId: appInfo.bundleId, appName: appInfo.displayName)
    }

    /// Disables monitoring for the given bundle id. Returns the produced
    /// event, or `nil` if the app was unknown / already disabled.
    @discardableResult
    public func disableApp(bundleId: BundleIdentifier) -> AppMonitoringDisabled? {
        guard let index = monitoredApps.firstIndex(where: { $0.bundleId == bundleId }) else {
            return nil
        }
        guard monitoredApps[index].isEnabled else { return nil }
        monitoredApps[index].isEnabled = false
        return AppMonitoringDisabled(bundleId: bundleId)
    }

    /// Reconciles the stored selection with the currently-installed apps:
    /// - Adds previously-unknown installed apps as disabled rows.
    /// - Removes monitored apps that are no longer installed, emitting a
    ///   `AppMonitoringDisabled` event for each that was previously enabled.
    @discardableResult
    public func syncInstalledApps(installed: [AppInfo]) -> [DomainEvent] {
        var events: [DomainEvent] = []
        let installedById = Dictionary(uniqueKeysWithValues: installed.map { ($0.bundleId, $0) })

        // Drop monitored apps that have been uninstalled.
        var retained: [MonitoredApp] = []
        for app in monitoredApps {
            if let refreshed = installedById[app.bundleId] {
                var updated = app
                updated.appInfo = refreshed
                retained.append(updated)
            } else if app.isEnabled {
                events.append(AppMonitoringDisabled(bundleId: app.bundleId))
            }
        }
        monitoredApps = retained

        // Append newly-installed apps that we have not seen before, defaulted
        // to disabled so the user explicitly opts in.
        let knownIds = Set(monitoredApps.map { $0.bundleId })
        for appInfo in installed where !knownIds.contains(appInfo.bundleId) {
            monitoredApps.append(
                MonitoredApp(bundleId: appInfo.bundleId, appInfo: appInfo, isEnabled: false)
            )
        }

        return events
    }
}
