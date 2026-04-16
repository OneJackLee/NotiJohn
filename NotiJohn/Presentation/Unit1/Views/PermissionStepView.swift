import SwiftUI

/// S1.2 — Permission Request. Renders different states based on
/// `viewModel.permissionStatus`. The denied state inlines the S1.6
/// recovery block with a deep-link to iOS Settings.
struct PermissionStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(iconTint)

            Text("Notification Access")
                .font(.title)
                .fontWeight(.bold)

            Text("NotiJohn needs permission to read notifications from your apps so it can display them on CarPlay.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            statusBlock

            Spacer()

            Button {
                Task { await viewModel.advanceStep() }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.permissionStatus == .notDetermined)
        }
        .padding()
    }

    private var iconName: String {
        switch viewModel.permissionStatus {
        case .granted: return "checkmark.shield.fill"
        case .denied: return "exclamationmark.triangle.fill"
        case .notDetermined: return "bell.badge.fill"
        }
    }

    private var iconTint: Color {
        switch viewModel.permissionStatus {
        case .granted: return .green
        case .denied: return .yellow
        case .notDetermined: return .accentColor
        }
    }

    @ViewBuilder
    private var statusBlock: some View {
        switch viewModel.permissionStatus {
        case .notDetermined:
            Button {
                Task { await viewModel.requestPermission() }
            } label: {
                Text("Allow Notifications")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        case .granted:
            Label("Notifications enabled", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.headline)
        case .denied:
            VStack(spacing: 12) {
                Button {
                    openIOSSettings()
                } label: {
                    Text("Open Settings")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Text("Notification access is required for NotiJohn to work. Please enable it in Settings.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func openIOSSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
