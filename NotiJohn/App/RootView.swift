import SwiftUI

/// Top-level view that decides between onboarding and the main settings screen
/// based on whether onboarding has been completed.
struct RootView: View {
    @Environment(AppContainer.self) private var container
    @State private var isOnboardingComplete: Bool? = nil

    var body: some View {
        Group {
            switch isOnboardingComplete {
            case .none:
                ProgressView()
            case .some(false):
                OnboardingView(viewModel: container.unit1.makeOnboardingViewModel())
                    .onChange(of: container.unit1.onboardingCompletedFlag) { _, newValue in
                        if newValue { isOnboardingComplete = true }
                    }
            case .some(true):
                SettingsView(viewModel: container.unit1.makeAppSelectionViewModel())
            }
        }
        .task {
            isOnboardingComplete = await container.unit1.onboardingService.isOnboardingComplete()
        }
    }
}
