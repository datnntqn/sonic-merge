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
        #expect(svc.gate(.smartCutSession) == .allowed)
        #expect(svc.gate(.smartCutLength(seconds: 9999)) == .allowed)
        #expect(svc.gate(.removeWatermark) == .allowed)
    }
}
