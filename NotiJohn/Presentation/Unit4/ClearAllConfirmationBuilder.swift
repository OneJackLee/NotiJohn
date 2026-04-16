import Foundation
import CarPlay

/// Builds the modal `CPAlertTemplate` that asks "Clear all notifications?"
/// before invoking `NotificationManagementAppService.clearAll`. Honouring
/// this confirmation is the UI's contribution to `ClearAllConfirmationPolicy`.
///
/// The class is non-isolated; the `build` method is `@MainActor` because
/// it instantiates a `CPTemplate`.
public final class ClearAllConfirmationBuilder {
    private let managementService: NotificationManagementAppService

    public init(managementService: NotificationManagementAppService) {
        self.managementService = managementService
    }

    /// Two-action alert: destructive "Clear All" (which hops off the main
    /// actor into the management service) and a system-style "Cancel".
    @MainActor
    public func build() -> CPAlertTemplate {
        let confirmAction = CPAlertAction(title: "Clear All", style: .destructive) { [weak self] _ in
            guard let self else { return }
            Task {
                try? await self.managementService.clearAll()
            }
        }

        let cancelAction = CPAlertAction(title: "Cancel", style: .cancel) { _ in
            // CPAlertTemplate auto-dismisses; no domain operation needed.
        }

        return CPAlertTemplate(
            titleVariants: ["Clear all notifications?"],
            actions: [confirmAction, cancelAction]
        )
    }
}
