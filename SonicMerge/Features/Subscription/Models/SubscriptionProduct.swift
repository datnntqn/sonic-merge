import Foundation

/// View-friendly wrapper around StoreKit's `Product`. The paywall reads
/// only this type; `StoreKitClient` is the only place `Product` itself
/// appears. Decouples view code from StoreKit.
struct SubscriptionProduct: Equatable, Identifiable, Sendable {
    let id: String                          // App Store product ID
    let displayPrice: String                // localized e.g. "$4.99" / "₹450" / "¥600"
    let tier: Tier
    /// Localized monthly-equivalent string for yearly tier (e.g. "$3.33/mo").
    /// Computed in `StoreKitClient.bridgeToSubscriptionProduct(_:)` from the
    /// real `Product.price / 12` rendered with the product's locale.
    /// `nil` for monthly + lifetime. Required by Apple 3.1.2(a) — must reflect
    /// what the user will actually be charged, not a hardcoded value.
    let monthlyEquivalent: String?
    /// Whether the user is eligible for the 7-day introductory free trial on
    /// this product. False if user has already used the intro offer (Apple
    /// tracks this server-side via `Product.subscription.isEligibleForIntroOffer`).
    /// Drives CTA copy: "Start 7-day free trial" vs "Subscribe" — required
    /// for Apple 3.1.2(a) plain-language disclosure (no false trial promises).
    let isEligibleForIntroOffer: Bool

    enum Tier: Equatable, Sendable {
        case monthly
        case yearly
        case lifetime
    }

    var periodLabel: String {
        switch tier {
        case .monthly: return "/mo"
        case .yearly: return "/yr"
        case .lifetime: return "once"
        }
    }
}

/// Product IDs — match the App Store Connect IAP setup.
enum SubscriptionProductID {
    static let monthly = "com.cleancut.pro.monthly"
    static let yearly = "com.cleancut.pro.yearly"
    static let lifetime = "com.cleancut.pro.lifetime"
    static let allIDs: [String] = [monthly, yearly, lifetime]
}
