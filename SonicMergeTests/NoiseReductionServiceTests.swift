//
//  NoiseReductionServiceTests.swift
//  SonicMergeTests
//
//  Failing stubs for DNS-01: NoiseReductionService behaviors.
//  RED state: NoiseReductionService does not exist until Wave 1 (Plan 03-02).
//
//  REQUIRES: DeepFilterNet3.mlpackage in app bundle.
//  See docs/DENOISING_SETUP.md before running Wave 1.
//
//  These tests will turn green in Plan 03-02 when NoiseReductionService is implemented.
//

import Testing
import Foundation
@testable import SonicMerge

struct NoiseReductionServiceTests {

    // MARK: - DNS-01: Denoised file created

    @Test func testDenoisedFileCreated() async throws {
        // Stub: NoiseReductionService does not exist yet.
        // Wave 1 must implement NoiseReductionService.denoise(inputURL:outputURL:progress:)
        // and verify a non-empty file exists at the output URL after denoising.
        Issue.record("not implemented — DNS-01: Wave 1 implements NoiseReductionService")
    }

    // MARK: - DNS-01: Output format is valid

    @Test func testOutputFormatIsValid() async throws {
        // Stub: Output must be 48 kHz stereo PCM/AAC.
        // Wave 1 must verify AVAudioFormat of denoised output matches 48000 Hz, 2 channels.
        Issue.record("not implemented — DNS-01: output must be 48 kHz stereo")
    }

    // MARK: - DNS-01: Progress increases monotonically

    @Test func testProgressMonotonicallyIncreases() async throws {
        // Stub: AsyncStream<Float> must yield values from 0.0 to 1.0 in ascending order.
        // Wave 1 must verify collected progress values are monotonically non-decreasing.
        Issue.record("not implemented — DNS-01: AsyncStream<Float> must yield increasing values 0.0\u{2192}1.0")
    }
}
