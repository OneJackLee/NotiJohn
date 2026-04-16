import Foundation

/// Published when the user completes an onboarding step (Continue / Get Started).
public struct OnboardingStepCompleted: DomainEvent, Sendable {
    public let step: OnboardingStep
    public let occurredAt: Date

    public init(step: OnboardingStep, occurredAt: Date = Date()) {
        self.step = step
        self.occurredAt = occurredAt
    }
}
