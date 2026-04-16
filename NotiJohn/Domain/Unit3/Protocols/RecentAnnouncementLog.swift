import Foundation

/// Short-lived store of recently displayed banner fingerprints. Backs
/// `DuplicateSuppressionPolicy`. Implementations must be safe to call from
/// multiple threads — callers do not synchronize access externally.
public protocol RecentAnnouncementLog: AnyObject {
    /// Records that a banner with the given fingerprint was shown at the given
    /// timestamp.
    func record(fingerprint: NotificationFingerprint, at timestamp: Date)

    /// Returns true iff the fingerprint was recorded within the supplied
    /// window (measured against `Date()`).
    func hasBeenAnnounced(
        fingerprint: NotificationFingerprint,
        within window: DuplicateWindow
    ) -> Bool

    /// Drops entries whose timestamps fall outside the window. Called
    /// periodically to keep the in-memory map bounded.
    func purgeExpired(window: DuplicateWindow)
}
