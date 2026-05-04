// SMOKE TESTS — see QA checklist in spec §11.3 for full integration coverage.
// These verify the storage layer behaves as expected; they do NOT exercise
// the @AppStorage SwiftUI integration in RootTabView or the .fullScreenCover
// presentation behavior. Manual QA covers those.

import Testing
import Foundation
@testable import SonicMerge

struct OnboardingGateTests {

    @Test func defaultGateIsFalse() {
        let defaults = UserDefaults(suiteName: "test-\(UUID())")!
        #expect(defaults.bool(forKey: "sonicMerge.hasOnboarded") == false)
    }

    @Test func gateRoundtripsAcrossInstances() {
        let suite = "test-\(UUID())"
        let writer = UserDefaults(suiteName: suite)!
        writer.set(true, forKey: "sonicMerge.hasOnboarded")
        let reader = UserDefaults(suiteName: suite)!
        #expect(reader.bool(forKey: "sonicMerge.hasOnboarded") == true)
    }
}
