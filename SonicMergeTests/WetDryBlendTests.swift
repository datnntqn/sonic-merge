//
//  WetDryBlendTests.swift
//  SonicMergeTests
//
//  Failing stubs for DNS-02: wet/dry blend behaviors.
//  RED state: NoiseReductionService blend function does not exist until Wave 2 (Plan 03-03).
//
//  Note: WetDryBlendTests is pure math — no model or audio file needed.
//  Tests will turn green in Wave 2 when NoiseReductionService implements the blend function.
//

import Testing
import Foundation
@testable import SonicMerge

struct WetDryBlendTests {

    // MARK: - DNS-02: Zero intensity returns original

    @Test func testZeroIntensityReturnsOriginal() {
        // Stub: blend(intensity:0.0) must return the original (dry) signal unchanged.
        // Wave 2 must verify output equals the original buffer when intensity == 0.0.
        Issue.record("not implemented — DNS-02: blend(intensity:0.0) must equal original")
    }

    // MARK: - DNS-02: Full intensity returns denoised

    @Test func testFullIntensityReturnsDenoised() {
        // Stub: blend(intensity:1.0) must return the fully denoised (wet) signal.
        // Wave 2 must verify output equals the denoised buffer when intensity == 1.0.
        Issue.record("not implemented — DNS-02: blend(intensity:1.0) must equal denoised")
    }

    // MARK: - DNS-02: Half intensity is linear midpoint

    @Test func testHalfIntensityIsLinearMid() {
        // Stub: blend(intensity:0.5) must equal (original + denoised) / 2 for each sample.
        // Wave 2 must verify linear interpolation: output[i] = original[i] * 0.5 + denoised[i] * 0.5.
        Issue.record("not implemented — DNS-02: blend(intensity:0.5) must equal (original + denoised) / 2")
    }
}
