import Foundation
import Observation

/// View model for the post-onboarding `SettingsView` app list.
@Observable
@MainActor
public final class AppSelectionViewModel {
    private let appMonitoringService: AppMonitoringAppService
    private let permissionService: NotificationPermissionService

    // MARK: - Observed state

    public var monitoredApps: [MonitoredApp] = []
    public var permissionStatus: PermissionStatus = .notDetermined
    public var isLoading: Bool = false
    public var lastErrorMessage: String?

    public init(
        appMonitoringService: AppMonitoringAppService,
        permissionService: NotificationPermissionService
    ) {
        self.appMonitoringService = appMonitoringService
        self.permissionService = permissionService
    }

    // MARK: - Lifecycle

    /// Loads the persisted selection, reconciles with installed apps, and
    /// fetches the current permission status.
    public func onAppear() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let synced = try await appMonitoringService.syncWithInstalledApps()
            monitoredApps = sorted(synced.monitoredApps)
        } catch {
            // Fall back to whatever is currently persisted.
            let settings = await appMonitoringService.loadSettings()
            monitoredApps = sorted(settings.monitoredApps)
            lastErrorMessage = "Could not refresh app list: \(error.localizedDescription)"
        }
        permissionStatus = await permissionService.checkCurrentStatus()
    }

    /// Re-checks permission status when the app returns to the foreground.
    public func refreshPermissionStatus() async {
        permissionStatus = await permissionService.checkCurrentStatus()
    }

    // MARK: - Actions

    /// Toggles the given monitored app, applying an optimistic UI update.
    public func toggleApp(_ app: MonitoredApp) async {
        let newValue = !app.isEnabled
        // Optimistic update.
        if let index = monitoredApps.firstIndex(where: { $0.bundleId == app.bundleId }) {
            monitoredApps[index].isEnabled = newValue
        }
        do {
            if newValue {
                try await appMonitoringService.enableApp(app.appInfo)
            } else {
                try await appMonitoringService.disableApp(app.bundleId)
            }
        } catch {
            // Revert on failure.
            if let index = monitoredApps.firstIndex(where: { $0.bundleId == app.bundleId }) {
                monitoredApps[index].isEnabled = !newValue
            }
            lastErrorMessage = "Could not update selection: \(error.localizedDescription)"
        }
    }

    private func sorted(_ apps: [MonitoredApp]) -> [MonitoredApp] {
        apps.sorted { lhs, rhs in
            lhs.appInfo.displayName.localizedCaseInsensitiveCompare(rhs.appInfo.displayName) == .orderedAscending
        }
    }
}
