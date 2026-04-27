import Testing
import Foundation
import AVFoundation
@testable import SonicMerge

struct DisfluencyDetectorTests {

    private func seg(_ text: String, _ start: TimeInterval, _ end: TimeInterval) -> TranscriptionState.RecognizedSegment {
        .init(text: text, startTime: start, endTime: end, confidence: 0.9)
    }

    // Build a pure-Float buffer where every sample has the given amplitude.
    // Used to fabricate synthetic envelopes for the voicedRunsAboveThreshold tests.
    private func buffer(amplitude: Float, frames: Int) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: 48000,
                                   channels: 1,
                                   interleaved: false)!
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buf.frameLength = AVAudioFrameCount(frames)
        let ch = buf.floatChannelData![0]
        for i in 0..<frames { ch[i] = amplitude }
        return buf
    }

    @Test("voicedRunsAboveThreshold finds a single run above the silence threshold")
    func voicedRun_singleRunDetected() {
        // 10 windows of silence (0.0001 ≈ -80 dBFS), 5 windows of voice (0.5 ≈ -6 dBFS), 10 silent
        var envelope: [Float] = Array(repeating: 0.0001, count: 10)
        envelope.append(contentsOf: Array(repeating: 0.5, count: 5))
        envelope.append(contentsOf: Array(repeating: 0.0001, count: 10))
        let runs = DisfluencyDetector.voicedRunsAboveThreshold(envelope: envelope)
        #expect(runs.count == 1)
        // Window count 10 → start = 10 * 0.025 = 0.25s; end = 15 * 0.025 = 0.375s
        #expect(abs(runs[0].startTime - 0.25) < 1e-9)
        #expect(abs(runs[0].endTime - 0.375) < 1e-9)
    }

    @Test("voicedRunsAboveThreshold treats run extending to end-of-buffer correctly")
    func voicedRun_runAtBufferEnd() {
        let envelope: [Float] = Array(repeating: 0.0001, count: 5) + Array(repeating: 0.5, count: 5)
        let runs = DisfluencyDetector.voicedRunsAboveThreshold(envelope: envelope)
        #expect(runs.count == 1)
        #expect(abs(runs[0].startTime - 0.125) < 1e-9)
        #expect(abs(runs[0].endTime - 0.250) < 1e-9)
    }

    @Test("filterCandidates rejects too-short voiced runs")
    func filter_rejectsTooShort() {
        // 50ms run — below the 100ms minimum
        let runs = [DisfluencyDetector.VoicedRun(startTime: 1.0, endTime: 1.05)]
        let kept = DisfluencyDetector.filterCandidates(runs: runs, recognizedSegments: [], totalDuration: 5.0)
        #expect(kept.isEmpty)
    }

    @Test("filterCandidates rejects too-long voiced runs")
    func filter_rejectsTooLong() {
        // 800ms run — above the 700ms maximum
        let runs = [DisfluencyDetector.VoicedRun(startTime: 1.0, endTime: 1.8)]
        let kept = DisfluencyDetector.filterCandidates(runs: runs, recognizedSegments: [], totalDuration: 5.0)
        #expect(kept.isEmpty)
    }

    @Test("filterCandidates keeps a 300ms isolated run")
    func filter_keepsCleanCandidate() {
        let runs = [DisfluencyDetector.VoicedRun(startTime: 1.0, endTime: 1.3)]
        let kept = DisfluencyDetector.filterCandidates(runs: runs, recognizedSegments: [], totalDuration: 5.0)
        #expect(kept.count == 1)
    }

    @Test("filterCandidates rejects a run overlapping a recognized segment")
    func filter_rejectsOverlap() {
        let runs = [DisfluencyDetector.VoicedRun(startTime: 1.0, endTime: 1.3)]
        let segments = [seg("hello", 0.8, 1.1)]  // overlaps run start
        let kept = DisfluencyDetector.filterCandidates(runs: runs, recognizedSegments: segments, totalDuration: 5.0)
        #expect(kept.isEmpty)
    }

    @Test("filterCandidates accepts a run safely between two recognized segments")
    func filter_keepsRunInGap() {
        let runs = [DisfluencyDetector.VoicedRun(startTime: 1.5, endTime: 1.7)]
        let segments = [seg("hello", 0.8, 1.2), seg("world", 2.0, 2.5)]
        let kept = DisfluencyDetector.filterCandidates(runs: runs, recognizedSegments: segments, totalDuration: 5.0)
        #expect(kept.count == 1)
    }

    @Test("rmsEnvelope produces correct values for a constant-amplitude buffer")
    func rms_constantSignal() {
        let buf = buffer(amplitude: 0.5, frames: 4800)  // 100ms @ 48kHz
        let env = DisfluencyDetector.rmsEnvelope(buffer: buf, windowFrames: 1200)  // 25ms windows
        #expect(env.count == 4)
        for v in env { #expect(abs(v - 0.5) < 1e-5) }
    }
}
