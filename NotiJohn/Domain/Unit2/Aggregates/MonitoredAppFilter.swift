import Foundation

/// In-memory aggregate tracking which bundle IDs the user has opted to monitor.
/// Rebuilt on launch via Unit 1's `AppMonitoringEnabled` event replay; mutated
/// thereafter by the `Unit2Container` event subscriptions.
public final class MonitoredAppFilter {
    public private(set) var enabledBundleIds: Set<BundleIdentifier>

    public init(enabledBundleIds: Set<BundleIdentifier> = []) {
        self.enabledBundleIds = enabledBundleIds
    }

    public func addApp(bundleId: BundleIdentifier) {
        enabledBundleIds.insert(bundleId)
    }

    public func removeApp(bundleId: BundleIdentifier) {
        enabledBundleIds.remove(bundleId)
    }

    /// Pure query consulted by `AppFilterPolicy` before capture.
    public func shouldCapture(bundleId: BundleIdentifier) -> Bool {
        enabledBundleIds.contains(bundleId)
    }
}
