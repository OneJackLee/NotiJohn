import Foundation

/// A single app entry within the `MonitoredAppSettings` aggregate.
/// Identified within the aggregate by its `bundleId`.
public struct MonitoredApp: Identifiable, Hashable, Codable, Sendable {
    public let bundleId: BundleIdentifier
    public var appInfo: AppInfo
    public var isEnabled: Bool

    public var id: BundleIdentifier { bundleId }

    public init(bundleId: BundleIdentifier, appInfo: AppInfo, isEnabled: Bool) {
        self.bundleId = bundleId
        self.appInfo = appInfo
        self.isEnabled = isEnabled
    }
}
