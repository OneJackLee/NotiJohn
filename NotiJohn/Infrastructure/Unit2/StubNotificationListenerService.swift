import Foundation

/// Development stub implementation of `NotificationListenerService`.
///
/// The real implementation would observe `UNUserNotificationCenter` (or run a
/// Notification Service Extension) and forward events to the capture service.
/// Until those entitlements are wired up, this stub exposes
/// `simulateNotification` so unit tests and the CarPlay simulator can drive
/// the capture pipeline manually.
public final class StubNotificationListenerService: NotificationListenerService {
    private let captureService: NotificationCaptureAppService

    public init(captureService: NotificationCaptureAppService) {
        self.captureService = captureService
    }

    public func startListening() {
        print("[StubNotificationListenerService] startListening (no-op stub)")
    }

    public func stopListening() {
        print("[StubNotificationListenerService] stopListening (no-op stub)")
    }

    /// Feeds a synthetic notification through the capture pipeline. Invalid
    /// bundle IDs (empty strings) are silently dropped.
    public func simulateNotification(
        bundleId: String,
        appName: String,
        title: String,
        body: String
    ) async {
        guard let bundle = BundleIdentifier(bundleId) else {
            print("[StubNotificationListenerService] dropped: empty bundleId")
            return
        }
        do {
            try await captureService.handleIncomingNotification(
                bundleId: bundle,
                appName: appName,
                appIcon: nil,
                title: title,
                body: body
            )
        } catch {
            print("[StubNotificationListenerService] capture failed: \(error)")
        }
    }
}
