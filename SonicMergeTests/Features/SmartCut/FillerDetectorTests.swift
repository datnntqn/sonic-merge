import Testing
import Foundation
@testable import SonicMerge

struct FillerDetectorTests {

    private func seg(_ text: String, _ start: TimeInterval, _ end: TimeInterval) -> TranscriptionState.RecognizedSegment {
        .init(text: text, startTime: start, endTime: end, confidence: 0.9)
    }

    @Test func testMatchesSimpleFiller() {
        let segments = [seg("um", 1.0, 1.3)]
        let edits = FillerDetector.detect(in: segments,
                                          words: ["um"],
                                          enabledByDefault: { $0 == "um" })
        #expect(edits.count == 1)
        #expect(edits[0].matchedText == "um")
        // 100ms pad each side, no neighbors → ~0.9...~1.4 (use tolerance —
        // 1.3 + 0.1 isn't exactly 1.4 in IEEE754).
        #expect(abs(edits[0].timeRange.lowerBound - 0.9) < 0.0001)
        #expect(abs(edits[0].timeRange.upperBound - 1.4) < 0.0001)
        #expect(edits[0].isEnabled == true)
    }

    @Test func testCaseInsensitive() {
        let segments = [seg("UM", 1.0, 1.3), seg("Uh", 2.0, 2.4)]
        let edits = FillerDetector.detect(in: segments,
                                          words: ["um", "uh"],
                                          enabledByDefault: { _ in true })
        #expect(edits.count == 2)
    }

    @Test func testPunctuationIgnored() {
        let segments = [seg("um,", 1.0, 1.3), seg("um.", 2.0, 2.3)]
        let edits = FillerDetector.detect(in: segments,
                                          words: ["um"],
                                          enabledByDefault: { _ in true })
        #expect(edits.count == 2)
    }

    @Test func testNonFillerWordsAreIgnored() {
        let segments = [seg("hello", 0, 0.5), seg("world", 1, 1.5)]
        let edits = FillerDetector.detect(in: segments,
                                          words: ["um"],
                                          enabledByDefault: { _ in true })
        #expect(edits.isEmpty)
    }

    @Test func testMultiWordPhraseMatchesAcrossSegments() {
        let segments = [
            seg("you", 1.0, 1.2),
            seg("know", 1.3, 1.5),
            seg("the", 1.6, 1.8),
        ]
        let edits = FillerDetector.detect(in: segments,
                                          words: ["you know"],
                                          enabledByDefault: { _ in true })
        #expect(edits.count == 1)
        #expect(edits[0].matchedText == "you know")
        // Time range spans both words with 100ms pad. Lower clamps to 0
        // (no prior segment, 1.0 - 0.1 = 0.9). Upper clamps to next
        // segment's start (1.6) since 1.5 + 0.1 = 1.6 reaches "the".
        #expect(edits[0].timeRange == 0.9...1.6)
    }

    @Test func testPaddingClampsToNeighbors() {
        // "uh" is wedged between two non-filler words. Padding must clamp
        // to neighbor boundaries so it doesn't encroach on real speech.
        let segments = [
            seg("hello", 0.5, 0.95),
            seg("uh", 1.0, 1.3),
            seg("world", 1.32, 1.8),
        ]
        let edits = FillerDetector.detect(in: segments,
                                          words: ["uh"],
                                          enabledByDefault: { _ in true })
        #expect(edits.count == 1)
        // Lower pad clamps to "hello".endTime (0.95) — closer than 1.0 - 0.1.
        // Upper pad clamps to "world".startTime (1.32) — closer than 1.3 + 0.1.
        #expect(edits[0].timeRange == 0.95...1.32)
    }

    @Test func testDefaultOffFlagPropagates() {
        let segments = [seg("like", 1.0, 1.3)]
        let edits = FillerDetector.detect(in: segments,
                                          words: ["like"],
                                          enabledByDefault: { _ in false })
        #expect(edits[0].isEnabled == false)
    }

    @Test func testNonMonotonicNeighborsDoNotCrash() {
        // Long audio crash repro: SFSpeechRecognizer's chunked path can emit
        // segments where segments[i].endTime > segments[i+1].startTime —
        // the last word of chunk N extends past the boundary, while the
        // next chunk's first word starts at exactly the boundary. The
        // padded range for the i+1 segment must not invert (lowerBound >
        // upperBound), which would trip ClosedRange's precondition.
        let segments = [
            seg("hello", 29.5, 30.3),   // last word of chunk 0 — extends past 30s
            seg("um", 30.0, 30.1),      // first word of chunk 1 — overlaps "hello"
            seg("world", 30.5, 31.0),
        ]
        let edits = FillerDetector.detect(in: segments,
                                          words: ["um"],
                                          enabledByDefault: { _ in true })
        #expect(edits.count == 1)
        #expect(edits[0].timeRange.lowerBound <= edits[0].timeRange.upperBound)
    }

    @Test func testContextExcerptIncludesNeighbors() {
        let segments = [
            seg("so", 0.5, 0.8),
            seg("um", 1.0, 1.3),
            seg("the", 1.5, 1.7),
            seg("thing", 1.8, 2.1),
        ]
        let edits = FillerDetector.detect(in: segments,
                                          words: ["um"],
                                          enabledByDefault: { _ in true })
        #expect(edits[0].contextExcerpt.contains("so"))
        #expect(edits[0].contextExcerpt.contains("um"))
        #expect(edits[0].contextExcerpt.contains("the"))
    }
}
