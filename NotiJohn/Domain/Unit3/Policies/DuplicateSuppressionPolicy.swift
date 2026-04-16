import Foundation

/// Stateless decision object that asks the underlying `RecentAnnouncementLog`
/// whether a given fingerprint has been shown inside `window`. Holds no state
/// of its own — the log is the only mutable collaborator.
public struct DuplicateSuppressionPolicy {
    public let recentLog: RecentAnnouncementLog
    public let window: DuplicateWindow

    public init(recentLog: RecentAnnouncementLog, window: DuplicateWindow) {
        self.recentLog = recentLog
        self.window = window
    }

    /// Returns true iff the fingerprint was announced inside the policy's
    /// window. `timestamp` is currently informational — implementations
    /// compare against `Date()` to honor wall-clock semantics.
    public func isDuplicate(
        fingerprint: NotificationFingerprint,
        at timestamp: Date
    ) -> Bool {
        recentLog.hasBeenAnnounced(fingerprint: fingerprint, within: window)
    }

    /// Records that a banner for `fingerprint` was shown at `timestamp`.
    public func recordDisplay(
        fingerprint: NotificationFingerprint,
        at timestamp: Date
    ) {
        recentLog.record(fingerprint: fingerprint, at: timestamp)
    }
}
