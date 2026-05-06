import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct EntitlementServiceTests {

    @Test func defaultEntitlementIsFree() {
        let svc = EntitlementService()
        #expect(svc.currentEntitlement == .free)
        #expect(svc.isPro == false)
    }

    @Test func setEntitlementUpdatesIsPro() {
        let svc = EntitlementService()
        svc.setEntitlement(.lifetime)
        #expect(svc.currentEntitlement == .lifetime)
        #expect(svc.isPro == true)
    }

    @Test func gateAlwaysAllowedInSubProject1() {
        let svc = EntitlementService()
        // Free user — but Sub-project 1 doesn't gate yet. Always .allowed.
        // NOTE: Sub-project 2 has now wired real semantics, so this test
        // documents that the old expectation was provisional. The new tests
        // below verify correct behavior.
        #expect(svc.gate(.smartCutSession) == .allowed)
        #expect(svc.gate(.smartCutLength(seconds: 9999)) == .requiresPro(reason: .hitLengthCap))
        #expect(svc.gate(.removeWatermark) == .requiresPro(reason: .watermarkExport))
    }

    // MARK: - gate(_:) — Sub-project 2

    @Test func proUserAlwaysAllowed() {
        let svc = EntitlementService()
        svc.setEntitlement(.lifetime)

        let cases: [ProFeature] = [
            .smartCutSession, .smartCutLength(seconds: 99999),
            .denoiseSession, .denoiseLength(seconds: 99999),
            .mergeClipCount(count: 999),
            .exportFormat(format: .mp3),
            .removeWatermark, .customFillerLibrary, .backgroundProcessing
        ]
        for feature in cases {
            #expect(svc.gate(feature) == .allowed, "Pro should be allowed for \(feature)")
        }
    }

    @Test func freeSmartCutSessionDailyCap() {
        let suite = "EntitlementServiceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let tracker = DailyUsageTracker(
            defaults: defaults,
            calendar: Calendar(identifier: .gregorian),
            dateProvider: { Date(timeIntervalSince1970: 1714824000) }
        )
        let svc = EntitlementService(usageTracker: tracker)
        // 0, 1, 2 → allowed; 3 → denied
        for _ in 0..<3 {
            #expect(svc.gate(.smartCutSession) == .allowed)
            tracker.increment(.smartCut)
        }
        #expect(svc.gate(.smartCutSession) == .requiresPro(reason: .hitDailyCap))
    }

    @Test func freeSmartCutLengthCap() {
        let svc = EntitlementService()
        #expect(svc.gate(.smartCutLength(seconds: 299)) == .allowed)
        #expect(svc.gate(.smartCutLength(seconds: 300)) == .allowed)  // 5:00 exactly is OK
        #expect(svc.gate(.smartCutLength(seconds: 301)) == .requiresPro(reason: .hitLengthCap))
    }

    @Test func freeDenoiseLengthCap() {
        let svc = EntitlementService()
        #expect(svc.gate(.denoiseLength(seconds: 180)) == .allowed)
        #expect(svc.gate(.denoiseLength(seconds: 181)) == .requiresPro(reason: .hitLengthCap))
    }

    @Test func freeMergeClipCountCap() {
        let svc = EntitlementService()
        #expect(svc.gate(.mergeClipCount(count: 3)) == .allowed)
        #expect(svc.gate(.mergeClipCount(count: 4)) == .requiresPro(reason: .hitLengthCap))
        // .hitLengthCap is the closest existing reason for "your input exceeds free." If
        // we want a distinct .hitClipCountCap later, add it to PaywallReason — for v1
        // we share the reason because the headline copy reads the same.
    }

    @Test func freeExportFormat() {
        let svc = EntitlementService()
        #expect(svc.gate(.exportFormat(format: .wav)) == .allowed)
        #expect(svc.gate(.exportFormat(format: .m4a)) == .requiresPro(reason: .watermarkExport))
        #expect(svc.gate(.exportFormat(format: .mp3)) == .requiresPro(reason: .watermarkExport))
    }

    @Test func freeRemoveWatermark() {
        let svc = EntitlementService()
        #expect(svc.gate(.removeWatermark) == .requiresPro(reason: .watermarkExport))
    }

    @Test func freeCustomFillerLibrary() {
        let svc = EntitlementService()
        #expect(svc.gate(.customFillerLibrary) == .requiresPro(reason: .settingsUpgrade))
        // .settingsUpgrade is the user-explicitly-chose-to-upgrade reason; library
        // editing is a Settings-adjacent feature so it shares that reason.
    }

    @Test func freeBackgroundProcessing() {
        let svc = EntitlementService()
        #expect(svc.gate(.backgroundProcessing) == .requiresPro(reason: .settingsUpgrade))
    }
}
