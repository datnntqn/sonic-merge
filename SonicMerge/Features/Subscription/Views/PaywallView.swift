import SwiftUI
import StoreKit

/// Variant A paywall: annual default + toggle. Approved in brainstorming
/// at `docs/superpowers/specs/2026-05-04-monetization-design.md` §"Paywall UI".
///
/// Apple requirements (guidelines 3.1.1, 3.1.2, 5.1.1):
/// - Restore Purchases visible
/// - Plain-language price + period + auto-renew + cancel-anytime
/// - Terms + Privacy links
struct PaywallView: View {

    let reason: PaywallReason

    @Environment(\.dismiss) private var dismiss
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.storeKitClient) private var client
    @Environment(EntitlementService.self) private var entitlementService

    @State private var selectedTier: SubscriptionProduct.Tier = .yearly
    @State private var products: [SubscriptionProduct] = []
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var purchaseError: String?

    private static let testimonials: [TestimonialQuote] = [
        TestimonialQuote(stars: 5, quote: "Cleaned a 45-min interview in 30 seconds. My old workflow took 2 hours.", author: "Jamie, podcast editor"),
        TestimonialQuote(stars: 5, quote: "On-device means I can clean voice memos on a flight. Game-changing for journalists.", author: "Priya, freelance reporter"),
        TestimonialQuote(stars: 5, quote: "The fillers detection is shockingly accurate. Saved me hours.", author: "Alex, audiobook narrator")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    hero
                    featureRow
                    pricingBlock
                    checklist
                    testimonialSlot
                    Color.clear.frame(height: 100)  // sticky-CTA spacer
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            stickyCTA
        }
        .background(Color(uiColor: semantic.surfaceBase))
        .task { await loadProducts() }
        .alert("Purchase failed", isPresented: Binding(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(purchaseError ?? "")
        }
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(uiColor: semantic.textSecondary).opacity(0.5))
                }
                .accessibilityLabel("Close paywall")
            }
            if reason == .endOfOnboarding {
                Text("🎉 You're all set")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(uiColor: semantic.accentAI).opacity(0.15)))
                    .foregroundStyle(Color(uiColor: semantic.accentAI))
                    .accessibilityIdentifier("PaywallView.celebratoryBadge")
            }
            SmartCutMark(size: .hero)
                .frame(width: 56, height: 56)
            Text("Your audio never leaves your phone.")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            Text("CleanCut Pro")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(LinearGradient(
                    colors: semantic.accentAIGradientStops.map { Color(uiColor: $0) },
                    startPoint: .leading,
                    endPoint: .trailing
                ))
            Text(reasonHeadline)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                .multilineTextAlignment(.center)
        }
    }

    private var reasonHeadline: String {
        Self.headlineCopy(for: reason)
    }

    static func headlineCopy(for reason: PaywallReason) -> String {
        switch reason {
        case .endOfOnboarding: return "Cut fillers. Clean noise. No limits."
        case .hitDailyCap: return "You've used your daily free quota. Pro = unlimited."
        case .hitLengthCap: return "This clip is longer than free supports. Pro = any length."
        case .watermarkExport: return "Pro removes the export watermark."
        case .settingsUpgrade: return "Cut fillers. Clean noise. No limits."
        case .trialExpired: return "Your trial ended. Keep unlimited access?"
        }
    }

    private var featureRow: some View {
        HStack(spacing: 8) {
            featurePill(icon: "infinity", label: "Unlimited\nsessions")
            featurePill(icon: "drop.fill", label: "No\nwatermark")
            featurePill(icon: "clock.fill", label: "Any\nlength")
        }
    }

    private func featurePill(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(uiColor: semantic.accentAI))
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: semantic.surfaceCard))
        )
    }

    private var pricingBlock: some View {
        VStack(spacing: 12) {
            Picker("Tier", selection: $selectedTier) {
                Text("Monthly").tag(SubscriptionProduct.Tier.monthly)
                Text("Yearly").tag(SubscriptionProduct.Tier.yearly)
                Text("Lifetime").tag(SubscriptionProduct.Tier.lifetime)
            }
            .pickerStyle(.segmented)

            if let p = products.first(where: { $0.tier == selectedTier }) {
                priceCard(for: p)
            } else {
                ProgressView().padding(.vertical, 30)
            }
        }
    }

    private func priceCard(for product: SubscriptionProduct) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(product.displayPrice)
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
                Text(product.periodLabel)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
            }
            Text(priceSubtext(for: product))
                .font(.caption)
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(
                    colors: semantic.accentAIGradientStops.map { Color(uiColor: $0).opacity(0.10) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color(uiColor: semantic.accentAction), lineWidth: 1.5)
                )
        )
        .overlay(alignment: .topTrailing) {
            if product.tier == .yearly {
                Text("SAVE 58%")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(LinearGradient(
                        colors: [Color(uiColor: SonicMergeTheme.ColorPalette.emberRed),
                                 Color(uiColor: SonicMergeTheme.ColorPalette.magentaAccent)],
                        startPoint: .leading, endPoint: .trailing
                    )))
                    .offset(x: -16, y: -8)
            }
        }
    }

    /// Composes the small print under the price card. Apple guideline 3.1.2(a)
    /// requires plain-language disclosure that reflects the actual charge — so
    /// the monthly equivalent for yearly comes from `product.monthlyEquivalent`
    /// (computed in `StoreKitClient.bridgeToSubscriptionProduct`), NOT a
    /// hardcoded "$3.33". The "7-day free trial" copy only appears when
    /// `isEligibleForIntroOffer == true` (i.e., the user hasn't used the trial
    /// before — otherwise showing "free trial" would be deceptive).
    private func priceSubtext(for product: SubscriptionProduct) -> String {
        let trialPart = product.isEligibleForIntroOffer ? "7-day free trial · " : ""
        switch product.tier {
        case .monthly:
            return "\(trialPart)Cancel anytime · Auto-renews"
        case .yearly:
            let monthly = product.monthlyEquivalent.map { "\($0)/mo · " } ?? ""
            return "\(monthly)\(trialPart)Auto-renews"
        case .lifetime:
            return "One-time payment · No renewal"
        }
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 10) {
            checklistRow("Unlimited Smart Cut + Denoise")
            checklistRow("Files of any length")
            checklistRow("No export watermark")
            checklistRow("Custom filler libraries")
            checklistRow("Background processing + push")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func checklistRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: semantic.accentAIGradientStops.map { Color(uiColor: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(width: 18, height: 18)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
        }
    }

    private var testimonialSlot: some View {
        let quote = Self.testimonials.randomElement() ?? Self.testimonials[0]
        return VStack(alignment: .leading, spacing: 6) {
            Text(String(repeating: "★", count: quote.stars))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(uiColor: SonicMergeTheme.ColorPalette.emberOrange))
            Text("\u{201C}\(quote.quote)\u{201D}")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
            Text("— \(quote.author)")
                .font(.caption)
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: semantic.surfaceCard))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color(uiColor: semantic.accentAI))
                        .frame(width: 3)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
    }

    private var stickyCTA: some View {
        VStack(spacing: 8) {
            Button {
                Task { await purchaseSelected() }
            } label: {
                HStack {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(ctaLabel)
                            .font(.system(.body, design: .rounded, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(LinearGradient(
                    colors: semantic.accentAIGradientStops.map { Color(uiColor: $0) },
                    startPoint: .leading,
                    endPoint: .trailing
                )))
            }
            .disabled(isPurchasing || products.isEmpty)
            .accessibilityLabel(ctaLabel)

            HStack(spacing: 14) {
                RestorePurchasesButton(isRestoring: $isRestoring) {
                    try await client?.restore()
                }
                Text("·").foregroundStyle(Color(uiColor: semantic.textSecondary))
                Link("Terms", destination: URL(string: "https://datnntqn.github.io/clearcut-legal/terms.html")!)
                    .font(.footnote)
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
                Text("·").foregroundStyle(Color(uiColor: semantic.textSecondary))
                Link("Privacy", destination: URL(string: "https://datnntqn.github.io/clearcut-legal/privacy.html")!)
                    .font(.footnote)
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
            }
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            Color(uiColor: semantic.surfaceBase)
                .opacity(0.97)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    /// CTA copy depends on the selected tier AND the user's intro-offer
    /// eligibility on that tier. If they've used the trial before, the
    /// CTA says "Subscribe — $X.XX" rather than "Start 7-day free trial"
    /// (Apple 3.1.2(a) — no false trial promises).
    private var ctaLabel: String {
        let selected = products.first(where: { $0.tier == selectedTier })
        switch selectedTier {
        case .monthly:
            if selected?.isEligibleForIntroOffer == true {
                return "Start 7-day free trial"
            }
            return "Subscribe \u{2014} \(selected?.displayPrice ?? "$3.99")/mo"
        case .yearly:
            if selected?.isEligibleForIntroOffer == true {
                return "Start 7-day free trial"
            }
            return "Subscribe \u{2014} \(selected?.displayPrice ?? "$19.99")/yr"
        case .lifetime:
            return "Buy Lifetime \u{2014} \(selected?.displayPrice ?? "$39.99")"
        }
    }

    // MARK: - Actions

    private func loadProducts() async {
        guard let client else {
            purchaseError = "StoreKit not ready. Try again."
            return
        }
        do {
            products = try await client.loadProducts()
        } catch {
            purchaseError = "Couldn't load products: \(error.localizedDescription)"
        }
    }

    private func purchaseSelected() async {
        guard let client else { return }
        guard let product = products.first(where: { $0.tier == selectedTier }) else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await client.purchase(productID: product.id)
            // Successful purchase — Transaction.updates listener has flipped
            // entitlement. Dismiss the paywall.
            dismiss()
        } catch StoreKitClient.StoreKitError.userCancelled {
            // No-op — user backed out.
        } catch {
            purchaseError = error.localizedDescription
        }
    }
}

private struct TestimonialQuote: Hashable {
    let stars: Int
    let quote: String
    let author: String
}
