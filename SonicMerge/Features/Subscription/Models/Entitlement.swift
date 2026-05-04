import Foundation

/// Represents the user's current entitlement to Pro features. Computed
/// from StoreKit's `Transaction.currentEntitlements` async stream by
/// `EntitlementService`. Three cases plus a derived `isPro` boolean
/// that's the only thing most callsites care about.
///
/// `pro(expiresAt:)` distinguishes from `lifetime` because the UI shows
/// expiration date for subscribers but not for lifetime buyers.
enum Entitlement: Equatable, Sendable {
    case free
    case pro(expiresAt: Date)
    case lifetime

    /// True when the user can access Pro features right now. `pro` expires
    /// at `expiresAt` (Apple's grace period is handled by StoreKit before
    /// we get to this state — by the time we see `.expired`, it's truly
    /// expired). `lifetime` is always Pro.
    var isPro: Bool {
        switch self {
        case .free: return false
        case .pro(let expiresAt): return expiresAt > .now
        case .lifetime: return true
        }
    }

    var isLifetime: Bool {
        if case .lifetime = self { return true }
        return false
    }

    /// Used in Settings → "Account" section as the primary status label.
    var displayLabel: String {
        switch self {
        case .free: return "Free"
        case .pro(let expiresAt):
            let f = DateFormatter()
            f.dateStyle = .medium
            return "Pro · expires \(f.string(from: expiresAt))"
        case .lifetime: return "Pro · Lifetime"
        }
    }
}
