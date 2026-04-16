import SwiftUI

/// S1.3 — App Selection (Onboarding). Allows the user to toggle which
/// installed apps will be monitored. Same domain operations as `SettingsView`.
struct AppSelectionStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    private var sortedApps: [AppInfo] {
        viewModel.installedApps.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Select Apps to Monitor")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Choose which apps' notifications will appear on CarPlay.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)

            if viewModel.isLoading && sortedApps.isEmpty {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if sortedApps.isEmpty {
                ContentUnavailableView(
                    "No apps found",
                    systemImage: "app.dashed",
                    description: Text("We couldn't find any apps to monitor.")
                )
                .frame(maxHeight: .infinity)
            } else {
                List(sortedApps, id: \.bundleId) { app in
                    AppToggleRow(
                        appInfo: app,
                        isOn: Binding(
                            get: { viewModel.selectedBundleIds.contains(app.bundleId) },
                            set: { newValue in
                                Task { await viewModel.toggleApp(app, enabled: newValue) }
                            }
                        )
                    )
                }
                .listStyle(.insetGrouped)
            }

            VStack(spacing: 8) {
                Button {
                    Task { await viewModel.advanceStep() }
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    Task { await viewModel.skipCurrentStep() }
                } label: {
                    Text("Skip")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .controlSize(.large)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

/// Row for a single app: icon + name + toggle.
struct AppToggleRow: View {
    let appInfo: AppInfo
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            iconView
                .frame(width: 32, height: 32)
            Text(appInfo.displayName)
                .font(.body)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let data = appInfo.iconData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 7))
        } else {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.secondary.opacity(0.2))
                .overlay(
                    Image(systemName: "app.fill")
                        .foregroundStyle(.secondary)
                )
        }
    }
}
