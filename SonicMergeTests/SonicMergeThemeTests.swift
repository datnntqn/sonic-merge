// SonicMergeThemeTests.swift
// SonicMergeTests

import Testing
import UIKit
@testable import SonicMerge

struct SonicMergeThemeTests {

    @Test func canvasBackgroundRGBA_matchesUX01Background() {
        let c = SonicMergeTheme.ColorPalette.canvasBackground
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(c.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(Double(r) - 0.973) < 0.02)
        #expect(abs(Double(g) - 0.976) < 0.02)
        #expect(abs(Double(b) - 0.980) < 0.02)
    }

    @Test func aiAccentRGBA_matchesUX01AIAccent() {
        let c = SonicMergeTheme.ColorPalette.aiAccent
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(c.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(Double(r) - (88.0 / 255.0)) < 0.02)
        #expect(abs(Double(g) - (86.0 / 255.0)) < 0.02)
        #expect(abs(Double(b) - (214.0 / 255.0)) < 0.02)
    }
}
