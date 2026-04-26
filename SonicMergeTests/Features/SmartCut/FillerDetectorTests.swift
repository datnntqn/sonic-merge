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
        #expect(edits[0].timeRange == 1.0...1.3)
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
        // Time range spans both words: 1.0...1.5
        #expect(edits[0].timeRange == 1.0...1.5)
    }

    @Test func testDefaultOffFlagPropagates() {
        let segments = [seg("like", 1.0, 1.3)]
        let edits = FillerDetector.detect(in: segments,
                                          words: ["like"],
                                          enabledByDefault: { _ in false })
        #expect(edits[0].isEnabled == false)
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
