import Testing
import SwiftUI
@testable import SonicMerge

@MainActor
struct PaywallViewTests {

    /// PaywallView reads `@Environment(EntitlementService.self)` and
    /// `@Environment(\.storeKitClient)`. Both MUST be injected or the
    /// view crashes on render with "No observable EntitlementService found."
    private func makeView(reason: PaywallReason, scheme: ColorScheme) -> some View {
        let entitlements = EntitlementService()
        // storeKitClient is intentionally left nil — render-only smoke test.
        // PaywallView guards `loadProducts()` with `guard let client` so a
        // nil client renders the empty state without crashing.
        return PaywallView(reason: reason)
            .environment(entitlements)
            .environment(\.sonicMergeSemantic, .resolved(colorScheme: scheme, preference: scheme == .dark ? .dark : .light))
    }

    @Test func rendersInLightMode() {
        let renderer = ImageRenderer(content: makeView(reason: .settingsUpgrade, scheme: .light).frame(width: 390, height: 800))
        renderer.scale = 1
        #expect(renderer.uiImage != nil)
    }

    @Test func rendersInDarkMode() {
        let renderer = ImageRenderer(content: makeView(reason: .settingsUpgrade, scheme: .dark).frame(width: 390, height: 800))
        renderer.scale = 1
        #expect(renderer.uiImage != nil)
    }

    @Test func rendersAllReasons() {
        let reasons: [PaywallReason] = [.endOfOnboarding, .hitDailyCap, .hitLengthCap, .watermarkExport, .settingsUpgrade, .trialExpired]
        for reason in reasons {
            let renderer = ImageRenderer(content: makeView(reason: reason, scheme: .dark).frame(width: 390, height: 800))
            renderer.scale = 1
            #expect(renderer.uiImage != nil, "Failed to render reason: \(reason)")
        }
    }
}
