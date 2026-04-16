import Foundation
import Combine
import Observation

/// DI container for Unit 1 (iPhone Companion App).
///
/// Wires the Unit 1 domain services, infrastructure adapters, application
/// services, and view-model factories. Subscribes to its own
/// `OnboardingCompleted` event so that `RootView` can observe the
/// `onboardingCompletedFlag` to switch from the onboarding flow to the
/// main settings screen.
@Observable
public final class Unit1Container {
    public let eventBus: DomainEventBus

    /// Set to `true` when an `OnboardingCompleted` event is observed on the
    /// shared event bus. Observed by `RootView` to switch out of the
    /// onboarding flow.
    public var onboardingCompletedFlag: Bool = false

    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Repositories

    @ObservationIgnored
    public lazy var settingsRepo: MonitoredAppSettingsRepository =
        UserDefaultsSettingsRepository()

    @ObservationIgnored
    public lazy var onboardingRepo: OnboardingProgressRepository =
        UserDefaultsOnboardingRepository()

    // MARK: - Domain services

    @ObservationIgnored
    public lazy var discoveryService: InstalledAppDiscoveryService =
        IOSAppDiscoveryService()

    @ObservationIgnored
    public lazy var permissionService: NotificationPermissionService =
        IOSNotificationPermissionService()

    // MARK: - Application services

    @ObservationIgnored
    public lazy var appMonitoringService: AppMonitoringAppService =
        AppMonitoringAppService(
            settingsRepo: settingsRepo,
            discoveryService: discoveryService,
            eventBus: eventBus
        )

    @ObservationIgnored
    public lazy var onboardingService: OnboardingAppService =
        OnboardingAppService(
            onboardingRepo: onboardingRepo,
            permissionService: permissionService,
            eventBus: eventBus
        )

    // MARK: - Init

    public init(eventBus: DomainEventBus) {
        self.eventBus = eventBus

        eventBus.subscribe(to: OnboardingCompleted.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.onboardingCompletedFlag = true
            }
            .store(in: &cancellables)
    }

    // MARK: - ViewModel factories

    @MainActor
    public func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            onboardingService: onboardingService,
            appMonitoringService: appMonitoringService
        )
    }

    @MainActor
    public func makeAppSelectionViewModel() -> AppSelectionViewModel {
        AppSelectionViewModel(
            appMonitoringService: appMonitoringService,
            permissionService: permissionService
        )
    }
}
