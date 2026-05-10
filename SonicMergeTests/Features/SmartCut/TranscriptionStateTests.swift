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

    @Test func testLegacyJSONWithoutLocaleIdentifierDecodesNil() throws {
        let json = """
        {"sourceHash":"h","sourceDuration":60,"chunkDurationSeconds":30,
         "completedChunkCount":0,"recognizedSegments":[],"isComplete":false}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(TranscriptionState.self, from: json)
        #expect(decoded.localeIdentifier == nil)
    }

    @Test func testPreMigrationJSONDecodesWithDefaultEngine() throws {
        // Hand-rolled pre-migration JSON: NO engine, NO completedRecognizedDuration,
        // NO liveTranscriptText. Mirrors the shape of cached state files written by
        // pre-SpeechAnalyzer builds.
        let json = """
        {
          "sourceHash": "abc123",
          "localeIdentifier": "en-US",
          "sourceDuration": 1800,
          "chunkDurationSeconds": 30,
          "completedChunkCount": 4,
          "recognizedSegments": [],
          "isComplete": false
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(TranscriptionState.self, from: json)
        #expect(decoded.engine == .sfSpeechRecognizer)
        #expect(decoded.completedRecognizedDuration == 0)
        #expect(decoded.liveTranscriptText == "")
    }

    @Test func testProgressFractionAnalyzerEngineUsesCompletedRecognizedDuration() {
        let state = TranscriptionState(
            sourceHash: "abc",
            sourceDuration: 100,
            chunkDurationSeconds: 0,             // analyzer engine ignores chunks
            completedChunkCount: 0,
            recognizedSegments: [],
            isComplete: false,
            engine: .speechAnalyzer,
            completedRecognizedDuration: 30
        )
        #expect(abs(state.progressFraction - 0.3) < 0.0001)
    }

    @Test func testProgressFractionAnalyzerEngineCapsAtOne() {
        let state = TranscriptionState(
            sourceHash: "abc",
            sourceDuration: 100,
            chunkDurationSeconds: 0,
            completedChunkCount: 0,
            recognizedSegments: [],
            isComplete: true,
            engine: .speechAnalyzer,
            completedRecognizedDuration: 150     // floating-point overshoot
        )
        #expect(state.progressFraction == 1.0)
    }
}
