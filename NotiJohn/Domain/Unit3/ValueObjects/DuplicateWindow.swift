import Foundation

/// Time window during which a fingerprint, once banner-displayed, will
/// suppress subsequent banner displays of the same notification.
public struct DuplicateWindow: Hashable, Sendable {
    public let seconds: TimeInterval

    /// Project default — 30 seconds, matching the spec in `interactions.md`.
    public static let `default` = DuplicateWindow(seconds: 30)

    public init(seconds: TimeInterval) {
        precondition(seconds > 0, "Duplicate window must be positive")
        self.seconds = seconds
    }
}
