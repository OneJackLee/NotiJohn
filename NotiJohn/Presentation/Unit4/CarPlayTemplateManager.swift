import Foundation
import Combine
import CarPlay
import UIKit

/// Coordinates the Unit 4 CarPlay template stack on top of a
/// `CPInterfaceController` provided by Unit 3's `CarPlaySceneDelegate`.
///
/// The class itself is non-isolated so it can be instantiated from
/// `Unit4Container` during app launch, but every method that touches a
/// `CPInterfaceController` or `CPTemplate` is marked `@MainActor`. The
/// Combine pipeline that drives `refreshList()` hops to `DispatchQueue.main`
/// before invoking us so the contract is satisfied.
public final class CarPlayTemplateManager {
    private var interfaceController: CPInterfaceController?
    private let listBuilder: NotificationListTemplateBuilder
    private let detailBuilder: NotificationDetailTemplateBuilder
    private let clearAllBuilder: ClearAllConfirmationBuilder

    private var cancellables = Set<AnyCancellable>()

    public init(
        listBuilder: NotificationListTemplateBuilder,
        detailBuilder: NotificationDetailTemplateBuilder,
        clearAllBuilder: ClearAllConfirmationBuilder
    ) {
        self.listBuilder = listBuilder
        self.detailBuilder = detailBuilder
        self.clearAllBuilder = clearAllBuilder
    }

    /// Called by Unit 3 when CarPlay connects. Stores the interface
    /// controller, builds the list template as the root, and starts
    /// observing domain events so the list auto-refreshes.
    @MainActor
    public func setup(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        let rootTemplate = listBuilder.build()
        interfaceController.setRootTemplate(rootTemplate, animated: false, completion: nil)
        observeListChanges()
    }

    @MainActor
    private func observeListChanges() {
        listBuilder.observeChanges()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshList()
            }
            .store(in: &cancellables)
    }

    /// Re-fetches the list from the application service and replaces the
    /// `CPListTemplate` sections. Safe to call repeatedly.
    @MainActor
    public func refreshList() {
        Task { @MainActor in
            await listBuilder.refresh()
        }
    }

    /// Fetches the notification detail (which transparently marks it as
    /// read) and pushes the resulting `CPInformationTemplate`. Silently
    /// skips the push if the notification is no longer present.
    @MainActor
    public func pushDetail(for notificationId: NotificationId) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let template = await self.detailBuilder.build(for: notificationId) {
                self.interfaceController?.pushTemplate(template, animated: true, completion: nil)
            }
        }
    }

    /// Presents the modal "Clear all notifications?" confirmation alert.
    @MainActor
    public func showClearAllConfirmation() {
        let alert = clearAllBuilder.build()
        interfaceController?.presentTemplate(alert, animated: true, completion: nil)
    }
}
