import Foundation

/// Published when the OS reports CarPlay has disconnected and the session has
/// transitioned to `.disconnected`. Unit 3 stops presenting banners; other
/// units may use this to flush state.
public struct CarPlaySessionEnded: DomainEvent, Sendable {
    public let sessionId: SessionId
    public let disconnectedAt: Date
    public let occurredAt: Date

    public init(sessionId: SessionId, disconnectedAt: Date, occurredAt: Date) {
        self.sessionId = sessionId
        self.disconnectedAt = disconnectedAt
        self.occurredAt = occurredAt
    }
}
