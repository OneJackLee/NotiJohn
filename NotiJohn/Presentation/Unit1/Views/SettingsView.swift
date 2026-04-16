import SwiftUI

/// S1.5 — Post-onboarding settings screen. Lets the user manage which apps
/// are monitored and inspect the current notification permission status.
///
/// In `DEBUG` builds, also exposes a "Simulate Notification" tool that
/// directly invokes Unit 2's capture pipeline so the Unit 3/4 CarPlay flow
/// can be exercised without a paired iPhone notification.
struct SettingsView: View {
    @Bindable var viewModel: AppSelectionViewModel
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    @Environment(AppContainer.self) private var container
    #endif

    var body: some View {
        NavigationStack {
            List {
                monitoredAppsSection
                permissionSection
                #if DEBUG
                debugSection
                #endif
            }
            .navigationTitle("Settings")
        }
        .task { await viewModel.onAppear() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.refreshPermissionStatus() }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var monitoredAppsSection: some View {
        Section("Monitored Apps") {
            if viewModel.isLoading && viewModel.monitoredApps.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if viewModel.monitoredApps.isEmpty {
                Text("No apps available.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.monitoredApps) { app in
                    AppToggleRow(
                        appInfo: app.appInfo,
                        isOn: Binding(
                            get: { app.isEnabled },
                            set: { _ in
                                Task { await viewModel.toggleApp(app) }
                            }
                        )
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var permissionSection: some View {
        Section("Notification Access") {
            switch viewModel.permissionStatus {
            case .granted:
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .notDetermined:
                Label("Not yet requested", systemImage: "questionmark.circle")
                    .foregroundStyle(.secondary)
            case .denied:
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Label("Denied — tap to fix", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    #if DEBUG
    @State private var debugTitle: String = "Test Notification"
    @State private var debugBody: String = "Hello from NotiJohn debug tools."
    @State private var debugBundleId: String = "net.whatsapp.WhatsApp"
    @State private var debugAppName: String = "WhatsApp"
    @State private var debugError: String?

    @ViewBuilder
    private var debugSection: some View {
        Section("Debug — Simulate Notification") {
            TextField("Bundle ID", text: $debugBundleId)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("App Name", text: $debugAppName)
            TextField("Title", text: $debugTitle)
            TextField("Body", text: $debugBody, axis: .vertical)
                .lineLimit(2...4)

            Button("Send Simulated Notification") {
                Task { await sendDebugNotification() }
            }

            if let debugError {
                Text(debugError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }

        Section("Debug — Captured Notifications") {
            NavigationLink {
                DebugNotificationListView(
                    viewModel: DebugNotificationListViewModel(
                        listService: container.unit4.listService,
                        detailService: container.unit4.detailService,
                        managementService: container.unit4.managementService
                    )
                )
            } label: {
                Label("View captured notifications", systemImage: "tray.full")
            }
            Text("iPhone-side mirror of the CarPlay list. Useful for verifying the capture pipeline without CarPlay.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func sendDebugNotification() async {
        guard let bundleId = BundleIdentifier(debugBundleId) else {
            debugError = "Invalid bundle ID."
            return
        }
        // Debug ergonomics: ensure this bundle is in the in-memory filter so
        // the simulate button always succeeds, regardless of whether the user
        // has toggled the corresponding row in "Monitored Apps". Has no
        // persistence side-effect — the next cold launch will rebuild the
        // filter from saved settings only.
        container.unit2.monitoredAppFilter.addApp(bundleId: bundleId)

        do {
            try await container.unit2.captureService.handleIncomingNotification(
                bundleId: bundleId,
                appName: debugAppName,
                appIcon: nil,
                title: debugTitle,
                body: debugBody
            )
            debugError = nil
        } catch {
            debugError = "Capture failed: \(error.localizedDescription)"
        }
    }
    #endif
}
