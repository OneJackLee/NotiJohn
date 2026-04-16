import Foundation

/// Published when the user disables monitoring for a previously enabled app.
/// Subscribed by Unit 2 to stop capturing from that app.
public struct AppMonitoringDisabled: DomainEvent, Sendable {
    public let bundleId: BundleIdentifier
    public let occurredAt: Date

    public init(bundleId: BundleIdentifier, occurredAt: Date = Date()) {
        self.bundleId = bundleId
        self.occurredAt = occurredAt
    }
}
