import Foundation

/// `UserDefaults`-backed repository for `MonitoredAppSettings`.
///
/// Uses the shared App Group container so the data is also visible to the
/// Notification Service Extension (which needs to know which apps the user
/// has opted in to monitor).
public final class UserDefaultsSettingsRepository: MonitoredAppSettingsRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "monitored_app_settings"

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
            ?? UserDefaults(suiteName: "group.com.onejacklee.notijohn")
            ?? .standard
    }

    public func get() async -> MonitoredAppSettings {
        guard let data = defaults.data(forKey: key) else {
            return MonitoredAppSettings()
        }
        do {
            return try JSONDecoder().decode(MonitoredAppSettings.self, from: data)
        } catch {
            // Treat decoding failures (e.g. schema migration) as "no data".
            return MonitoredAppSettings()
        }
    }

    public func save(_ settings: MonitoredAppSettings) async throws {
        let data = try JSONEncoder().encode(settings)
        defaults.set(data, forKey: key)
    }
}
