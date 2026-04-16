import Foundation

/// Published when the OS reports CarPlay has connected and `CarPlaySession`
/// has transitioned to `.connected`. Other units may use this to begin
/// foregrounded behaviors.
public struct CarPlaySessionStarted: DomainEvent, Sendable {
    public let sessionId: SessionId
    public let connectedAt: Date
    public let occurredAt: Date

    public init(sessionId: SessionId, connectedAt: Date, occurredAt: Date) {
        self.sessionId = sessionId
        self.connectedAt = connectedAt
        self.occurredAt = occurredAt
    }
}
