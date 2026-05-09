import Testing
import Foundation
@testable import SonicMerge

/// Verifies the explicit `pauseThreshold:` parameter on `SmartCutService.analyze`
/// actually flows through to `PauseDetector` (rather than being ignored in favor
/// of an init-time captured default).
struct SmartCutServicePauseThresholdTests {

    /// Stub conforming to the `TranscriptionServicing` protocol. Yields one
    /// pre-built `TranscriptionState` whose recognized segments have a single
    /// 2.0-second gap (1.0s end → 3.0s start). Lets us assert which threshold
    /// is in effect inside `analyze` based on whether the gap becomes a pause.
    private struct StubTranscriptionService: TranscriptionServicing {
        let segments: [TranscriptionState.RecognizedSegment]
        let duration: TimeInterval

        func transcribe(input: URL) -> AsyncThrowingStream<TranscriptionState, Error> {
            let segments = self.segments
            let duration = self.duration
            return AsyncThrowingStream { continuation in
                let state = TranscriptionState(
                    sourceHash: "test",
                    sourceDuration: duration,
                    chunkDurationSeconds: duration,
                    completedChunkCount: 1,
                    recognizedSegments: segments,
                    isComplete: true
                )
                continuation.yield(state)
                continuation.finish()
            }
        }
    }

    private static func twoWordSegmentsWith2sGap() -> [TranscriptionState.RecognizedSegment] {
        [
            .init(text: "alpha", startTime: 0.0, endTime: 1.0, confidence: 0.9),
            .init(text: "beta",  startTime: 3.0, endTime: 4.0, confidence: 0.9)
        ]
    }

    @Test func analyzeRespectsExplicitPauseThresholdBelowGap() async throws {
        let stub = StubTranscriptionService(
            segments: Self.twoWordSegmentsWith2sGap(),
            duration: 4.0
        )
        let library = FillerLibrary(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
        let service = SmartCutService(library: library, transcriptionServiceFactory: { _ in stub })

        var resolvedEditList: EditList?
        for try await update in await service.analyze(input: URL(fileURLWithPath: "/dev/null"),
                                                      pauseThreshold: 1.5,
                                                      locale: Locale(identifier: "en-US")) {
            if case .completed(let list, _, _) = update {
                resolvedEditList = list
            }
        }

        let editList = try #require(resolvedEditList)
        // Threshold 1.5s, gap 2.0s → exceeds → 1 pause cut.
        #expect(editList.pauses.filter(\.isEnabled).count == 1)
    }

    @Test func analyzeRespectsExplicitPauseThresholdAboveGap() async throws {
        let stub = StubTranscriptionService(
            segments: Self.twoWordSegmentsWith2sGap(),
            duration: 4.0
        )
        let library = FillerLibrary(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
        let service = SmartCutService(library: library, transcriptionServiceFactory: { _ in stub })

        var resolvedEditList: EditList?
        for try await update in await service.analyze(input: URL(fileURLWithPath: "/dev/null"),
                                                      pauseThreshold: 2.5,
                                                      locale: Locale(identifier: "en-US")) {
            if case .completed(let list, _, _) = update {
                resolvedEditList = list
            }
        }

        let editList = try #require(resolvedEditList)
        // Threshold 2.5s, gap 2.0s → below threshold → 0 pause cuts.
        #expect(editList.pauses.filter(\.isEnabled).count == 0)
    }
}
