import SwiftUI

/// S1.1 — Welcome screen. Static introduction, single "Continue" CTA.
struct WelcomeStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "car.front.waves.up.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .foregroundStyle(.tint)

            Text("NotiJohn")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your notifications, on CarPlay.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("NotiJohn captures notifications from your favorite apps and displays them on CarPlay while you drive.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Spacer()

            Button {
                Task { await viewModel.advanceStep() }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}
