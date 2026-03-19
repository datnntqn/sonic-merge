//
//  LUFSNormalizationService.swift
//  SonicMerge
//
//  Actor that measures integrated loudness via a manual BS.1770-3 K-weighting
//  biquad cascade (48 kHz, ITU-R BS.1770-3 Table 1 coefficients) and computes
//  the linear gain scalar needed to reach -16 LUFS.
//
//  Design mirrors AudioNormalizationService: plain actor, only primitive values
//  (URL, Double) cross actor boundaries — no AVFoundation objects escape the actor.
//
//  Used by AudioMergerService when lufsNormalize == true.
//

import AVFoundation
import Accelerate

actor LUFSNormalizationService {

    // MARK: - Constants

    /// Target integrated loudness (podcast standard, EBU R128 recommendation).
    static let targetLUFS: Double = -16.0

    // MARK: - Public API

    /// Returns the linear gain scalar to apply to reach -16 LUFS.
    /// If measurement fails or audio is too short, returns 1.0 (no gain change).
    /// Result is clamped to (0.001, 100.0) to prevent extreme amplification of near-silent files.
    func gainScalar(for url: URL) async -> Double {
        guard let measuredLUFS = await measureIntegratedLUFS(url: url),
              measuredLUFS.isFinite else {
            return 1.0
        }
        let gainDB = Self.targetLUFS - measuredLUFS
        let scalar = pow(10.0, gainDB / 20.0)
        return min(max(scalar, 0.001), 100.0)
    }

    // MARK: - Internal Measurement

    /// Measures integrated loudness using a manual BS.1770-3 K-weighting biquad cascade.
    ///
    /// Algorithm:
    /// 1. Decode audio to float32 PCM at 48 kHz stereo via AVAssetReader.
    /// 2. Apply K-weighting: 2-stage IIR biquad cascade (direct form II transposed).
    /// 3. Compute mean-square of weighted samples.
    /// 4. Convert to LUFS: 10*log10(mean_square) - 0.691 (stereo channel sum correction).
    ///
    /// Note: This is ungated loudness (no 400ms block gating per BS.1770-4).
    /// For files >= 3 seconds, ungated integrated loudness is a close approximation.
    private func measureIntegratedLUFS(url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first else {
            return nil
        }

        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            return nil
        }

        // Decode to float32 interleaved stereo at 48 kHz
        // K-weighting biquad coefficients are pre-computed for 48 kHz — must decode at this rate.
        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false
        ])
        guard reader.canAdd(readerOutput) else { return nil }
        reader.add(readerOutput)
        guard reader.startReading() else { return nil }

        // K-weighting filter coefficients at 48 kHz (ITU-R BS.1770-3, Table 1)
        // Stage 1 — Pre-filter (high shelf)
        let b1: (Double, Double, Double) = (1.53512485958697, -2.69169618940638, 1.19839281085285)
        let a1: (Double, Double, Double) = (1.0, -1.69065929318241, 0.73248077421585)
        // Stage 2 — RLB weighting (high-pass)
        let b2: (Double, Double, Double) = (1.0, -2.0, 1.0)
        let a2: (Double, Double, Double) = (1.0, -1.99004745483398, 0.99007225036621)

        // Biquad state registers (direct form II transposed), per channel
        var wL1 = (0.0, 0.0), wR1 = (0.0, 0.0)  // Stage 1 state: w[n-1], w[n-2]
        var wL2 = (0.0, 0.0), wR2 = (0.0, 0.0)  // Stage 2 state

        var sumOfSquares: Double = 0.0
        var totalSamples: Int = 0

        while let sampleBuffer = readerOutput.copyNextSampleBuffer() {
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }
            let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
            guard numSamples > 0 else { continue }

            var dataLen = 0
            var dataPtr: UnsafeMutablePointer<Int8>?
            guard CMBlockBufferGetDataPointer(
                blockBuffer, atOffset: 0,
                lengthAtOffsetOut: nil, totalLengthOut: &dataLen,
                dataPointerOut: &dataPtr
            ) == noErr, let dataPtr else { continue }

            let floats = UnsafeMutableRawPointer(dataPtr).assumingMemoryBound(to: Float.self)
            let floatCount = dataLen / MemoryLayout<Float>.size  // interleaved: L,R,L,R,...

            var i = 0
            while i + 1 < floatCount {
                var sL = Double(floats[i])
                var sR = Double(floats[i + 1])

                // Stage 1 biquad — left channel (direct form II transposed)
                let yL1 = b1.0 * sL + wL1.0
                wL1.0 = b1.1 * sL - a1.1 * yL1 + wL1.1
                wL1.1 = b1.2 * sL - a1.2 * yL1
                sL = yL1

                // Stage 1 biquad — right channel
                let yR1 = b1.0 * sR + wR1.0
                wR1.0 = b1.1 * sR - a1.1 * yR1 + wR1.1
                wR1.1 = b1.2 * sR - a1.2 * yR1
                sR = yR1

                // Stage 2 biquad — left channel
                let yL2 = b2.0 * sL + wL2.0
                wL2.0 = b2.1 * sL - a2.1 * yL2 + wL2.1
                wL2.1 = b2.2 * sL - a2.2 * yL2
                sL = yL2

                // Stage 2 biquad — right channel
                let yR2 = b2.0 * sR + wR2.0
                wR2.0 = b2.1 * sR - a2.1 * yR2 + wR2.1
                wR2.1 = b2.2 * sR - a2.2 * yR2
                sR = yR2

                // Stereo mean-square (equal weight per channel per BS.1770-3)
                sumOfSquares += (sL * sL + sR * sR) / 2.0
                totalSamples += 1
                i += 2
            }
        }

        guard totalSamples > 0, sumOfSquares > 0 else { return nil }

        // Integrated loudness formula: LUFS = 10*log10(mean_square) - 0.691
        // The -0.691 is the BS.1770-3 stereo channel-weighting correction factor.
        let lufs = 10.0 * log10(sumOfSquares / Double(totalSamples)) - 0.691
        return lufs
    }
}
