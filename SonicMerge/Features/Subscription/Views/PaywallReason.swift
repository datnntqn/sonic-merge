import Foundation

/// Why the paywall is being presented. Used by `PaywallTriggerCoordinator`
/// to throttle aggressive surfacing and by `PaywallView` to set the
/// header copy.
enum PaywallReason: String, Sendable {
    /// User just finished onboarding step 5 (Smart Cut applied to sample).
    /// Highest-converting moment. Sub-project 3 wires this.
    case endOfOnboarding

    /// User tried to do a 4th Smart Cut/Denoise today. Sub-project 3 wires this.
    case hitDailyCap

    /// User imported a clip exceeding the free length cap. Sub-project 3 wires this.
    case hitLengthCap

    /// User toggled "Remove watermark" in the Export sheet. Sub-project 3 wires this.
    case watermarkExport

    /// User tapped "Upgrade to Pro" from Settings. Always shown — no throttling.
    case settingsUpgrade

    /// `Transaction.updates` listener detected `.expired`/`.revoked`.
    /// Sub-project 3 wires this. Highest re-conversion probability.
    case trialExpired

    /// True when this trigger should bypass session-and-dismiss throttling
    /// (user explicitly asked for the paywall).
    var bypassesThrottle: Bool {
        switch self {
        case .settingsUpgrade: return true
        default: return false
        }
    }
}
