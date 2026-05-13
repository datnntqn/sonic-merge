import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct PaywallTriggerCoordinatorIntegrationTests {

    private func freshCoordinator() -> PaywallTriggerCoordinator {
        let suite = "PaywallCoordIntTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return PaywallTriggerCoordinator(defaults: defaults)
    }

    @Test func firstReasonPresents() {
        let coord = freshCoordinator()
        #expect(coord.decide(.hitDailyCap) == .present)
        #expect(coord.hasShownPaywallThisSession == true)
    }

    @Test func secondCapHitInSessionFallsBackToToast() {
        let coord = freshCoordinator()
        _ = coord.decide(.hitDailyCap)
        #expect(coord.decide(.hitLengthCap) == .fallbackToast)
    }

    @Test func settingsUpgradeBypassesSessionThrottle() {
        let coord = freshCoordinator()
        _ = coord.decide(.hitDailyCap)
        #expect(coord.decide(.settingsUpgrade) == .present)
    }

    @Test func endOfOnboardingIsSuppressedAfterThrottle() {
        let coord = freshCoordinator()
        _ = coord.decide(.hitDailyCap)
        #expect(coord.decide(.endOfOnboarding) == .suppress)
    }

    @Test func dismissThresholdReachedFallsBackToToast() {
        let coord = freshCoordinator()
        for _ in 0..<5 { coord.recordDismiss(.hitDailyCap) }
        #expect(coord.decide(.hitDailyCap) == .fallbackToast)
    }

    @Test func dismissCounterPersistsAcrossInstances() {
        let suite = "PaywallCoordPersistTest-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let coord1 = PaywallTriggerCoordinator(defaults: defaults)
        for _ in 0..<5 { coord1.recordDismiss(.hitDailyCap) }
        let coord2 = PaywallTriggerCoordinator(defaults: defaults)
        #expect(coord2.decide(.hitDailyCap) == .fallbackToast)
    }

    @Test func resetSessionRehydratesPresentation() {
        let coord = freshCoordinator()
        _ = coord.decide(.hitDailyCap)
        #expect(coord.decide(.hitLengthCap) == .fallbackToast)
        coord.resetSession()
        #expect(coord.decide(.hitLengthCap) == .present)
    }
}
