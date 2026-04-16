import SwiftUI

/// Container for the linear onboarding flow. Switches between the four step
/// views based on `viewModel.currentStep`.
struct OnboardingView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch viewModel.currentStep {
            case .welcome:
                WelcomeStepView(viewModel: viewModel)
            case .permissionRequest:
                PermissionStepView(viewModel: viewModel)
            case .appSelection:
                AppSelectionStepView(viewModel: viewModel)
            case .completion:
                CompletionStepView(viewModel: viewModel)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.currentStep)
        .task { await viewModel.onAppear() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.refreshPermissionStatus() }
            }
        }
    }
}
