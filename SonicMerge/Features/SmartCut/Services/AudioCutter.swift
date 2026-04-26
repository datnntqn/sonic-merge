import Foundation
import AVFoundation

/// Renders an output WAV by removing each enabled time-range from `input`.
/// Applies a 25 ms equal-power crossfade at every cut boundary to remove clicks.
actor AudioCutter {

    /// Crossfade duration in seconds. Equal-power: cos/sin envelope so summed gain == 1.0.
    private static let crossfadeSeconds: TimeInterval = 0.025

    func apply(input: URL, editList: EditList) async throws -> URL {
        let file = try AVAudioFile(forReading: input)
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let totalFrames = file.length

        // Compute the keep-ranges (the inverse of cut-ranges).
        let cuts = editList.enabledCutRanges
        let keepRanges = invertRanges(cuts: cuts, totalDuration: Double(totalFrames) / sampleRate)

        // Read whole file into one buffer (acceptable v1: typical podcast 30 min @ 44.1kHz mono = ~316 MB
        // — large but viable on iPhone 12+; revisit if we add stereo or 96kHz). Plan-level note,
        // not a TODO: streaming render is a future optimization.
        let inBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames))!
        try file.read(into: inBuffer)

        // Allocate output buffer sized to the sum of keep-range frames.
        let outFrameCount = keepRanges.reduce(0) { acc, r in
            acc + AVAudioFrameCount((r.upperBound - r.lowerBound) * sampleRate)
        }
        let outBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outFrameCount)!
        outBuffer.frameLength = outFrameCount

        let channelCount = Int(format.channelCount)
        let crossfadeFrames = Int(Self.crossfadeSeconds * sampleRate)

        for ch in 0..<channelCount {
            let inSamples = inBuffer.floatChannelData![ch]
            let outSamples = outBuffer.floatChannelData![ch]
            var writeIdx = 0
            for (rangeIndex, range) in keepRanges.enumerated() {
                let startFrame = Int(range.lowerBound * sampleRate)
                let endFrame = Int(range.upperBound * sampleRate)
                let frames = endFrame - startFrame

                for f in 0..<frames {
                    var sample = inSamples[startFrame + f]
                    // Fade-out at the trailing edge of every keep-range except the last
                    if rangeIndex < keepRanges.count - 1, f >= frames - crossfadeFrames {
                        let envIdx = f - (frames - crossfadeFrames)
                        let theta = (Float(envIdx) / Float(crossfadeFrames)) * .pi / 2
                        sample *= cos(theta)
                    }
                    // Fade-in at the leading edge of every keep-range except the first
                    if rangeIndex > 0, f < crossfadeFrames {
                        let theta = (Float(f) / Float(crossfadeFrames)) * .pi / 2
                        sample *= sin(theta)
                    }
                    outSamples[writeIdx + f] = sample
                }
                writeIdx += frames
            }
        }

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("smartcut-output-\(UUID().uuidString).wav")
        let outFile = try AVAudioFile(forWriting: outURL, settings: format.settings)
        try outFile.write(from: outBuffer)
        return outURL
    }

    /// Returns the complement of `cuts` over `[0, totalDuration]`.
    /// E.g. cuts = [(2,3)], total = 5 → keep = [(0,2),(3,5)].
    private func invertRanges(cuts: [ClosedRange<TimeInterval>],
                              totalDuration: TimeInterval) -> [ClosedRange<TimeInterval>] {
        guard !cuts.isEmpty else { return [0...totalDuration] }
        var result: [ClosedRange<TimeInterval>] = []
        var cursor: TimeInterval = 0
        for cut in cuts {
            if cut.lowerBound > cursor {
                result.append(cursor...cut.lowerBound)
            }
            cursor = max(cursor, cut.upperBound)
        }
        if cursor < totalDuration {
            result.append(cursor...totalDuration)
        }
        return result
    }
}
