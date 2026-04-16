import Foundation

/// Curated catalog of common messaging / communication apps offered to the
/// user during onboarding and in `SettingsView`.
///
/// iOS does not expose a public API to enumerate installed apps, so this
/// implementation returns a static list. Icon data is deferred to the
/// presentation layer, which renders SF Symbol fallbacks.
public final class IOSAppDiscoveryService: InstalledAppDiscoveryService, @unchecked Sendable {
    public init() {}

    public func discoverApps() async -> [AppInfo] {
        Self.curatedApps
    }

    private static let curatedApps: [AppInfo] = [
        AppInfo(
            bundleId: BundleIdentifier(unchecked: "net.whatsapp.WhatsApp"),
            displayName: "WhatsApp",
            iconData: nil
        ),
        AppInfo(
            bundleId: BundleIdentifier(unchecked: "com.apple.MobileSMS"),
            displayName: "Messages",
            iconData: nil
        ),
        AppInfo(
            bundleId: BundleIdentifier(unchecked: "ph.telegra.Telegraph"),
            displayName: "Telegram",
            iconData: nil
        ),
        AppInfo(
            bundleId: BundleIdentifier(unchecked: "com.tinyspeck.chatlyio"),
            displayName: "Slack",
            iconData: nil
        ),
        AppInfo(
            bundleId: BundleIdentifier(unchecked: "com.hammerandchisel.discord"),
            displayName: "Discord",
            iconData: nil
        ),
        AppInfo(
            bundleId: BundleIdentifier(unchecked: "com.google.Gmail"),
            displayName: "Gmail",
            iconData: nil
        )
    ]
}
