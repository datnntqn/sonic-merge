import Testing
import Foundation
@testable import SonicMerge

struct TranscriptionStateTests {

    @Test func testRoundTrip() throws {
        let state = TranscriptionState(
            sourceHash: "abc123",
            sourceDuration: 1800,
            chunkDurationSeconds: 30,
            completedChunkCount: 4,
            recognizedSegments: [
                .init(text: "hello world", startTime: 0.5, endTime: 1.2, confidence: 0.92),
                .init(text: "um", startTime: 2.0, endTime: 2.3, confidence: 0.88),
            ],
            isComplete: false
        )

        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(TranscriptionState.self, from: encoded)
        #expect(decoded == state)
    }

    @Test func testProgressFractionAtMidPoint() {
        let state = TranscriptionState(
            sourceHash: "abc",
            sourceDuration: 100,
            chunkDurationSeconds: 10,
            completedChunkCount: 5,
            recognizedSegments: [],
            isComplete: false
        )
        #expect(abs(state.progressFraction - 0.5) < 0.0001)
    }

    @Test func testProgressFractionAtCompletion() {
        let state = TranscriptionState(
            sourceHash: "abc",
            sourceDuration: 100,
            chunkDurationSeconds: 10,
            completedChunkCount: 10,
            recognizedSegments: [],
            isComplete: true
        )
        #expect(state.progressFraction == 1.0)
    }

    @Test func testNextChunkStartTime() {
        let state = TranscriptionState(
            sourceHash: "abc",
            sourceDuration: 1800,
            chunkDurationSeconds: 30,
            completedChunkCount: 4,
            recognizedSegments: [],
            isComplete: false
        )
        #expect(state.nextChunkStartTime == 120)
    }
}
