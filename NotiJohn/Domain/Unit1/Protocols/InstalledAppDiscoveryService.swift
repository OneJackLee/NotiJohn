import Foundation

/// Returns the catalog of apps that the user may choose to monitor.
/// iOS sandboxing prevents true enumeration of installed apps; the concrete
/// implementation may use a curated list and/or dynamic discovery via the
/// Notification Service Extension.
public protocol InstalledAppDiscoveryService: AnyObject, Sendable {
    func discoverApps() async -> [AppInfo]
}
