import Foundation
import Observation

/// View model for the onboarding container view. Drives step transitions,
/// permission state, and the embedded app-selection list.
@Observable
@MainActor
public final class OnboardingViewModel {
    private let onboardingService: OnboardingAppService
    private let appMonitoringService: AppMonitoringAppService

    // MARK: - Observed state

    public var currentStep: OnboardingStep = .welcome
    public var permissionStatus: PermissionStatus = .notDetermined
    public var installedApps: [AppInfo] = []
    public var selectedBundleIds: Set<BundleIdentifier> = []
    public var isComplete: Bool = false
    public var isLoading: Bool = false
    public var lastErrorMessage: String?

    public init(
        onboardingService: OnboardingAppService,
        appMonitoringService: AppMonitoringAppService
    ) {
        self.onboardingService = onboardingService
        self.appMonitoringService = appMonitoringService
    }

    // MARK: - Lifecycle

    /// Loads progress, current permission status, and installed apps when
    /// the onboarding container appears.
    public func onAppear() async {
        isLoading = true
        defer { isLoading = false }

        let progress = await onboardingService.loadProgress()
        currentStep = progress.currentStep
        isComplete = progress.isComplete
        permissionStatus = await onboardingService.currentPermissionStatus()

        installedApps = await appMonitoringService.loadInstalledApps()
        let settings = await appMonitoringService.loadSettings()
        selectedBundleIds = Set(settings.enabledApps.map { $0.bundleId })
    }

    /// Re-checks permission status — typically driven by `scenePhase`
    /// changing back to `.active` after the user returns from iOS Settings.
    public func refreshPermissionStatus() async {
        permissionStatus = await onboardingService.currentPermissionStatus()
    }

    // MARK: - Actions

    /// Advances past the current step.
    /// On `.completion`, calls `finishOnboarding()` instead.
    public func advanceStep() async {
        do {
            if currentStep == .completion {
                try await onboardingService.finishOnboarding()
                isComplete = true
            } else {
                let step = currentStep
                try await onboardingService.completeStep(step)
                let progress = await onboardingService.loadProgress()
                currentStep = progress.currentStep
            }
        } catch {
            lastErrorMessage = "Could not advance: \(error.localizedDescription)"
        }
    }

    /// Skips the current step (only valid on `.appSelection`).
    public func skipCurrentStep() async {
        do {
            let step = currentStep
            try await onboardingService.skipStep(step)
            let progress = await onboardingService.loadProgress()
            currentStep = progress.currentStep
        } catch {
            lastErrorMessage = "Could not skip step: \(error.localizedDescription)"
        }
    }

    /// Triggers the iOS permission prompt and reflects the result.
    public func requestPermission() async {
        permissionStatus = await onboardingService.requestNotificationPermission()
    }

    /// Toggles monitoring for a single app from the embedded selection list.
    /// Updates optimistic UI state immediately, then persists.
    public func toggleApp(_ appInfo: AppInfo, enabled: Bool) async {
        // Optimistic update.
        if enabled {
            selectedBundleIds.insert(appInfo.bundleId)
        } else {
            selectedBundleIds.remove(appInfo.bundleId)
        }
        do {
            if enabled {
                try await appMonitoringService.enableApp(appInfo)
            } else {
                try await appMonitoringService.disableApp(appInfo.bundleId)
            }
        } catch {
            // Revert on failure.
            if enabled {
                selectedBundleIds.remove(appInfo.bundleId)
            } else {
                selectedBundleIds.insert(appInfo.bundleId)
            }
            lastErrorMessage = "Could not update selection: \(error.localizedDescription)"
        }
    }

    /// Convenience for `S1.4 — Get Started`. Equivalent to `advanceStep()`
    /// when on the completion step.
    public func finishOnboarding() async {
        await advanceStep()
    }
}
