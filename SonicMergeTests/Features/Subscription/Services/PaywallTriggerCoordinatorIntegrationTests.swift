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
        #expect(coord.shouldPresent(.hitDailyCap) == true)
        coord.markPresented(.hitDailyCap)
        #expect(coord.hasShownPaywallThisSession == true)
    }

    @Test func secondReasonInSessionSuppressed() {
        let coord = freshCoordinator()
        coord.markPresented(.hitDailyCap)
        #expect(coord.shouldPresent(.hitLengthCap) == false)
    }

    @Test func settingsUpgradeBypassesSessionThrottle() {
        let coord = freshCoordinator()
        coord.markPresented(.hitDailyCap)
        #expect(coord.shouldPresent(.settingsUpgrade) == true)
    }

    @Test func endOfOnboardingDoesNotBypassSessionThrottle() {
        let coord = freshCoordinator()
        coord.markPresented(.hitDailyCap)
        #expect(coord.shouldPresent(.endOfOnboarding) == false)
    }

    @Test func dismissThresholdReachedSuppresses() {
        let coord = freshCoordinator()
        for _ in 0..<5 { coord.recordDismiss(.hitDailyCap) }
        #expect(coord.shouldPresent(.hitDailyCap) == false)
    }

    @Test func dismissCounterPersistsAcrossInstances() {
        let suite = "PaywallCoordPersistTest-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let coord1 = PaywallTriggerCoordinator(defaults: defaults)
        for _ in 0..<5 { coord1.recordDismiss(.hitDailyCap) }
        let coord2 = PaywallTriggerCoordinator(defaults: defaults)
        #expect(coord2.shouldPresent(.hitDailyCap) == false)
    }

    @Test func resetSessionRehydratesPresentation() {
        let coord = freshCoordinator()
        coord.markPresented(.hitDailyCap)
        #expect(coord.shouldPresent(.hitLengthCap) == false)
        coord.resetSession()
        #expect(coord.shouldPresent(.hitLengthCap) == true)
    }
}
