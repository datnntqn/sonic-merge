import Testing
import Foundation
@testable import SonicMerge

struct EntitlementTests {

    @Test func freeIsNotPro() {
        let e: Entitlement = .free
        #expect(e.isPro == false)
        #expect(e.isLifetime == false)
    }

    @Test func proWithFutureExpirationIsPro() {
        let e: Entitlement = .pro(expiresAt: Date(timeIntervalSinceNow: 86400))
        #expect(e.isPro == true)
        #expect(e.isLifetime == false)
    }

    @Test func proWithPastExpirationIsNotPro() {
        let e: Entitlement = .pro(expiresAt: Date(timeIntervalSinceNow: -1))
        #expect(e.isPro == false)
    }

    @Test func lifetimeIsAlwaysPro() {
        let e: Entitlement = .lifetime
        #expect(e.isPro == true)
        #expect(e.isLifetime == true)
    }

    @Test func displayLabelMatchesTier() {
        #expect(Entitlement.free.displayLabel == "Free")
        #expect(Entitlement.pro(expiresAt: Date(timeIntervalSinceNow: 86400)).displayLabel.contains("Pro"))
        #expect(Entitlement.lifetime.displayLabel == "Pro · Lifetime")
    }
}
