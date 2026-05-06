import Foundation

/// Decides whether a paywall should actually be presented for a given
/// `PaywallReason`. Two layers of throttling:
///
/// 1. Session-level: once any paywall has been shown in this app launch,
///    no other (non-bypass) paywalls fire until next launch. Prevents
///    "user dismissed paywall on screen A, then tapped feature B and saw
///    another paywall instantly" annoyance.
///
/// 2. Per-reason dismiss count (persisted to UserDefaults): if a user has
///    dismissed the .hitDailyCap paywall 5 times across all sessions, we
///    stop showing it (Apple may flag aggressive re-prompting). Refreshes
///    only when the user upgrades to Pro (next sub-project).
///
/// `.settingsUpgrade` bypasses both — the user explicitly tapped Upgrade.
@MainActor
@Observable
final class PaywallTriggerCoordinator {

    /// 5 dismissals of the same reason → stop offering it.
    static let dismissThreshold = 5

    private let defaults: UserDefaults
    private(set) var hasShownPaywallThisSession: Bool = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func shouldPresent(_ reason: PaywallReason) -> Bool {
        if reason.bypassesThrottle { return true }
        if hasShownPaywallThisSession { return false }
        if dismissCount(for: reason) >= Self.dismissThreshold { return false }
        return true
    }

    func markPresented(_ reason: PaywallReason) {
        hasShownPaywallThisSession = true
    }

    func recordDismiss(_ reason: PaywallReason) {
        let key = dismissCountKey(for: reason)
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
    }

    /// Reset on cold launch / scenePhase becoming .background → .active
    /// transition. Caller hooks via SonicMergeApp.onChange(of: scenePhase).
    func resetSession() {
        hasShownPaywallThisSession = false
    }

    // MARK: - Private

    private func dismissCount(for reason: PaywallReason) -> Int {
        defaults.integer(forKey: dismissCountKey(for: reason))
    }

    private func dismissCountKey(for reason: PaywallReason) -> String {
        "PaywallTriggerCoordinator.dismissCount.\(reason.rawValue)"
    }
}
