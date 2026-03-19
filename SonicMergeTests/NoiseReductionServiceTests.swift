//
//  NoiseReductionServiceTests.swift
//  SonicMergeTests
//
//  Green tests for DNS-01: NoiseReductionService behaviors.
//
//  REQUIRES: DeepFilterNet3.mlpackage in app bundle and test target.
//  See docs/DENOISING_SETUP.md for setup instructions.
//  If the model is absent, denoise() returns an empty stream (model load error).
//

import Testing
import Foundation
import AVFoundation
@testable import SonicMerge

struct NoiseReductionServiceTests {

    private final class BundleLocator {}

    // MARK: - Fixture

    /// Returns a URL to a 48 kHz stereo audio fixture for testing.
    /// Falls back to a synthetic 1-second WAV if no bundle fixture is found.
    private func fixture48kHzStereoWAV() throws -> URL {
        if let url = Bundle(for: BundleLocator.self)
            .url(forResource: "stereo_48000", withExtension: "m4a") {
            return url
        }
        return try makeSyntheticWAV()
    }

    /// Generate a 1-second synthetic 48 kHz stereo Float32 WAV for testing.
    private func makeSyntheticWAV() throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_input_48k_stereo_\(UUID().uuidString).wav")
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 2,
            interleaved: false
        )!
        let frameCount: AVAudioFrameCount = 48_000  // 1 second
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        if let channelData = buffer.floatChannelData {
            for i in 0..<Int(frameCount) {
                let t = Float(i) / 48_000.0
                channelData[0][i] = sin(2.0 * Float.pi * 440.0 * t) * 0.1
                channelData[1][i] = 0.0
            }
        }
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: format.settings)
        try outputFile.write(from: buffer)
        return outputURL
    }

    // MARK: - DNS-01: Denoised file created

    @Test func testDenoisedFileCreated() async throws {
        let inputURL = try fixture48kHzStereoWAV()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("denoised_\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let service = NoiseReductionService()
        let stream = await service.denoise(inputURL: inputURL, outputURL: outputURL)
        for try await _ in stream {}

        let exists = FileManager.default.fileExists(atPath: outputURL.path)
        #expect(exists, "Denoised output file must exist after denoise() completes")
    }

    // MARK: - DNS-01: Output format is valid

    @Test func testOutputFormatIsValid() async throws {
        let inputURL = try fixture48kHzStereoWAV()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("denoised_format_\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let service = NoiseReductionService()
        let stream = await service.denoise(inputURL: inputURL, outputURL: outputURL)
        for try await _ in stream {}

        let outputFile = try AVAudioFile(forReading: outputURL)
        let fmt = outputFile.processingFormat
        #expect(fmt.sampleRate == 48_000, "Output sample rate must be 48000 Hz")
        #expect(fmt.channelCount == 2, "Output must be stereo (2 channels)")
        #expect(outputFile.length > 0, "Output file must contain audio frames")
    }

    // MARK: - DNS-01: Progress increases monotonically

    @Test func testProgressMonotonicallyIncreases() async throws {
        let inputURL = try fixture48kHzStereoWAV()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("denoised_progress_\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let service = NoiseReductionService()
        let stream = await service.denoise(inputURL: inputURL, outputURL: outputURL)

        var values: [Float] = []
        for try await value in stream {
            values.append(value)
        }

        #expect(!values.isEmpty, "Progress stream must yield at least one value")
        #expect(values.first! >= 0.0, "First progress value must be >= 0.0")
        #expect(values.last! == 1.0, "Final progress value must be 1.0")

        for i in 1..<values.count {
            #expect(values[i] >= values[i - 1],
                "Progress must be monotonically non-decreasing: \(values[i - 1]) → \(values[i])")
        }
    }
}
