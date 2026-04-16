import Foundation

/// Errors thrown by the `OnboardingProgress` aggregate when callers attempt
/// invalid step transitions.
public enum OnboardingProgressError: Error, Equatable {
    case stepOutOfOrder(expected: OnboardingStep, actual: OnboardingStep)
    case stepNotSkippable(OnboardingStep)
    case alreadyComplete
    case notReadyToFinish(currentStep: OnboardingStep)
}

/// Aggregate root for the linear onboarding flow. Enforces the invariant
/// that the user can only operate on the `currentStep` and that progression
/// is one-way: welcome → permissionRequest → appSelection → completion.
public final class OnboardingProgress: Codable {
    public private(set) var currentStep: OnboardingStep
    public private(set) var completedSteps: Set<OnboardingStep>
    public private(set) var skippedSteps: Set<OnboardingStep>
    public private(set) var isComplete: Bool

    public init(
        currentStep: OnboardingStep = .welcome,
        completedSteps: Set<OnboardingStep> = [],
        skippedSteps: Set<OnboardingStep> = [],
        isComplete: Bool = false
    ) {
        self.currentStep = currentStep
        self.completedSteps = completedSteps
        self.skippedSteps = skippedSteps
        self.isComplete = isComplete
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case currentStep, completedSteps, skippedSteps, isComplete
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.currentStep = try container.decode(OnboardingStep.self, forKey: .currentStep)
        self.completedSteps = try container.decode(Set<OnboardingStep>.self, forKey: .completedSteps)
        self.skippedSteps = try container.decode(Set<OnboardingStep>.self, forKey: .skippedSteps)
        self.isComplete = try container.decode(Bool.self, forKey: .isComplete)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentStep, forKey: .currentStep)
        try container.encode(completedSteps, forKey: .completedSteps)
        try container.encode(skippedSteps, forKey: .skippedSteps)
        try container.encode(isComplete, forKey: .isComplete)
    }

    // MARK: - Commands

    /// Marks the given step as completed and advances `currentStep` to the
    /// next step in the linear flow.
    public func completeStep(_ step: OnboardingStep) throws -> OnboardingStepCompleted {
        guard !isComplete else { throw OnboardingProgressError.alreadyComplete }
        guard step == currentStep else {
            throw OnboardingProgressError.stepOutOfOrder(expected: currentStep, actual: step)
        }
        completedSteps.insert(step)
        if let next = step.next {
            currentStep = next
        }
        return OnboardingStepCompleted(step: step)
    }

    /// Marks the given step as skipped and advances `currentStep`.
    /// Throws if the step is not skippable.
    public func skipStep(_ step: OnboardingStep) throws -> OnboardingStepSkipped {
        guard !isComplete else { throw OnboardingProgressError.alreadyComplete }
        guard step == currentStep else {
            throw OnboardingProgressError.stepOutOfOrder(expected: currentStep, actual: step)
        }
        guard step.isSkippable else { throw OnboardingProgressError.stepNotSkippable(step) }
        skippedSteps.insert(step)
        if let next = step.next {
            currentStep = next
        }
        return OnboardingStepSkipped(step: step)
    }

    /// Finalizes onboarding. Caller must have already advanced to the
    /// `.completion` step.
    public func finish() throws -> OnboardingCompleted {
        guard !isComplete else { throw OnboardingProgressError.alreadyComplete }
        guard currentStep == .completion else {
            throw OnboardingProgressError.notReadyToFinish(currentStep: currentStep)
        }
        isComplete = true
        completedSteps.insert(.completion)
        return OnboardingCompleted()
    }
}
