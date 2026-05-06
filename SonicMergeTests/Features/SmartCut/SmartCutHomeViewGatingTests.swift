import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct SmartCutHomeViewGatingTests {

    private func freshTracker() -> DailyUsageTracker {
        let suite = "SmartCutGatingTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return DailyUsageTracker(
            defaults: defaults,
            calendar: Calendar(identifier: .gregorian),
            dateProvider: { Date(timeIntervalSince1970: 1714824000) }
        )
    }

    @Test func freeUserUnderCapsAllowed() {
        let svc = EntitlementService(usageTracker: freshTracker())
        let decision = SmartCutHomeView.ImportDecision.gate(
            durationSeconds: 60,
            entitlements: svc
        )
        #expect(decision == nil)
    }

    @Test func freeUserExceedsLengthCap() {
        let svc = EntitlementService(usageTracker: freshTracker())
        let decision = SmartCutHomeView.ImportDecision.gate(
            durationSeconds: 301,
            entitlements: svc
        )
        #expect(decision == .hitLengthCap)
    }

    @Test func freeUserHitsDailyCap() {
        let tracker = freshTracker()
        let svc = EntitlementService(usageTracker: tracker)
        for _ in 0..<3 { svc.recordSmartCutSession() }
        let decision = SmartCutHomeView.ImportDecision.gate(
            durationSeconds: 60,
            entitlements: svc
        )
        #expect(decision == .hitDailyCap)
    }

    @Test func proUserBypassesAllCaps() {
        let svc = EntitlementService(usageTracker: freshTracker())
        svc.setEntitlement(.lifetime)
        for _ in 0..<10 { svc.recordSmartCutSession() }  // count irrelevant for Pro
        let decision = SmartCutHomeView.ImportDecision.gate(
            durationSeconds: 9999,
            entitlements: svc
        )
        #expect(decision == nil)
    }

    @Test func lengthCapTakesPrecedenceOverDailyCap() {
        let tracker = freshTracker()
        let svc = EntitlementService(usageTracker: tracker)
        for _ in 0..<3 { svc.recordSmartCutSession() }
        let decision = SmartCutHomeView.ImportDecision.gate(
            durationSeconds: 9999,
            entitlements: svc
        )
        // Both caps fail. The order of checks gives length first → user
        // sees the .hitLengthCap copy (more specific message).
        #expect(decision == .hitLengthCap)
    }
}
