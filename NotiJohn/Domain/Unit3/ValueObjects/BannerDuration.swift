import Foundation

/// How long a transient banner remains on the CarPlay screen before
/// `BannerAppService` removes the delivered system notification.
public struct BannerDuration: Hashable, Sendable {
    public let seconds: TimeInterval

    /// Project default — 5 seconds, matching the spec in `interactions.md`.
    public static let `default` = BannerDuration(seconds: 5)

    public init(seconds: TimeInterval) {
        precondition(seconds > 0, "Banner duration must be positive")
        self.seconds = seconds
    }
}
