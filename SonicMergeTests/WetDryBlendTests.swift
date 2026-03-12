//
//  WetDryBlendTests.swift
//  SonicMergeTests
//
//  Green tests for DNS-02: wet/dry blend behaviors.
//  Pure math tests — no model or audio file needed.
//  Tests verify the blend(original:denoised:intensity:) function in NoiseReductionService.swift.
//

import Testing
import Foundation
@testable import SonicMerge

struct WetDryBlendTests {

    // MARK: - DNS-02: Zero intensity returns original

    @Test func testZeroIntensityReturnsOriginal() {
        let original: [Float] = [1, 2, 3]
        let denoised: [Float] = [4, 5, 6]
        let result = blend(original: original, denoised: denoised, intensity: 0.0)
        #expect(result.count == 3)
        #expect(abs(result[0] - 1.0) < 1e-5)
        #expect(abs(result[1] - 2.0) < 1e-5)
        #expect(abs(result[2] - 3.0) < 1e-5)
    }

    // MARK: - DNS-02: Full intensity returns denoised

    @Test func testFullIntensityReturnsDenoised() {
        let original: [Float] = [1, 2, 3]
        let denoised: [Float] = [4, 5, 6]
        let result = blend(original: original, denoised: denoised, intensity: 1.0)
        #expect(result.count == 3)
        #expect(abs(result[0] - 4.0) < 1e-5)
        #expect(abs(result[1] - 5.0) < 1e-5)
        #expect(abs(result[2] - 6.0) < 1e-5)
    }

    // MARK: - DNS-02: Half intensity is linear midpoint

    @Test func testHalfIntensityIsLinearMid() {
        // blend(original:[0,0,0], denoised:[2,2,2], intensity:0.5) → [1,1,1]
        let original: [Float] = [0, 0, 0]
        let denoised: [Float] = [2, 2, 2]
        let result = blend(original: original, denoised: denoised, intensity: 0.5)
        #expect(result.count == 3)
        #expect(abs(result[0] - 1.0) < 1e-5)
        #expect(abs(result[1] - 1.0) < 1e-5)
        #expect(abs(result[2] - 1.0) < 1e-5)
    }
}
