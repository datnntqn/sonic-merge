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
        let service = SmartCutService(library: library, pauseThreshold: 1.5)

        var finalEditList: EditList?
        for try await update in service.analyze(input: url) {
            if case .completed(let list) = update {
                finalEditList = list
            }
        }
        let editList = try #require(finalEditList)

        // Fixture says "um hello uh world like this" then 2s silence then "yeah basically that's it".
        let categories = Set(editList.categories)
        #expect(categories.contains("um"))
        #expect(categories.contains("uh"))

        // Default-on fillers should be enabled
        let umEdits = editList.fillers.filter { $0.matchedText == "um" }
        #expect(umEdits.allSatisfy { $0.isEnabled })

        // Default-off fillers (if detected) should be disabled
        let likeEdits = editList.fillers.filter { $0.matchedText == "like" }
        if !likeEdits.isEmpty {
            #expect(likeEdits.allSatisfy { !$0.isEnabled })
        }

        #expect(!editList.pauses.isEmpty)
    }

    private final class BundleMarker {}
}
