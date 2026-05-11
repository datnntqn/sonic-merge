import Testing
import Foundation
@testable import SonicMerge

/// SpeechAnalyzerTranscriptionService is `@available(iOS 26, *)`. Swift
/// Testing's `@Test` macros can't be applied to availability-gated symbols,
/// so each test runtime-checks `#available` and skips on older OSes.
@Suite struct SpeechAnalyzerTranscriptionServiceTests {

    private final class BundleMarker {}

    /// Fixture is a deferred one-time deliverable; tests silently skip when
    /// missing (matches SmartCutServiceIntegrationTests' pattern).
    private func fixtureURL() -> URL? {
        Bundle(for: BundleMarker.self).url(forResource: "smart_cut_60s", withExtension: "wav")
    }

    @Test func streamingYieldsAtLeastOneUpdateBeforeCompletion() async throws {
        guard #available(iOS 26, *) else { return }
        guard let url = fixtureURL() else { return }
        let service = SpeechAnalyzerTranscriptionService(locale: Locale(identifier: "en-US"))
        var nonFinalCount = 0
        for try await state in service.transcribe(input: url) {
            if !state.isComplete { nonFinalCount += 1 }
        }
        #expect(nonFinalCount > 0, "Expected at least one mid-stream update before completion")
    }

    @Test func finalStateHasNonEmptyRecognizedSegments() async throws {
        guard #available(iOS 26, *) else { return }
        guard let url = fixtureURL() else { return }
        let service = SpeechAnalyzerTranscriptionService(locale: Locale(identifier: "en-US"))
        var final: TranscriptionState?
        for try await state in service.transcribe(input: url) {
            if state.isComplete { final = state }
        }
        let f = try #require(final)
        #expect(!f.recognizedSegments.isEmpty)
    }

    @Test func finalStateHasAnalyzerEngineAndPositiveCompletedDuration() async throws {
        guard #available(iOS 26, *) else { return }
        guard let url = fixtureURL() else { return }
        let service = SpeechAnalyzerTranscriptionService(locale: Locale(identifier: "en-US"))
        var final: TranscriptionState?
        for try await state in service.transcribe(input: url) {
            if state.isComplete { final = state }
        }
        let f = try #require(final)
        #expect(f.engine == .speechAnalyzer)
        #expect(f.completedRecognizedDuration > 0)
    }

    @Test func snapshotPersistedMidStream() async throws {
        guard #available(iOS 26, *) else { return }
        guard let url = fixtureURL() else { return }
        // Use a custom store that records every save.
        actor SaveRecorder {
            var saves: [TranscriptionState] = []
            func add(_ state: TranscriptionState) { saves.append(state) }
        }
        let recorder = SaveRecorder()
        let store = TranscriptionStateStore(
            load: { _ in nil },
            save: { state in await recorder.add(state) }
        )
        let service = SpeechAnalyzerTranscriptionService(
            locale: Locale(identifier: "en-US"),
            stateStore: store,
            snapshotInterval: 5  // shorter than default to guarantee a mid-stream snapshot
        )
        for try await _ in service.transcribe(input: url) {}
        let count = await recorder.saves.count
        #expect(count >= 2, "Expected at least one mid-stream snapshot plus the final save")
    }
}
