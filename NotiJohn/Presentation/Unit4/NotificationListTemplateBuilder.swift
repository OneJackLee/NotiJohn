import Foundation
import Combine
import CarPlay
import UIKit

/// Builds and refreshes the root `CPListTemplate` ("Notifications") and
/// translates `NotificationSummary` projections into `CPListItem`s.
///
/// The class is non-isolated for ease of construction; methods that touch
/// CarPlay/UIKit APIs are individually marked `@MainActor`. The
/// `templateManager` back-reference is `weak` so the manager (which owns
/// this builder) is not retained — a strong link would form a retain cycle.
public final class NotificationListTemplateBuilder {
    private let listService: NotificationListAppService
    private let managementService: NotificationManagementAppService
    public weak var templateManager: CarPlayTemplateManager?

    private var listTemplate: CPListTemplate?

    public init(
        listService: NotificationListAppService,
        managementService: NotificationManagementAppService
    ) {
        self.listService = listService
        self.managementService = managementService
    }

    /// Creates the root template with an empty section and the trailing
    /// "Clear All" navigation button. Kicks off an async refresh so the
    /// initial data load happens after the template is returned to the
    /// interface controller (avoids blocking the connect path).
    @MainActor
    public func build() -> CPListTemplate {
        let template = CPListTemplate(title: "Notifications", sections: [])
        template.trailingNavigationBarButtons = [
            CPBarButton(title: "Clear All") { [weak self] _ in
                self?.templateManager?.showClearAllConfirmation()
            }
        ]
        self.listTemplate = template
        Task { @MainActor [weak self] in
            await self?.refresh()
        }
        return template
    }

    /// Re-fetches the full notification list and replaces the sections of
    /// the live `CPListTemplate`. Each item's tap handler asks the manager
    /// to push the matching detail template; unread items show a filled
    /// circle as their leading image.
    @MainActor
    public func refresh() async {
        let summaries = await listService.fetchNotificationList()
        let items = summaries.map { summary -> CPListItem in
            let item = CPListItem(
                text: summary.title,
                detailText: summary.sourceAppName
            )
            // Visual distinction for unread: filled circle as a leading icon.
            // Read items get no image so the row reads as "neutral".
            if summary.readStatus == .unread {
                item.setImage(UIImage(systemName: "circle.fill"))
            } else {
                item.setImage(nil)
            }
            item.handler = { [weak self] _, completion in
                self?.templateManager?.pushDetail(for: summary.notificationId)
                completion()
            }
            return item
        }
        let section = CPListSection(items: items)
        listTemplate?.updateSections([section])
    }

    /// Forwards the application service's merged change publisher.
    /// Exposed so the manager can subscribe without having a direct
    /// dependency on `NotificationListAppService`.
    public func observeChanges() -> AnyPublisher<Void, Never> {
        listService.observeListChanges()
    }
}
