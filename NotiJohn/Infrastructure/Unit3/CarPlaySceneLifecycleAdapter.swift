import Foundation
import CarPlay

/// Thin bridge between the UIKit `CPTemplateApplicationSceneDelegate`
/// callbacks and the application-layer `CarPlaySessionAppService`.
///
/// Exists so the scene delegate (constructed by UIKit, see
/// `CarPlaySceneDelegate`) does not need to depend on the application layer
/// directly — only on this adapter.
public final class CarPlaySceneLifecycleAdapter {
    private let sessionService: CarPlaySessionAppService

    public init(sessionService: CarPlaySessionAppService) {
        self.sessionService = sessionService
    }

    /// Called from `CarPlaySceneDelegate.templateApplicationScene(_:didConnect:to:)`.
    /// `interfaceController` and `window` are accepted for forward
    /// compatibility (Unit 4 wires its template stack against the controller).
    public func didConnect(
        interfaceController: CPInterfaceController,
        window: CPWindow
    ) {
        sessionService.onCarPlayConnect()
    }

    /// Called from `CarPlaySceneDelegate.templateApplicationScene(_:didDisconnect:)`.
    public func didDisconnect(interfaceController: CPInterfaceController) {
        sessionService.onCarPlayDisconnect()
    }
}
