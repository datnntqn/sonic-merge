import Testing
import Foundation
@testable import SonicMerge

struct PauseDetectorTests {

    private func seg(_ start: TimeInterval, _ end: TimeInterval) -> TranscriptionState.RecognizedSegment {
        .init(text: "x", startTime: start, endTime: end, confidence: 0.9)
    }

    @Test func testNoPausesBelowThreshold() {
        let segments = [seg(0, 1), seg(1.4, 2.4)]  // 0.4s gap
        let pauses = PauseDetector.detect(in: segments,
                                          totalDuration: 3,
                                          threshold: 1.5)
        #expect(pauses.isEmpty)
    }

    @Test func testDetectsGapAboveThreshold() {
        let segments = [seg(0, 1), seg(3, 4)]  // 2.0s gap
        let pauses = PauseDetector.detect(in: segments,
                                          totalDuration: 5,
                                          threshold: 1.5)
        #expect(pauses.count == 1)
        #expect(pauses[0].timeRange == 1...3)
    }

    @Test func testThresholdBoundaryExclusive() {
        let segments = [seg(0, 1), seg(2.5, 3.5)]  // exactly 1.5s gap
        let pauses = PauseDetector.detect(in: segments,
                                          totalDuration: 5,
                                          threshold: 1.5)
        // Boundary is exclusive: gap == threshold does NOT trigger.
        #expect(pauses.isEmpty)
    }

    @Test func testJustOverThresholdTriggers() {
        let segments = [seg(0, 1), seg(2.51, 3.51)]
        let pauses = PauseDetector.detect(in: segments,
                                          totalDuration: 5,
                                          threshold: 1.5)
        #expect(pauses.count == 1)
    }

    @Test func testLeadingSilenceDetected() {
        let segments = [seg(2, 3)]
        let pauses = PauseDetector.detect(in: segments,
                                          totalDuration: 4,
                                          threshold: 1.5)
        #expect(pauses.count == 1)
        #expect(pauses[0].timeRange == 0...2)
    }

    @Test func testTrailingSilenceDetected() {
        let segments = [seg(0, 1)]
        let pauses = PauseDetector.detect(in: segments,
                                          totalDuration: 4,
                                          threshold: 1.5)
        #expect(pauses.count == 1)
        #expect(pauses[0].timeRange == 1...4)
    }

    @Test func testMultipleGaps() {
        let segments = [seg(0, 1), seg(3, 4), seg(7, 8)]
        let pauses = PauseDetector.detect(in: segments,
                                          totalDuration: 9,
                                          threshold: 1.5)
        #expect(pauses.count == 2)
        #expect(pauses.contains(where: { $0.timeRange == 1...3 }))
        #expect(pauses.contains(where: { $0.timeRange == 4...7 }))
    }

    @Test func testDefaultEnabledIsTrue() {
        let segments = [seg(0, 1), seg(3, 4)]
        let pauses = PauseDetector.detect(in: segments,
                                          totalDuration: 5,
                                          threshold: 1.5)
        #expect(pauses[0].isEnabled == true)
    }
}
