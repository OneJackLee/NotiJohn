import Foundation

/// Published when the user skips a skippable onboarding step (currently only
/// `appSelection`).
public struct OnboardingStepSkipped: DomainEvent, Sendable {
    public let step: OnboardingStep
    public let occurredAt: Date

    public init(step: OnboardingStep, occurredAt: Date = Date()) {
        self.step = step
        self.occurredAt = occurredAt
    }
}
