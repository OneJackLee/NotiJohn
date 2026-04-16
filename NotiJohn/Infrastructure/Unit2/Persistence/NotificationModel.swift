import Foundation
import SwiftData

/// SwiftData persistence record for `Notification`.
///
/// Naming is fixed: `AppContainer` references `NotificationModel.self` in its
/// schema declaration — do not rename.
@Model
public final class NotificationModel {
    @Attribute(.unique) public var id: UUID
    public var sourceBundleId: String
    public var sourceAppName: String
    @Attribute(.externalStorage) public var sourceAppIcon: Data?
    public var title: String
    public var body: String
    public var capturedAt: Date
    public var fingerprint: String
    /// Stored as the raw value of `ReadStatus` ("unread" / "read") so SwiftData
    /// can index it as a primitive String.
    public var readStatusRaw: String

    public init(
        id: UUID,
        sourceBundleId: String,
        sourceAppName: String,
        sourceAppIcon: Data?,
        title: String,
        body: String,
        capturedAt: Date,
        fingerprint: String,
        readStatusRaw: String
    ) {
        self.id = id
        self.sourceBundleId = sourceBundleId
        self.sourceAppName = sourceAppName
        self.sourceAppIcon = sourceAppIcon
        self.title = title
        self.body = body
        self.capturedAt = capturedAt
        self.fingerprint = fingerprint
        self.readStatusRaw = readStatusRaw
    }

    /// Materializes a SwiftData record from a domain aggregate.
    public convenience init(from notification: Notification) {
        self.init(
            id: notification.id.value,
            sourceBundleId: notification.sourceApp.bundleId.value,
            sourceAppName: notification.sourceApp.appName,
            sourceAppIcon: notification.sourceApp.appIcon,
            title: notification.content.title,
            body: notification.content.body,
            capturedAt: notification.capturedAt.value,
            fingerprint: notification.fingerprint.value,
            readStatusRaw: notification.readStatus.rawValue
        )
    }

    /// Re-hydrates a domain aggregate. Bundle IDs from the store are trusted
    /// and use the unchecked initializer; read status falls back to `.unread`
    /// if the persisted raw value is unrecognised (defensive).
    public func toDomain() -> Notification {
        Notification(
            id: NotificationId(id),
            sourceApp: SourceApp(
                bundleId: BundleIdentifier(unchecked: sourceBundleId),
                appName: sourceAppName,
                appIcon: sourceAppIcon
            ),
            content: NotificationContent(title: title, body: body),
            capturedAt: CaptureTimestamp(capturedAt),
            fingerprint: NotificationFingerprint(value: fingerprint),
            readStatus: ReadStatus(rawValue: readStatusRaw) ?? .unread
        )
    }
}
