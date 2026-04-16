import Foundation

/// Orchestrates the onboarding flow. Mutates the `OnboardingProgress`
/// aggregate via well-defined commands and publishes the resulting domain
/// events on the shared bus.
public final class OnboardingAppService {
    private let onboardingRepo: OnboardingProgressRepository
    private let permissionService: NotificationPermissionService
    private let eventBus: DomainEventBus

    public init(
        onboardingRepo: OnboardingProgressRepository,
        permissionService: NotificationPermissionService,
        eventBus: DomainEventBus
    ) {
        self.onboardingRepo = onboardingRepo
        self.permissionService = permissionService
        self.eventBus = eventBus
    }

    /// Returns the persisted onboarding progress (or a fresh aggregate on
    /// first launch).
    public func loadProgress() async -> OnboardingProgress {
        await onboardingRepo.get()
    }

    /// Completes the given step. No-op if the step has already been
    /// completed (idempotent on double-tap).
    public func completeStep(_ step: OnboardingStep) async throws {
        let progress = await onboardingRepo.get()
        // Idempotent guard: if the user double-taps Continue, ignore the
        // second tap rather than throwing.
        guard progress.currentStep == step else { return }
        let event = try progress.completeStep(step)
        try await onboardingRepo.save(progress)
        eventBus.publish(event)
    }

    /// Skips the given step. Throws via the aggregate if the step is not
    /// skippable.
    public func skipStep(_ step: OnboardingStep) async throws {
        let progress = await onboardingRepo.get()
        guard progress.currentStep == step else { return }
        let event = try progress.skipStep(step)
        try await onboardingRepo.save(progress)
        eventBus.publish(event)
    }

    /// Triggers the iOS notification permission prompt and publishes a
    /// `NotificationPermissionChanged` event with the result.
    @discardableResult
    public func requestNotificationPermission() async -> PermissionStatus {
        let status = await permissionService.requestPermission()
        eventBus.publish(NotificationPermissionChanged(newStatus: status))
        return status
    }

    /// Returns the current OS-reported permission status without prompting.
    public func currentPermissionStatus() async -> PermissionStatus {
        await permissionService.checkCurrentStatus()
    }

    /// Finalizes onboarding, marking the aggregate complete and publishing
    /// `OnboardingCompleted`.
    public func finishOnboarding() async throws {
        let progress = await onboardingRepo.get()
        guard !progress.isComplete else { return }
        let event = try progress.finish()
        try await onboardingRepo.save(progress)
        eventBus.publish(event)
    }

    /// Used by `RootView` at launch to decide between the onboarding flow
    /// and the main settings screen.
    public func isOnboardingComplete() async -> Bool {
        await onboardingRepo.get().isComplete
    }
}
