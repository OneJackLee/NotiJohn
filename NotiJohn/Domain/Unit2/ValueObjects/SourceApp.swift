import Foundation

/// Describes the iOS app that emitted a captured notification.
/// Travels with `NotificationCaptured` events to Units 3 and 4.
public struct SourceApp: Hashable, Codable, Sendable {
    public let bundleId: BundleIdentifier
    public let appName: String
    public let appIcon: Data?

    public init(bundleId: BundleIdentifier, appName: String, appIcon: Data?) {
        self.bundleId = bundleId
        self.appName = appName
        self.appIcon = appIcon
    }
}
