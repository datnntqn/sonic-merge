import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct ReviewPromptCoordinatorTests {

    private func freshCoordinator(
        installedDaysAgo: Int = 5,
        paywallShown: Bool = false
    ) -> (ReviewPromptCoordinator, ReviewMetricsStore, PaywallTriggerCoordinator) {
        let suite = "ReviewCoordTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = ReviewMetricsStore(defaults: defaults)
        _ = store.installDate
        let earlier = Date().addingTimeInterval(-86400 * Double(installedDaysAgo))
        defaults.set(earlier, forKey: "ReviewMetrics.installDate")
        let paywall = PaywallTriggerCoordinator(defaults: defaults)
        if paywallShown { paywall.markPresented(.hitDailyCap) }
        let coord = ReviewPromptCoordinator(metrics: store, paywallCoordinator: paywall)
        return (coord, store, paywall)
    }

    @Test func belowExportThresholdSuppresses() {
        let (coord, store, _) = freshCoordinator()
        #expect(coord.shouldPromptNow() == false)
        store.incrementExportCount()
        #expect(coord.shouldPromptNow() == false)
        store.incrementExportCount()
        #expect(coord.shouldPromptNow() == false)
    }

    @Test func threeExportsAndOldEnoughInstallAllows() {
        let (coord, store, _) = freshCoordinator(installedDaysAgo: 5)
        for _ in 0..<3 { store.incrementExportCount() }
        #expect(coord.shouldPromptNow() == true)
    }

    @Test func recentInstallSuppresses() {
        let (coord, store, _) = freshCoordinator(installedDaysAgo: 1)
        for _ in 0..<5 { store.incrementExportCount() }
        #expect(coord.shouldPromptNow() == false)
    }

    @Test func paywallShownSessionSuppresses() {
        let (coord, store, _) = freshCoordinator(installedDaysAgo: 5, paywallShown: true)
        for _ in 0..<5 { store.incrementExportCount() }
        #expect(coord.shouldPromptNow() == false)
    }

    @Test func cooldownActiveSuppresses() {
        let (coord, store, _) = freshCoordinator(installedDaysAgo: 100)
        for _ in 0..<5 { store.incrementExportCount() }
        store.lastPromptDate = Date().addingTimeInterval(-86400 * 30)
        #expect(coord.shouldPromptNow() == false)
    }

    @Test func cooldownExpiredAllows() {
        let (coord, store, _) = freshCoordinator(installedDaysAgo: 200)
        for _ in 0..<5 { store.incrementExportCount() }
        store.lastPromptDate = Date().addingTimeInterval(-86400 * 100)
        #expect(coord.shouldPromptNow() == true)
    }

    @Test func recordExportIncrementsCount() {
        let (coord, store, _) = freshCoordinator()
        coord.recordExport()
        #expect(store.exportCount == 1)
    }

    @Test func markPromptedSetsLastPromptDate() {
        let (coord, store, _) = freshCoordinator()
        let before = Date()
        coord.markPrompted()
        let after = Date()
        let stamp = store.lastPromptDate
        #expect(stamp != nil)
        #expect(stamp! >= before)
        #expect(stamp! <= after)
    }
}
