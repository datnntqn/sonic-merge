import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct EntitlementServiceMirrorTests {

    private func freshService() -> (EntitlementService, UserDefaults) {
        let suite = "EntitlementMirrorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let service = EntitlementService(sharedDefaults: defaults)
        return (service, defaults)
    }

    @Test func defaultEntitlementMirrorsFree() {
        let (_, defaults) = freshService()
        // Construction alone should not write — only setEntitlement triggers
        // the mirror. The Share Extension's default-false reading therefore
        // correctly treats fresh installs as Free.
        let raw = defaults.object(forKey: EntitlementService.isProMirrorKey)
        #expect(raw == nil)
    }

    @Test func setProWritesTrueToMirror() {
        let (service, defaults) = freshService()
        service.setEntitlement(.pro(expiresAt: Date().addingTimeInterval(86400)))
        #expect(defaults.bool(forKey: EntitlementService.isProMirrorKey) == true)
    }

    @Test func setLifetimeWritesTrueToMirror() {
        let (service, defaults) = freshService()
        service.setEntitlement(.lifetime)
        #expect(defaults.bool(forKey: EntitlementService.isProMirrorKey) == true)
    }

    @Test func setFreeWritesFalseToMirror() {
        let (service, defaults) = freshService()
        service.setEntitlement(.pro(expiresAt: Date().addingTimeInterval(86400)))
        #expect(defaults.bool(forKey: EntitlementService.isProMirrorKey) == true)
        service.setEntitlement(.free)
        #expect(defaults.bool(forKey: EntitlementService.isProMirrorKey) == false)
    }
}
