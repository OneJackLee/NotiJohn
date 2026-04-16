import Foundation

/// UI-side documentation policy: the "Clear All" command must be preceded by
/// an explicit user confirmation (`CPAlertTemplate`). The domain service
/// (`NotificationManagementAppService.clearAll`) does NOT verify confirmation —
/// the presentation layer is responsible for honouring this policy.
///
/// Kept as an enum with a static flag so it is impossible to instantiate or
/// mutate; presence of the type in the codebase serves as the contract.
public enum ClearAllConfirmationPolicy {
    /// Always `true`. Indicates that "Clear All" requires a confirmation
    /// dialog before invoking the management service.
    public static let requiresConfirmation = true
}
