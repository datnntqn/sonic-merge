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

    @Test func defaultShouldPresent() {
        let (coord, _) = freshCoordinator()
        #expect(coord.shouldPresent(.endOfOnboarding) == true)
    }

    @Test func sessionFlagBlocksSecondPresent() {
        let (coord, _) = freshCoordinator()
        coord.markPresented(.endOfOnboarding)
        #expect(coord.shouldPresent(.hitDailyCap) == false)
    }

    @Test func settingsUpgradeBypassesSessionFlag() {
        let (coord, _) = freshCoordinator()
        coord.markPresented(.endOfOnboarding)
        // .settingsUpgrade ignores throttling — user explicitly tapped Upgrade.
        #expect(coord.shouldPresent(.settingsUpgrade) == true)
    }

    @Test func dismissCountReachesThreshold() {
        let (coord, _) = freshCoordinator()
        // Dismissing the same reason 5 times suppresses it.
        for _ in 0..<5 { coord.recordDismiss(.hitDailyCap) }
        #expect(coord.shouldPresent(.hitDailyCap) == false)
    }

    @Test func differentReasonNotAffectedByDismissCount() {
        let (coord, _) = freshCoordinator()
        for _ in 0..<5 { coord.recordDismiss(.hitDailyCap) }
        // Different reason still surfaces.
        #expect(coord.shouldPresent(.endOfOnboarding) == true)
    }

    @Test func resetSessionClearsFlag() {
        let (coord, _) = freshCoordinator()
        coord.markPresented(.endOfOnboarding)
        coord.resetSession()
        #expect(coord.shouldPresent(.hitDailyCap) == true)
    }
}
