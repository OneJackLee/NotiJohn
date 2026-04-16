import Foundation

/// Thread-safe, in-memory implementation of `RecentAnnouncementLog`.
///
/// Synchronization uses a serial `DispatchQueue` rather than a lock so that
/// the type is straightforward to mark `@unchecked Sendable` — the underlying
/// dictionary is only ever touched while the queue is holding the call.
public final class InMemoryRecentAnnouncementLog: RecentAnnouncementLog, @unchecked Sendable {
    private var entries: [NotificationFingerprint: Date] = [:]
    private let queue = DispatchQueue(
        label: "com.onejacklee.notijohn.unit3.recentLog"
    )

    public init() {}

    public func record(fingerprint: NotificationFingerprint, at timestamp: Date) {
        queue.sync {
            entries[fingerprint] = timestamp
        }
    }

    public func hasBeenAnnounced(
        fingerprint: NotificationFingerprint,
        within window: DuplicateWindow
    ) -> Bool {
        queue.sync {
            guard let lastSeen = entries[fingerprint] else { return false }
            return Date().timeIntervalSince(lastSeen) <= window.seconds
        }
    }

    public func purgeExpired(window: DuplicateWindow) {
        queue.sync {
            let cutoff = Date().addingTimeInterval(-window.seconds)
            entries = entries.filter { $0.value > cutoff }
        }
    }
}
