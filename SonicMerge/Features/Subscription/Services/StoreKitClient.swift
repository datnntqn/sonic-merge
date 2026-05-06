import Foundation
import SwiftUI
import StoreKit

/// Thin wrapper around StoreKit 2. The ONE place in the app that imports
/// StoreKit. Bridges `Product` ↔ `SubscriptionProduct`, `Transaction` ↔
/// `Entitlement`, and exposes purchase / restore as async functions.
///
/// Owns a long-running `Task` that listens to `Transaction.updates` for
/// the lifetime of the app (started in `init`, kept alive via a stored
/// reference). Whenever a transaction transitions (purchase, expire,
/// revoke, refund), it re-resolves the user's current entitlement and
/// calls `EntitlementService.setEntitlement(_:)`.
@MainActor
final class StoreKitClient {

    enum StoreKitError: Error {
        case productNotLoaded(id: String)
        case purchaseFailed(reason: String)
        case userCancelled
        case verificationFailed
    }

    private let entitlementService: EntitlementService
    private var products: [String: Product] = [:]
    private var transactionListener: Task<Void, Never>?

    init(entitlementService: EntitlementService) {
        self.entitlementService = entitlementService
        self.transactionListener = Task { [weak self] in
            await self?.listenForTransactions()
        }
        // Resolve initial state on launch.
        Task { [weak self] in
            await self?.refreshCurrentEntitlement()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    /// Loads all 3 products from the App Store (or `.storekit` config in
    /// debug) and caches them. Returns view-friendly wrappers.
    /// `bridgeToSubscriptionProduct` is async because intro-offer eligibility
    /// requires an awaitable property on `Product.subscription`.
    func loadProducts() async throws -> [SubscriptionProduct] {
        let storeProducts = try await Product.products(for: SubscriptionProductID.allIDs)
        for p in storeProducts {
            products[p.id] = p
        }
        var bridged: [SubscriptionProduct] = []
        for p in storeProducts {
            if let sp = await Self.bridgeToSubscriptionProduct(p) {
                bridged.append(sp)
            }
        }
        return bridged
    }

    /// Purchases `productID`. On success, the `Transaction.updates`
    /// listener fires and updates `EntitlementService` automatically.
    func purchase(productID: String) async throws {
        guard let product = products[productID] else {
            throw StoreKitError.productNotLoaded(id: productID)
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                await refreshCurrentEntitlement()
            case .unverified:
                throw StoreKitError.verificationFailed
            }
        case .userCancelled:
            throw StoreKitError.userCancelled
        case .pending:
            // Apple SCA / parental approval flow — Transaction.updates will
            // fire later when resolved. Nothing to do now.
            break
        @unknown default:
            throw StoreKitError.purchaseFailed(reason: "Unknown StoreKit result")
        }
    }

    /// Restore Purchases — required by App Store guideline 3.1.1.
    func restore() async throws {
        try await AppStore.sync()
        await refreshCurrentEntitlement()
    }

    // MARK: - Private

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            guard case .verified(let transaction) = update else { continue }
            await transaction.finish()
            await refreshCurrentEntitlement()
        }
    }

    /// Iterates `Transaction.currentEntitlements` and reduces to one
    /// `Entitlement`. Lifetime trumps subscription; latest expiration
    /// wins between subscription transactions.
    private func refreshCurrentEntitlement() async {
        var resolved: Entitlement = .free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            switch transaction.productID {
            case SubscriptionProductID.lifetime:
                resolved = .lifetime
            case SubscriptionProductID.monthly, SubscriptionProductID.yearly:
                if case .lifetime = resolved { continue } // lifetime trumps
                if let expiration = transaction.expirationDate, expiration > .now {
                    // Keep the LATEST expiry — if `existing >= expiration`,
                    // we already have one that ends at the same time or
                    // later than this transaction's, so skip (don't
                    // overwrite). Otherwise fall through and overwrite
                    // with the later expiration.
                    if case .pro(let existing) = resolved, existing >= expiration {
                        continue
                    }
                    resolved = .pro(expiresAt: expiration)
                }
            default:
                continue
            }
        }
        entitlementService.setEntitlement(resolved)
    }

    static func bridgeToSubscriptionProduct(_ product: Product) async -> SubscriptionProduct? {
        let tier: SubscriptionProduct.Tier
        switch product.id {
        case SubscriptionProductID.monthly: tier = .monthly
        case SubscriptionProductID.yearly: tier = .yearly
        case SubscriptionProductID.lifetime: tier = .lifetime
        default: return nil
        }

        // Monthly equivalent for yearly tier — derived from real Product.price,
        // formatted with the product's locale, NOT a hardcoded "$3.33"
        // (Apple guideline 3.1.2(a) — disclosure must reflect actual charge).
        let monthlyEquivalent: String?
        if tier == .yearly {
            let perMonth = product.price / 12
            monthlyEquivalent = perMonth.formatted(product.priceFormatStyle)
        } else {
            monthlyEquivalent = nil
        }

        // Intro-offer eligibility from StoreKit. `nil` for non-subscriptions
        // (lifetime is non-consumable, so .isEligibleForIntroOffer is N/A and
        // we always return false for it). Subscriptions read from the
        // `Product.SubscriptionInfo`'s async property.
        let isEligible: Bool
        if let subscription = product.subscription {
            isEligible = await subscription.isEligibleForIntroOffer
        } else {
            isEligible = false
        }

        return SubscriptionProduct(
            id: product.id,
            displayPrice: product.displayPrice,
            tier: tier,
            monthlyEquivalent: monthlyEquivalent,
            isEligibleForIntroOffer: isEligible
        )
    }
}

// MARK: - Environment injection

private struct StoreKitClientKey: EnvironmentKey {
    static let defaultValue: StoreKitClient? = nil
}

extension EnvironmentValues {
    /// Hoisted at app-level (RootTabView) so PaywallView + SettingsView
    /// share ONE StoreKitClient instance — not two (which would start two
    /// Transaction.updates listeners and double-fire entitlement updates).
    var storeKitClient: StoreKitClient? {
        get { self[StoreKitClientKey.self] }
        set { self[StoreKitClientKey.self] = newValue }
    }
}
