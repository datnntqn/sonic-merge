import Testing
import Foundation
import BackgroundTasks
import UserNotifications
@testable import SonicMerge

struct BackgroundTranscriptionTaskTests {

    @Test func testIdentifierMatchesInfoPlistRequirement() {
        #expect(BackgroundTranscriptionTask.identifier == "com.dtech.SonicMerge.smartcut.transcribe")
    }

    @Test func testRequestBuilderProducesNonExternalPowerLowPriorityRequest() {
        let req = BackgroundTranscriptionTask.makeRequest()
        #expect(req.identifier == BackgroundTranscriptionTask.identifier)
        #expect(req.requiresExternalPower == false)
        #expect(req.requiresNetworkConnectivity == false)
    }

    @Test func testNotificationContentHasExpectedTitleAndPayload() {
        let content = BackgroundTranscriptionTask.makeCompletionNotificationContent(
            sourceHash: "abc123",
            fillerCount: 47
        )
        #expect(content.title.lowercased().contains("smart cut"))
        #expect(content.body.contains("47"))
        #expect((content.userInfo["smartCutCompletedFor"] as? String) == "abc123")
    }

    @Test func testSourceLocatorRoundTrip() {
        let url = URL(fileURLWithPath: "/tmp/test-\(UUID().uuidString).wav")
        let hash = "round-trip-\(UUID().uuidString)"
        SmartCutSourceLocator.register(hash: hash, url: url)
        let resolved = SmartCutSourceLocator.lookupURL(forHash: hash)
        #expect(resolved?.path == url.path)
    }

    @Test func testSourceLocatorReturnsNilForUnknownHash() {
        let resolved = SmartCutSourceLocator.lookupURL(forHash: "unknown-\(UUID().uuidString)")
        #expect(resolved == nil)
    }
}
