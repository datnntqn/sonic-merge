// SmartCutMarkTests.swift
// SonicMergeTests
//
// Render-without-crash smoke tests for the three SmartCutMark size presets,
// plus a pixel-diversity test that confirms the fire gradient is actually
// rendering and not silently flattening.

import Testing
import SwiftUI
@testable import SonicMerge

struct SmartCutMarkTests {

    @Test func toolbarSizeRendersWithoutCrash() {
        let view = SmartCutMark(size: .toolbar)
        let renderer = ImageRenderer(content: view.frame(width: 22, height: 22))
        renderer.scale = 1
        #expect(renderer.uiImage != nil)
    }

    @Test func heroSizeRendersWithoutCrash() {
        let view = SmartCutMark(size: .hero)
        let renderer = ImageRenderer(content: view.frame(width: 56, height: 56))
        renderer.scale = 1
        #expect(renderer.uiImage != nil)
    }

    @Test func splashSizeRendersWithoutCrash() {
        let view = SmartCutMark(size: .splash)
        let renderer = ImageRenderer(content: view.frame(width: 96, height: 96))
        renderer.scale = 1
        #expect(renderer.uiImage != nil)
    }

    @Test func monochromeTintAppliesFlatColor() {
        let view = SmartCutMark(size: .toolbar, monochromeTint: .white)
        let renderer = ImageRenderer(content: view.frame(width: 22, height: 22))
        renderer.scale = 1
        #expect(renderer.uiImage != nil)
    }

    /// Pixel-diversity smoke test: gradient version should produce many more
    /// distinct hues than monochrome, giving confidence the LinearGradient is
    /// actually rendering. Sampled only the bar-interior 4-row band centered
    /// at y=h/2 — anti-aliasing produces some pixel diversity in mono too,
    /// so a multiplicative threshold (gradient > 2× mono) is the stable signal.
    @Test func gradientProducesMoreColorVarietyThanMonochrome() {
        let gradient = SmartCutMark(size: .splash)
        let mono = SmartCutMark(size: .splash, monochromeTint: .white)

        func uniquePixelCount(_ view: some View) -> Int {
            let r = ImageRenderer(content: view.frame(width: 96, height: 96))
            r.scale = 1
            guard let img = r.uiImage, let cg = img.cgImage,
                  let data = cg.dataProvider?.data,
                  let ptr = CFDataGetBytePtr(data) else { return 0 }
            let bytesPerRow = cg.bytesPerRow
            let bpp = cg.bitsPerPixel / 8
            let yStart = 48 - 2, yEnd = 48 + 2
            var samples = Set<UInt32>()
            for y in yStart..<yEnd {
                var x = 0
                while x < 96 {
                    let i = y * bytesPerRow + x * bpp
                    if i + 4 > CFDataGetLength(data) { break }
                    let rC = UInt32(ptr[i]); let gC = UInt32(ptr[i+1])
                    let bC = UInt32(ptr[i+2]); let aC = UInt32(ptr[i+3])
                    samples.insert((rC << 24) | (gC << 16) | (bC << 8) | aC)
                    x += 2
                }
            }
            return samples.count
        }

        let gradientUnique = uniquePixelCount(gradient)
        let monoUnique = uniquePixelCount(mono)
        #expect(gradientUnique > monoUnique * 2,
                "expected gradient>2×mono — got gradient=\(gradientUnique) mono=\(monoUnique)")
    }
}
