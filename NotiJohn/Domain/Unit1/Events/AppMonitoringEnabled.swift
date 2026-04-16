import Foundation

/// Published when the user enables monitoring for a specific app.
/// Subscribed by Unit 2 (`MonitoredAppFilter`) to begin capturing notifications
/// from that app.
public struct AppMonitoringEnabled: DomainEvent, Sendable {
    public let bundleId: BundleIdentifier
    public let appName: String
    public let occurredAt: Date

    public init(bundleId: BundleIdentifier, appName: String, occurredAt: Date = Date()) {
        self.bundleId = bundleId
        self.appName = appName
        self.occurredAt = occurredAt
    }
}
