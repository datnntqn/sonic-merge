import SwiftUI

/// `EnvironmentValues` key for the app's `PaywallTriggerCoordinator`.
///
/// The default value is a fresh, process-local coordinator — this keeps the
/// `.paywall(reason:)` modifier safe to use in views that haven't been
/// explicitly wired (e.g., previews, isolated unit-test hosts). The `RootTabView`
/// injects the real shared instance via `.environment(\.paywallCoordinator, ...)`.
private struct PaywallCoordinatorKey: EnvironmentKey {
    @MainActor static let defaultValue: PaywallTriggerCoordinator = .init()
}

extension EnvironmentValues {
    var paywallCoordinator: PaywallTriggerCoordinator {
        get { self[PaywallCoordinatorKey.self] }
        set { self[PaywallCoordinatorKey.self] = newValue }
    }
}
