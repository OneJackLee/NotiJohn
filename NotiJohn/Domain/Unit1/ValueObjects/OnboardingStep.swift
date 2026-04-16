import Foundation

/// Linear onboarding flow steps. Order is enforced by `OnboardingProgress`.
public enum OnboardingStep: String, CaseIterable, Codable, Comparable, Sendable {
    case welcome
    case permissionRequest
    case appSelection
    case completion

    /// Whether the user is permitted to skip past this step.
    /// Only the app-selection step is skippable; the user can configure
    /// monitored apps later in `SettingsView`.
    public var isSkippable: Bool {
        switch self {
        case .appSelection: return true
        default: return false
        }
    }

    /// Numeric ordering used for `Comparable` and step progression.
    private var order: Int {
        switch self {
        case .welcome: return 0
        case .permissionRequest: return 1
        case .appSelection: return 2
        case .completion: return 3
        }
    }

    /// The next step in the linear flow, or `nil` when already at `.completion`.
    public var next: OnboardingStep? {
        switch self {
        case .welcome: return .permissionRequest
        case .permissionRequest: return .appSelection
        case .appSelection: return .completion
        case .completion: return nil
        }
    }

    public static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        lhs.order < rhs.order
    }
}
