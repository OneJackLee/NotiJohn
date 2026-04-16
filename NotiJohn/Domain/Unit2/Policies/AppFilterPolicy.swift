import Foundation

/// Thin named policy that delegates to `MonitoredAppFilter.shouldCapture`.
/// Exists so `NotificationCaptureAppService` reads as a self-documenting
/// pipeline (filter check → capture → persist → cap → publish).
public struct AppFilterPolicy {
    public let filter: MonitoredAppFilter

    public init(filter: MonitoredAppFilter) {
        self.filter = filter
    }

    public func shouldCapture(bundleId: BundleIdentifier) -> Bool {
        filter.shouldCapture(bundleId: bundleId)
    }
}
