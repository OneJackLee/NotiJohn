import Foundation

/// Persists and retrieves the singleton `OnboardingProgress` aggregate.
public protocol OnboardingProgressRepository: AnyObject, Sendable {
    /// Returns the persisted progress, or a fresh aggregate scoped at
    /// `.welcome` on first run.
    func get() async -> OnboardingProgress

    /// Persists the given aggregate, overwriting any prior state.
    func save(_ progress: OnboardingProgress) async throws
}
