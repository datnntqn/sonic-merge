import Foundation
import AVFoundation

/// Heuristic detector for verbal hesitations (um/uh/ah/er/oh) that
/// SFSpeechRecognizer's on-device engine drops as noise during language-model
/// decoding. Operates directly on the audio waveform — independent of the
/// transcript — so it surfaces fillers the recognizer never sees.
///
/// Algorithm: compute an RMS energy envelope, find voiced runs (energy above
/// silence threshold), keep only short runs (100–700ms) that fall in the
/// gaps between recognized speech segments. Those gap-bound short voiced
/// events are the typical disfluency signature.
///
/// Output FillerEdits use the generic matchedText `(filler)` because we
/// cannot reliably classify um vs uh vs oh from waveform alone — labelling
/// it generically matches what the user actually sees in the result list
/// without overpromising.
enum DisfluencyDetector {

    /// Generic label for detected disfluencies (matches how the rest of the
    /// pipeline groups by `matchedText`; users see one card "(filler)" with
    /// all events as occurrences).
    static let label: String = "(filler)"

    /// Minimum disfluency duration. Anything shorter is likely a click or breath.
    static let minDurationSeconds: TimeInterval = 0.10
    /// Maximum disfluency duration. "uhhh" rarely exceeds 700ms in conversational speech.
    static let maxDurationSeconds: TimeInterval = 0.70
    /// RMS threshold (dBFS) below which a window counts as silence.
    static let silenceThresholdDB: Float = -40.0
    /// RMS analysis window — 25ms balances precision vs cost.
    static let windowSeconds: TimeInterval = 0.025
    /// A candidate must be at least this far from any recognized segment to count
    /// as "in a gap." Tight buffer avoids tagging the trailing breath of a real word.
    static let recognizedSegmentBufferSeconds: TimeInterval = 0.05

    /// Produce FillerEdits for likely disfluencies in `audioURL`.
    /// `recognizedSegments` come from TranscriptionService and are excluded
    /// from candidates so we don't double-detect words already in the transcript.
    static func detect(audioURL: URL,
                       recognizedSegments: [TranscriptionState.RecognizedSegment],
                       totalDuration: TimeInterval,
                       enabledByDefault: Bool = true) throws -> [FillerEdit] {
        let envelope = try rmsEnvelope(of: audioURL)
        let voicedRuns = voicedRunsAboveThreshold(envelope: envelope)
        let candidates = filterCandidates(
            runs: voicedRuns,
            recognizedSegments: recognizedSegments,
            totalDuration: totalDuration
        )
        return candidates.map { run in
            FillerEdit(
                matchedText: label,
                timeRange: run.startTime...run.endTime,
                confidence: 0.7,
                contextExcerpt: "...detected filler sound...",
                isEnabled: enabledByDefault
            )
        }
    }

    // MARK: - Internals (exposed for unit tests)

    struct VoicedRun: Equatable {
        let startTime: TimeInterval
        let endTime: TimeInterval
        var duration: TimeInterval { endTime - startTime }
    }

    /// Walk the audio's first channel, compute RMS over fixed windows.
    static func rmsEnvelope(of audioURL: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: audioURL)
        let format = file.processingFormat
        let totalFrames = AVAudioFrameCount(file.length)
        guard totalFrames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else {
            return []
        }
        try file.read(into: buffer)
        let windowFrames = max(1, Int(windowSeconds * format.sampleRate))
        return rmsEnvelope(buffer: buffer, windowFrames: windowFrames)
    }

    /// Pure-function RMS envelope — split out for unit tests with synthetic buffers.
    static func rmsEnvelope(buffer: AVAudioPCMBuffer, windowFrames: Int) -> [Float] {
        guard windowFrames > 0,
              let channel = buffer.floatChannelData?[0] else { return [] }
        let frameLength = Int(buffer.frameLength)
        var envelope: [Float] = []
        envelope.reserveCapacity(frameLength / windowFrames)
        var i = 0
        while i + windowFrames <= frameLength {
            var sum: Float = 0
            for f in 0..<windowFrames {
                let s = channel[i + f]
                sum += s * s
            }
            envelope.append(sqrt(sum / Float(windowFrames)))
            i += windowFrames
        }
        return envelope
    }

    /// Convert an RMS envelope into voiced runs (consecutive windows above threshold).
    static func voicedRunsAboveThreshold(envelope: [Float]) -> [VoicedRun] {
        let threshold = pow(10.0, silenceThresholdDB / 20.0)  // dBFS → linear
        var runs: [VoicedRun] = []
        var inRun = false
        var runStartIndex = 0
        for (i, rms) in envelope.enumerated() {
            if rms > threshold {
                if !inRun { runStartIndex = i; inRun = true }
            } else if inRun {
                runs.append(VoicedRun(
                    startTime: Double(runStartIndex) * windowSeconds,
                    endTime: Double(i) * windowSeconds
                ))
                inRun = false
            }
        }
        if inRun {
            runs.append(VoicedRun(
                startTime: Double(runStartIndex) * windowSeconds,
                endTime: Double(envelope.count) * windowSeconds
            ))
        }
        return runs
    }

    /// Keep only short voiced runs that don't overlap any recognized segment
    /// (with a small safety buffer on each side).
    static func filterCandidates(runs: [VoicedRun],
                                 recognizedSegments: [TranscriptionState.RecognizedSegment],
                                 totalDuration: TimeInterval) -> [VoicedRun] {
        runs.filter { run in
            guard run.duration >= minDurationSeconds,
                  run.duration <= maxDurationSeconds else { return false }
            // Reject if any recognized segment overlaps the run (with buffer).
            let runStart = run.startTime - recognizedSegmentBufferSeconds
            let runEnd = run.endTime + recognizedSegmentBufferSeconds
            return !recognizedSegments.contains { seg in
                runStart <= seg.endTime && runEnd >= seg.startTime
            }
        }
    }
}
