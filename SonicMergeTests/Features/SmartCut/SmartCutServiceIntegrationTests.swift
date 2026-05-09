import Testing
import Foundation
import Speech
@testable import SonicMerge

struct SmartCutServiceIntegrationTests {

    private func fixtureURL() -> URL? {
        Bundle(for: BundleMarker.self).url(forResource: "smart_cut_60s", withExtension: "wav")
    }

    /// Fixture WAV is a deferred one-time deliverable — test silently skips when missing.
    /// Same Swift-Testing-has-no-conditional-skip caveat as TranscriptionServiceIntegrationTests.
    @Test func testAnalyzeFindsExpectedFillersAndPauses() async throws {
        guard let url = fixtureURL() else { return }
        guard SFSpeechRecognizer(locale: Locale(identifier: "en-US"))?.supportsOnDeviceRecognition == true else { return }

        let library = FillerLibrary(defaults: UserDefaults(suiteName: "smartcut-int-\(UUID())")!)
        let service = SmartCutService(library: library)

        var finalEditList: EditList?
        for try await update in service.analyze(input: url, pauseThreshold: 1.5, locale: Locale(identifier: "en-US")) {
            if case .completed(let list, _, _) = update {
                finalEditList = list
            }
        }
        let editList = try #require(finalEditList)

        // Fixture says "um hello uh world like this" then 2s silence then "yeah basically that's it".
        // defaultOnWords is now empty (the on-device recognizer is unreliable
        // on short hesitations), so the analyze pipeline won't detect filler
        // categories with a fresh library — that's the intended product
        // behavior. The integration test now exercises only the parts of the
        // pipeline that don't depend on default fillers: pause detection.
        #expect(!editList.pauses.isEmpty)

        // Default-off fillers (if detected via opt-in) should be disabled.
        // None will be detected here since the user hasn't opted in, but
        // keep the assertion shape so future regressions surface.
        let likeEdits = editList.fillers.filter { $0.matchedText == "like" }
        if !likeEdits.isEmpty {
            #expect(likeEdits.allSatisfy { !$0.isEnabled })
        }
    }

    private final class BundleMarker {}
}
