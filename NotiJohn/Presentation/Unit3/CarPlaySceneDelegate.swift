import Foundation
import UIKit
import CarPlay

/// UIKit instantiates this delegate via the Info.plist scene manifest, so it
/// cannot receive collaborators through an initializer. To bridge the gap we
/// expose a static `sceneServices` slot that the orchestrator (`AppContainer`)
/// must populate at app startup.
///
/// **Wiring contract — the `AppContainer` must run, once, before the system
/// connects the CarPlay scene:**
/// ```swift
/// CarPlaySceneDelegate.sceneServices = .init(
///     lifecycleAdapter: appContainer.unit3.lifecycleAdapter,
///     templateManager:  appContainer.unit4.templateManager
/// )
/// ```
/// (TODO: orchestrator must add this assignment in `AppContainer.init` —
/// Unit 3 deliberately does not modify `AppContainer.swift`.)
///
/// If the slot is `nil` when `didConnect` fires we log a warning and fall
/// through gracefully — better to have an empty CarPlay screen than a crash.
public final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    /// Bag of dependencies the scene delegate needs. Populated externally
    /// because UIKit owns this delegate's lifetime.
    public struct SceneServices {
        public let lifecycleAdapter: CarPlaySceneLifecycleAdapter
        public let templateManager: CarPlayTemplateManager

        public init(
            lifecycleAdapter: CarPlaySceneLifecycleAdapter,
            templateManager: CarPlayTemplateManager
        ) {
            self.lifecycleAdapter = lifecycleAdapter
            self.templateManager = templateManager
        }
    }

    /// Set by `AppContainer` during app startup. See class doc above.
    public static var sceneServices: SceneServices?

    /// Held while the scene is connected; cleared on disconnect.
    private var interfaceController: CPInterfaceController?

    public override init() {
        super.init()
    }

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController

        guard let services = Self.sceneServices else {
            // Surface the wiring failure but don't crash — the CarPlay screen
            // will simply be blank until the next reconnect.
            assertionFailure(
                "CarPlaySceneDelegate.sceneServices was nil on didConnect — "
                + "AppContainer must populate this before CarPlay connects."
            )
            return
        }

        services.lifecycleAdapter.didConnect(
            interfaceController: interfaceController,
            window: window
        )

        // Hand the controller to Unit 4 so it can install the root list
        // template. Unit 3 owns no persistent UI of its own.
        services.templateManager.setup(interfaceController: interfaceController)
    }

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        Self.sceneServices?.lifecycleAdapter.didDisconnect(
            interfaceController: interfaceController
        )
        self.interfaceController = nil
    }
}
