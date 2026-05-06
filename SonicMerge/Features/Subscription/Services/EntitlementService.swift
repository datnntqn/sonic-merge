import Foundation
import Observation

/// Single source of truth for the user's Pro entitlement state. Other
/// code in the app talks to this — never to StoreKit directly. That
/// decoupling means swapping StoreKit for any other IAP backend
/// (RevenueCat, Adapty) only changes `StoreKitClient.swift`.
///
/// In Sub-project 1, `gate(_:)` always returns `.allowed` — no feature
/// caps yet. Sub-project 2 wires the actual gate semantics. Keep the
/// type stable so callsites added now don't need to change.
@MainActor
@Observable
final class EntitlementService {

    /// Process-wide singleton. The app injects this via `.environment`
    /// so previews and tests can inject a fake.
    static let shared = EntitlementService()

    private(set) var currentEntitlement: Entitlement = .free

    var isPro: Bool { currentEntitlement.isPro }

    init() {}

    /// Called by `StoreKitClient` when `Transaction.currentEntitlements`
    /// resolves or when `Transaction.updates` emits a new state.
    /// Public so tests can inject states without StoreKit.
    func setEntitlement(_ entitlement: Entitlement) {
        currentEntitlement = entitlement
    }

    /// Maps a `ProFeature` to a `GateResult`, deciding whether the user can
    /// proceed. Free-tier callers bind the returned `PaywallReason` straight
    /// into a `.paywall(reason:)` modifier when denied.
    func gate(_ feature: ProFeature) -> GateResult {
        return .allowed
    }
}

// EntitlementService is @Observable — inject via @Environment(EntitlementService.self)
// (Swift 5.9+ Observation framework). No EnvironmentKey needed.
