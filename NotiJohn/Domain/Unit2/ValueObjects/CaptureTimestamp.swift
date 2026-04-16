import Foundation

/// Wraps the moment a notification was captured. Comparable so that callers
/// can sort or compute "oldest remaining" without leaking `Date` semantics.
public struct CaptureTimestamp: Hashable, Codable, Comparable, Sendable {
    public let value: Date

    public init(_ value: Date) {
        self.value = value
    }

    public static func < (lhs: CaptureTimestamp, rhs: CaptureTimestamp) -> Bool {
        lhs.value < rhs.value
    }
}
