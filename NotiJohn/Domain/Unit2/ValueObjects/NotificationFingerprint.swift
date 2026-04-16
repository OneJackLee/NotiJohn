import Foundation
import CryptoKit

/// Deterministic SHA-256 fingerprint of `bundleId | title | body`.
/// Used by Unit 3's duplicate suppression policy to recognize repeats
/// of the same notification within the announcement window.
public struct NotificationFingerprint: Hashable, Codable, Sendable {
    public let value: String

    public init(value: String) {
        self.value = value
    }

    /// Computes a stable hash for the supplied tuple. Inputs are joined with
    /// "|" — the separator is deliberately a character disallowed in bundle IDs.
    public static func compute(
        bundleId: BundleIdentifier,
        title: String,
        body: String
    ) -> NotificationFingerprint {
        let input = "\(bundleId.value)|\(title)|\(body)"
        let digest = SHA256.hash(data: Data(input.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return NotificationFingerprint(value: hex)
    }
}
