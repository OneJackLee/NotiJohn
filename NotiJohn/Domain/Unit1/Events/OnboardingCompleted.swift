import Foundation

/// Published when the entire onboarding flow has finished. Causes
/// `RootView` to switch from the onboarding container to `SettingsView`.
public struct OnboardingCompleted: DomainEvent, Sendable {
    public let occurredAt: Date

    public init(occurredAt: Date = Date()) {
        self.occurredAt = occurredAt
    }
}
