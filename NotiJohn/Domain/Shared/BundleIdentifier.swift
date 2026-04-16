import Foundation

/// Reverse-DNS bundle identifier of an iOS app. Shared across all units.
public struct BundleIdentifier: Hashable, Codable, Sendable {
    public let value: String

    public init?(_ value: String) {
        guard !value.isEmpty else { return nil }
        self.value = value
    }

    /// Forced initializer for trusted internal sources (e.g. system APIs).
    public init(unchecked value: String) {
        self.value = value
    }
}

extension BundleIdentifier: CustomStringConvertible {
    public var description: String { value }
}
