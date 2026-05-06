import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct DenoiseHomeViewGatingTests {

    private func freshTracker() -> DailyUsageTracker {
        let suite = "DenoiseGatingTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return DailyUsageTracker(
            defaults: defaults,
            calendar: Calendar(identifier: .gregorian),
            dateProvider: { Date(timeIntervalSince1970: 1714824000) }
        )
    }

    @Test func freeUserUnderCapsAllowed() {
        let svc = EntitlementService(usageTracker: freshTracker())
        let decision = DenoiseHomeView.ImportDecision.gate(durationSeconds: 60, entitlements: svc)
        #expect(decision == nil)
    }

    @Test func freeUserExceedsLengthCap() {
        let svc = EntitlementService(usageTracker: freshTracker())
        // Denoise free length = 180s = 3 min
        let decision = DenoiseHomeView.ImportDecision.gate(durationSeconds: 181, entitlements: svc)
        #expect(decision == .hitLengthCap)
    }

    @Test func freeUserHitsDailyCap() {
        let tracker = freshTracker()
        let svc = EntitlementService(usageTracker: tracker)
        for _ in 0..<3 { svc.recordDenoiseSession() }
        let decision = DenoiseHomeView.ImportDecision.gate(durationSeconds: 60, entitlements: svc)
        #expect(decision == .hitDailyCap)
    }

    @Test func proUserBypassesAllCaps() {
        let svc = EntitlementService(usageTracker: freshTracker())
        svc.setEntitlement(.lifetime)
        let decision = DenoiseHomeView.ImportDecision.gate(durationSeconds: 9999, entitlements: svc)
        #expect(decision == nil)
    }
}
