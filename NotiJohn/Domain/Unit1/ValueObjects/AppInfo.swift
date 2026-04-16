import Foundation

/// Display metadata for an installed iOS application that may be monitored
/// for notifications. Identified within the domain by its `bundleId`.
public struct AppInfo: Hashable, Codable, Sendable {
    public let bundleId: BundleIdentifier
    public let displayName: String
    public let iconData: Data?

    public init(bundleId: BundleIdentifier, displayName: String, iconData: Data? = nil) {
        self.bundleId = bundleId
        self.displayName = displayName
        self.iconData = iconData
    }
}
