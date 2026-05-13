import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct PaywallTriggerCoordinatorTests {

    private func freshCoordinator() -> (PaywallTriggerCoordinator, UserDefaults) {
        let suite = "PaywallTriggerCoordinatorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let coord = PaywallTriggerCoordinator(defaults: defaults)
        return (coord, defaults)
    }

    @Test func defaultDecidePresents() {
        let (coord, _) = freshCoordinator()
        #expect(coord.decide(.endOfOnboarding) == .present)
    }

    @Test func sessionFlagSuppressesProactiveSecondPresent() {
        let (coord, _) = freshCoordinator()
        _ = coord.decide(.endOfOnboarding)
        // Second proactive reason in same session is silently suppressed.
        #expect(coord.decide(.trialExpired) == .suppress)
    }

    @Test func sessionFlagFallsBackToToastForCapHit() {
        let (coord, _) = freshCoordinator()
        _ = coord.decide(.endOfOnboarding)
        // Cap-hit must surface a toast so the user isn't silently rejected.
        #expect(coord.decide(.hitLengthCap) == .fallbackToast)
        #expect(coord.decide(.hitDailyCap) == .fallbackToast)
    }

    @Test func settingsUpgradeBypassesSessionFlag() {
        let (coord, _) = freshCoordinator()
        _ = coord.decide(.endOfOnboarding)
        // .settingsUpgrade ignores throttling — user explicitly tapped Upgrade.
        #expect(coord.decide(.settingsUpgrade) == .present)
    }

    @Test func dismissCountReachesThresholdFallsBackToToast() {
        let (coord, _) = freshCoordinator()
        // Dismissing the same cap-hit reason 5 times → throttled, but
        // toast still fires (no silent rejection).
        for _ in 0..<5 { coord.recordDismiss(.hitDailyCap) }
        #expect(coord.decide(.hitDailyCap) == .fallbackToast)
    }

    @Test func dismissCountReachesThresholdSuppressesProactive() {
        let (coord, _) = freshCoordinator()
        for _ in 0..<5 { coord.recordDismiss(.endOfOnboarding) }
        // Proactive reasons go silent — onboarding moment passed.
        #expect(coord.decide(.endOfOnboarding) == .suppress)
    }

    @Test func differentReasonNotAffectedByDismissCount() {
        let (coord, _) = freshCoordinator()
        for _ in 0..<5 { coord.recordDismiss(.hitDailyCap) }
        // Different reason still surfaces.
        #expect(coord.decide(.endOfOnboarding) == .present)
    }

    @Test func resetSessionClearsFlag() {
        let (coord, _) = freshCoordinator()
        _ = coord.decide(.endOfOnboarding)
        coord.resetSession()
        #expect(coord.decide(.hitDailyCap) == .present)
    }

    @Test func presentMarksSessionShownInternally() {
        let (coord, _) = freshCoordinator()
        #expect(coord.hasShownPaywallThisSession == false)
        _ = coord.decide(.hitDailyCap)
        #expect(coord.hasShownPaywallThisSession == true)
    }

    @Test func fallbackToastDoesNotConsumeSessionFlag() {
        let (coord, _) = freshCoordinator()
        _ = coord.decide(.endOfOnboarding)
        // Cap-hit throttled to toast — session flag was already set by the
        // first decide and doesn't get re-set by a non-present decision.
        #expect(coord.decide(.hitLengthCap) == .fallbackToast)
        // The flag stays true; resetSession is the only way to clear it.
        #expect(coord.hasShownPaywallThisSession == true)
    }
}
