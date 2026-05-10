import Testing
import Foundation
import BackgroundTasks
import UserNotifications
@testable import SonicMerge

struct BackgroundTranscriptionTaskTests {

    @Test func testIdentifierMatchesInfoPlistRequirement() {
        #expect(BackgroundTranscriptionTask.identifier == "com.dtech.cleancut.smartcut.transcribe")
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

    @Test func testRawHashStripsKnownEngineSuffixes() {
        #expect(BackgroundTranscriptionTask.rawHash(from: "abcdef#cloud") == "abcdef")
        #expect(BackgroundTranscriptionTask.rawHash(from: "abcdef#local") == "abcdef")
        #expect(BackgroundTranscriptionTask.rawHash(from: "abcdef#analyzer") == "abcdef")
        #expect(BackgroundTranscriptionTask.rawHash(from: "abcdef") == "abcdef") // already raw
        #expect(BackgroundTranscriptionTask.rawHash(from: "abcdef#unknown") == "abcdef#unknown") // leave unknowns alone
    }

    @Test func testResumeRoutingForSFState_returnsSFService() {
        let state = TranscriptionState(
            sourceHash: "abc#cloud",
            sourceDuration: 60,
            chunkDurationSeconds: 30,
            completedChunkCount: 1,
            recognizedSegments: [],
            isComplete: false,
            localeIdentifier: "en-US",
            engine: .sfSpeechRecognizer,
            completedRecognizedDuration: 0,
            liveTranscriptText: ""
        )
        // 1. The locator is keyed by the RAW hash; the helper must strip #cloud.
        #expect(BackgroundTranscriptionTask.rawHash(from: state.sourceHash) == "abc")
        // 2. The factory takes localeIdentifier and returns the engine the BG task uses.
        let service = TranscriptionServiceFactory.make(
            localeIdentifier: state.localeIdentifier ?? "en-US"
        )
        if #available(iOS 26, *) {
            // On iOS 26+, the factory routes ALL non-"auto" identifiers to
            // SpeechAnalyzer. This is the documented spec edge case: a user
            // who upgrades from iOS 17–25 mid-resume gets routed to a different
            // engine; the analyzer's namespaced cache key won't match the
            // SF-written state, so it'll start fresh from t=0.
            #expect(service is SpeechAnalyzerTranscriptionService)
        } else {
            #expect(service is TranscriptionService)
        }
    }

    @Test func testResumeRoutingForAnalyzerState_returnsAnalyzerServiceOniOS26() {
        guard #available(iOS 26, *) else { return }
        let state = TranscriptionState(
            sourceHash: "abc#analyzer",
            sourceDuration: 60,
            chunkDurationSeconds: 0,
            completedChunkCount: 0,
            recognizedSegments: [],
            isComplete: false,
            localeIdentifier: "en-US",
            engine: .speechAnalyzer,
            completedRecognizedDuration: 12,
            liveTranscriptText: "Hello world"
        )
        #expect(BackgroundTranscriptionTask.rawHash(from: state.sourceHash) == "abc")
        let service = TranscriptionServiceFactory.make(
            localeIdentifier: state.localeIdentifier ?? "en-US"
        )
        #expect(service is SpeechAnalyzerTranscriptionService)
    }
}
