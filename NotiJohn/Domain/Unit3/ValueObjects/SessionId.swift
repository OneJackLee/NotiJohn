import Foundation

/// Strongly-typed identifier for a `CarPlaySession` instance.
/// A new identifier is minted every time the OS reports a CarPlay connection.
public struct SessionId: Hashable, Sendable {
    public let value: UUID

    /// Generates a fresh identifier for a brand-new session.
    public init() {
        self.value = UUID()
    }

    /// Re-hydrates an identifier (primarily for tests).
    public init(_ uuid: UUID) {
        self.value = uuid
    }
}
