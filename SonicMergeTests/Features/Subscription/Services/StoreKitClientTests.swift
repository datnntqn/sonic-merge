import Testing
import Foundation
import StoreKit
import StoreKitTest
@testable import SonicMerge

@MainActor
struct StoreKitClientTests {

    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "CleanCut")
        session.disableDialogs = true
        session.clearTransactions()
        session.resetToDefaultState()
        return session
    }

    @Test func loadProductsReturnsThreeSKUs() async throws {
        let _ = try makeSession()
        let entitlements = EntitlementService()
        let client = StoreKitClient(entitlementService: entitlements)
        let products = try await client.loadProducts()
        #expect(products.count == 3)
        #expect(products.contains { $0.id == SubscriptionProductID.monthly })
        #expect(products.contains { $0.id == SubscriptionProductID.yearly })
        #expect(products.contains { $0.id == SubscriptionProductID.lifetime })
    }

    @Test func purchasingMonthlySetsEntitlementToPro() async throws {
        let session = try makeSession()
        let entitlements = EntitlementService()
        let client = StoreKitClient(entitlementService: entitlements)
        _ = try await client.loadProducts()

        // purchase() calls refreshCurrentEntitlement() inline before
        // returning, so we can assert immediately — no Task.sleep needed.
        try await client.purchase(productID: SubscriptionProductID.monthly)
        #expect(entitlements.isPro == true)
        _ = session  // keep alive
    }

    @Test func restoreAfterClearedTransactionsKeepsEntitlement() async throws {
        let session = try makeSession()
        let entitlements = EntitlementService()
        let client = StoreKitClient(entitlementService: entitlements)
        _ = try await client.loadProducts()

        try await client.purchase(productID: SubscriptionProductID.lifetime)
        #expect(entitlements.currentEntitlement == .lifetime)

        try await client.restore()
        #expect(entitlements.currentEntitlement == .lifetime)
        _ = session
    }
}
