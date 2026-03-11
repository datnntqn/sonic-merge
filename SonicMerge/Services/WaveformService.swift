//
//  WaveformService.swift
//  SonicMerge
//
//  Created by DATNNT on 11/3/26.
//

import AVFoundation
import Accelerate
import Foundation

/// Generates a compact waveform representation for an audio file.
///
/// Produces exactly `barCount` peak amplitude values normalized to 0...1,
/// written as raw Float32 binary to a sidecar file. The sidecar is stored
/// alongside the audio file in the App Group clips directory.
///
/// Called after normalization completes, before AudioClip is persisted.
/// Failure is non-fatal — a flat waveform (all zeros) is written on error
/// so clip cards always have valid data to render.
actor WaveformService {

    /// Number of peak bars. Fixed at 50 for consistent rendering at 60pt card width.
    static let barCount: Int = 50

    /// Generate waveform peaks from `audioURL` and write to `destinationURL`.
    ///
    /// - Parameters:
    ///   - audioURL: URL of the normalized .m4a audio file to analyze.
    ///   - destinationURL: URL where the .waveform sidecar will be written.
    /// - Throws: Only file-write errors. Audio read failures produce a flat waveform.
    func generate(audioURL: URL, destinationURL: URL) async throws {
        let peaks = await extractPeaks(from: audioURL)
        let data = Data(bytes: peaks, count: peaks.count * MemoryLayout<Float>.size)
        try data.write(to: destinationURL, options: .atomic)
    }

    // MARK: - Private

    private func extractPeaks(from url: URL) async -> [Float] {
        let zeros = Array(repeating: Float(0), count: Self.barCount)

        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first else {
            return zeros
        }

        let reader: AVAssetReader
        do { reader = try AVAssetReader(asset: asset) } catch { return zeros }

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ])
        reader.add(output)
        guard reader.startReading() else { return zeros }

        var allSamples: [Float] = []
        allSamples.reserveCapacity(48_000 * 2)  // 1s stereo at 48kHz

        while let buf = output.copyNextSampleBuffer(),
              let blockBuf = CMSampleBufferGetDataBuffer(buf) {
            var length = 0
            var ptr: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(
                blockBuf, atOffset: 0,
                lengthAtOffsetOut: nil,
                totalLengthOut: &length,
                dataPointerOut: &ptr
            )
            if let ptr {
                let count = length / MemoryLayout<Float>.size
                ptr.withMemoryRebound(to: Float.self, capacity: count) { floatPtr in
                    allSamples.append(contentsOf: UnsafeBufferPointer(start: floatPtr, count: count))
                }
            }
        }

        guard !allSamples.isEmpty else { return zeros }

        // Downsample to barCount peaks using vDSP_maxmgv (magnitude max per chunk)
        let chunkSize = max(allSamples.count / Self.barCount, 1)
        var peaks: [Float] = (0..<Self.barCount).map { i in
            let start = i * chunkSize
            let end = min(start + chunkSize, allSamples.count)
            guard start < end else { return 0 }
            var peak: Float = 0
            vDSP_maxmgv(
                Array(allSamples[start..<end]), 1,
                &peak,
                vDSP_Length(end - start)
            )
            return peak
        }

        // Normalize peaks to 0...1
        var maxPeak: Float = 0
        vDSP_maxv(peaks, 1, &maxPeak, vDSP_Length(peaks.count))
        if maxPeak > 0 {
            vDSP_vsdiv(peaks, 1, &maxPeak, &peaks, 1, vDSP_Length(peaks.count))
        }

        return peaks
    }
}
