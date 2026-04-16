import Foundation
import CarPlay
import UIKit

/// Builds the `CPInformationTemplate` shown when the user taps a list item.
/// Loading is delegated to `NotificationDetailAppService`, which also
/// applies the auto-mark-as-read side effect.
///
/// The class is non-isolated for ease of construction; the `build` method
/// is `@MainActor` because it instantiates `CPTemplate` types that must be
/// touched on the main actor.
public final class NotificationDetailTemplateBuilder {
    private let detailService: NotificationDetailAppService

    public init(detailService: NotificationDetailAppService) {
        self.detailService = detailService
    }

    /// Loads the detail and constructs a four-row information template.
    /// Returns `nil` if the notification is missing (e.g., dismissed
    /// between the tap and the load) so the manager can skip the push.
    @MainActor
    public func build(for notificationId: NotificationId) async -> CPInformationTemplate? {
        guard let detail = try? await detailService.viewNotificationDetail(id: notificationId) else {
            return nil
        }

        let items: [CPInformationItem] = [
            CPInformationItem(title: "From", detail: detail.sourceAppName),
            CPInformationItem(title: "Title", detail: detail.title),
            CPInformationItem(title: "Message", detail: detail.body),
            CPInformationItem(title: "Received", detail: Self.formatDate(detail.capturedAt)),
        ]

        return CPInformationTemplate(
            title: detail.title,
            layout: .leading,
            items: items,
            actions: []
        )
    }

    /// Formats the captured timestamp as a relative string (e.g., "2 minutes
    /// ago") suitable for the at-a-glance CarPlay UI.
    private static func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
