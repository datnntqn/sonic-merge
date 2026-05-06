import Testing
import SwiftUI
@testable import SonicMerge

@MainActor
struct SettingsViewTests {

    @Test func rendersFreeTier() {
        let entitlements = EntitlementService()
        entitlements.setEntitlement(.free)
        let view = NavigationStack {
            SettingsView()
        }
        .environment(entitlements)
        .environment(\.sonicMergeSemantic, .resolved(colorScheme: .light, preference: .light))

        let renderer = ImageRenderer(content: view.frame(width: 390, height: 700))
        renderer.scale = 1
        #expect(renderer.uiImage != nil)
    }

    @Test func rendersProTier() {
        let entitlements = EntitlementService()
        entitlements.setEntitlement(.lifetime)
        let view = NavigationStack {
            SettingsView()
        }
        .environment(entitlements)
        .environment(\.sonicMergeSemantic, .resolved(colorScheme: .dark, preference: .dark))

        let renderer = ImageRenderer(content: view.frame(width: 390, height: 700))
        renderer.scale = 1
        #expect(renderer.uiImage != nil)
    }
}
