import Testing
@testable import SonicMerge

struct SubscriptionProductTests {

    @Test func tierMonthly() {
        let p = SubscriptionProduct(
            id: "com.cleancut.pro.monthly",
            displayPrice: "$4.99",
            tier: .monthly,
            monthlyEquivalent: nil,
            isEligibleForIntroOffer: true
        )
        #expect(p.periodLabel == "/mo")
        #expect(p.tier == .monthly)
        #expect(p.monthlyEquivalent == nil)
        #expect(p.isEligibleForIntroOffer == true)
    }

    @Test func tierYearly() {
        let p = SubscriptionProduct(
            id: "com.cleancut.pro.yearly",
            displayPrice: "$39.99",
            tier: .yearly,
            monthlyEquivalent: "$3.33",
            isEligibleForIntroOffer: true
        )
        #expect(p.periodLabel == "/yr")
        #expect(p.monthlyEquivalent == "$3.33")
    }

    @Test func tierLifetime() {
        let p = SubscriptionProduct(
            id: "com.cleancut.pro.lifetime",
            displayPrice: "$79.99",
            tier: .lifetime,
            monthlyEquivalent: nil,
            isEligibleForIntroOffer: false
        )
        #expect(p.periodLabel == "once")
    }
}
