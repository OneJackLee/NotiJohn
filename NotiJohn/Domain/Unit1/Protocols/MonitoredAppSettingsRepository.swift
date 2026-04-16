import Foundation

/// Persists and retrieves the singleton `MonitoredAppSettings` aggregate.
public protocol MonitoredAppSettingsRepository: AnyObject, Sendable {
    /// Returns the persisted settings, or a fresh empty aggregate on first run.
    func get() async -> MonitoredAppSettings

    /// Persists the given aggregate, overwriting any prior state.
    func save(_ settings: MonitoredAppSettings) async throws
}
