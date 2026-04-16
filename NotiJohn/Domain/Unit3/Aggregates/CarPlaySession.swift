import Foundation

/// In-memory aggregate that tracks whether the app is currently presenting on
/// CarPlay. There is exactly one instance per app lifecycle; `start()` and
/// `end()` mutate it as the OS reports connection changes.
///
/// Persistence is intentionally absent — the OS owns the source of truth for
/// the physical connection, so any restart-time state would be stale.
public final class CarPlaySession {
    public let id: SessionId
    public private(set) var connectionState: ConnectionState
    public private(set) var connectedAt: Date?
    public private(set) var disconnectedAt: Date?

    public init() {
        self.id = SessionId()
        self.connectionState = .disconnected
        self.connectedAt = nil
        self.disconnectedAt = nil
    }

    /// Transitions to `.connected` and emits a domain event. Re-issuing
    /// `start()` overwrites previous timestamps — the OS will only call us
    /// again after a complete disconnect/reconnect cycle.
    public func start() -> CarPlaySessionStarted {
        let now = Date()
        connectionState = .connected
        connectedAt = now
        disconnectedAt = nil
        return CarPlaySessionStarted(
            sessionId: id,
            connectedAt: now,
            occurredAt: now
        )
    }

    /// Transitions to `.disconnected` and emits a domain event.
    public func end() -> CarPlaySessionEnded {
        let now = Date()
        connectionState = .disconnected
        disconnectedAt = now
        return CarPlaySessionEnded(
            sessionId: id,
            disconnectedAt: now,
            occurredAt: now
        )
    }

    public var isConnected: Bool { connectionState == .connected }
}
