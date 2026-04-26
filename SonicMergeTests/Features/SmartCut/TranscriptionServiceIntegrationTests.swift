import Testing
import Foundation
import Speech
@testable import SonicMerge

struct TranscriptionServiceIntegrationTests {

    private func fixtureURL() -> URL? {
        Bundle(for: BundleMarker.self).url(forResource: "smart_cut_60s", withExtension: "wav")
    }

    /// SFSpeechRecognizer requires the on-device model to be downloaded on the test runner.
    /// On CI this may not be available; tests gate on `isAvailable`.
    /// The fixture WAV is a deferred one-time deliverable — test skips gracefully when missing.
    @Test func testTranscribesFixtureToExpectedSegments() async throws {
        guard let url = fixtureURL() else {
            Issue.record("Fixture smart_cut_60s.wav missing — skipping. Run GenerateFixtures.")
            return
        }
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard recognizer?.isAvailable == true, recognizer?.supportsOnDeviceRecognition == true else {
            Issue.record("On-device recognizer unavailable on this test runner — skipping.")
            return
        }

        let service = TranscriptionService(chunkDurationSeconds: 30)
        var lastState: TranscriptionState?
        for try await state in service.transcribe(input: url) {
            lastState = state
        }
        let finalState = try #require(lastState)
        #expect(finalState.isComplete)
        let allText = finalState.recognizedSegments.map(\.text).joined(separator: " ").lowercased()
        // We don't assert exact text — recognizer drift is real. Substrings only.
        #expect(allText.contains("um"))
        #expect(allText.contains("hello"))
    }

    /// Marker class lives in this file to give Bundle(for:) a target.
    private final class BundleMarker {}
}
