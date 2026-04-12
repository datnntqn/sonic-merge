// SonicMergeThemeTests.swift
// SonicMergeTests

import Testing
import UIKit
import SwiftUI
@testable import SonicMerge

struct SonicMergeThemeTests {

    // MARK: - ColorPalette v1.1

    @Test func canvasBackgroundRGBA_matchesUX01Background() {
        // Updated to #FBFBFC per D-05
        let c = SonicMergeTheme.ColorPalette.canvasBackground
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(c.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(Double(r) - (251.0 / 255.0)) < 0.01)
        #expect(abs(Double(g) - (251.0 / 255.0)) < 0.01)
        #expect(abs(Double(b) - (252.0 / 255.0)) < 0.01)
    }

    @Test func aiAccentRGBA_matchesUX01AIAccent() {
        let c = SonicMergeTheme.ColorPalette.aiAccent
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(c.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(Double(r) - (88.0 / 255.0)) < 0.02)
        #expect(abs(Double(g) - (86.0 / 255.0)) < 0.02)
        #expect(abs(Double(b) - (214.0 / 255.0)) < 0.02)
    }

    @Test func primaryAccent_isDeepIndigo() {
        // Per D-03: primaryAccent replaced from #007AFF to Deep Indigo #5856D6
        let c = SonicMergeTheme.ColorPalette.primaryAccent
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(c.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(Double(r) - (88.0 / 255.0)) < 0.01)
        #expect(abs(Double(g) - (86.0 / 255.0)) < 0.01)
        #expect(abs(Double(b) - (214.0 / 255.0)) < 0.01)
    }

    @Test func limeGreen_matchesAIAccentColor() {
        // Per D-04: Lime Green #A7C957
        let c = SonicMergeTheme.ColorPalette.limeGreen
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(c.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(Double(r) - (167.0 / 255.0)) < 0.01)
        #expect(abs(Double(g) - (201.0 / 255.0)) < 0.01)
        #expect(abs(Double(b) - (87.0 / 255.0)) < 0.01)
    }

    @Test func darkBackground_isPureBlack() {
        // Per D-02: dark mode background is #000000
        let c = SonicMergeTheme.ColorPalette.darkBackground
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(c.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(Double(r) == 0.0)
        #expect(Double(g) == 0.0)
        #expect(Double(b) == 0.0)
    }

    @Test func darkCardSurface_isNearBlack() {
        // Per UI-SPEC: dark card surface is #0F0F0F
        let c = SonicMergeTheme.ColorPalette.darkCardSurface
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(c.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(Double(r) - (15.0 / 255.0)) < 0.01)
        #expect(abs(Double(g) - (15.0 / 255.0)) < 0.01)
        #expect(abs(Double(b) - (15.0 / 255.0)) < 0.01)
    }

    @Test func systemPurple_isAF52DE() {
        // Per Phase 7 UI-SPEC: waveform mesh gradient end-stop #AF52DE
        let c = SonicMergeTheme.ColorPalette.systemPurple
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(c.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(Double(r) - (175.0 / 255.0)) < 0.01)
        #expect(abs(Double(g) - (82.0 / 255.0)) < 0.01)
        #expect(abs(Double(b) - (222.0 / 255.0)) < 0.01)
    }

    // MARK: - Radius

    @Test func radius_card_is24() {
        #expect(SonicMergeTheme.Radius.card == 24)
    }

    @Test func radius_chip_is8() {
        #expect(SonicMergeTheme.Radius.chip == 8)
    }

    // MARK: - Spacing

    @Test func spacing_xs_is4() {
        #expect(SonicMergeTheme.Spacing.xs == 4)
    }

    @Test func spacing_sm_is8() {
        #expect(SonicMergeTheme.Spacing.sm == 8)
    }

    @Test func spacing_md_is16() {
        #expect(SonicMergeTheme.Spacing.md == 16)
    }

    @Test func spacing_lg_is24() {
        #expect(SonicMergeTheme.Spacing.lg == 24)
    }

    @Test func spacing_xl_is32() {
        #expect(SonicMergeTheme.Spacing.xl == 32)
    }

    @Test func spacing_xxl_is48() {
        #expect(SonicMergeTheme.Spacing.xxl == 48)
    }

    @Test func spacing_xxxl_is64() {
        #expect(SonicMergeTheme.Spacing.xxxl == 64)
    }

    // MARK: - Semantic token slots

    @Test func lightSemantic_hasNewTokenSlots() {
        // Resolves light palette and checks new slots exist and are non-nil
        let semantic = SonicMergeSemantic.resolved(colorScheme: .light, preference: .system)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(semantic.accentAI.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(semantic.accentGlow.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(semantic.surfaceCard.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(semantic.surfaceGlass.getRed(&r, green: &g, blue: &b, alpha: &a))
    }

    @Test func lightSemantic_accentAI_isLimeGreen() {
        let semantic = SonicMergeSemantic.resolved(colorScheme: .light, preference: .system)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(semantic.accentAI.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(Double(r) - (167.0 / 255.0)) < 0.01)
        #expect(abs(Double(g) - (201.0 / 255.0)) < 0.01)
        #expect(abs(Double(b) - (87.0 / 255.0)) < 0.01)
    }

    @Test func lightSemantic_accentGradientEnd_isSystemPurple() {
        let semantic = SonicMergeSemantic.resolved(colorScheme: .light, preference: .system)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(semantic.accentGradientEnd.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(Double(r) - (175.0 / 255.0)) < 0.01)
        #expect(abs(Double(g) - (82.0 / 255.0)) < 0.01)
        #expect(abs(Double(b) - (222.0 / 255.0)) < 0.01)
    }

    @Test func darkSemantic_accentGradientEnd_isSystemPurple() {
        let semantic = SonicMergeSemantic.resolved(colorScheme: .dark, preference: .system)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(semantic.accentGradientEnd.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(Double(r) - (175.0 / 255.0)) < 0.01)
        #expect(abs(Double(g) - (82.0 / 255.0)) < 0.01)
        #expect(abs(Double(b) - (222.0 / 255.0)) < 0.01)
    }

    @Test func darkSemantic_hasPureBlackBase() {
        let semantic = SonicMergeSemantic.resolved(colorScheme: .dark, preference: .system)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(semantic.surfaceBase.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(Double(r) == 0.0)
        #expect(Double(g) == 0.0)
        #expect(Double(b) == 0.0)
    }

    @Test func darkSemantic_hasDeepIndigoAccent() {
        let semantic = SonicMergeSemantic.resolved(colorScheme: .dark, preference: .system)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(semantic.accentAction.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(Double(r) - (88.0 / 255.0)) < 0.01)
        #expect(abs(Double(g) - (86.0 / 255.0)) < 0.01)
        #expect(abs(Double(b) - (214.0 / 255.0)) < 0.01)
    }

    @Test func darkSemantic_surfaceCardIsNearBlack() {
        let semantic = SonicMergeSemantic.resolved(colorScheme: .dark, preference: .system)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(semantic.surfaceCard.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(Double(r) - (15.0 / 255.0)) < 0.01)
        #expect(abs(Double(g) - (15.0 / 255.0)) < 0.01)
        #expect(abs(Double(b) - (15.0 / 255.0)) < 0.01)
    }

    @Test func darkSemantic_accentAI_isLimeGreen() {
        let semantic = SonicMergeSemantic.resolved(colorScheme: .dark, preference: .system)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(semantic.accentAI.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(Double(r) - (167.0 / 255.0)) < 0.01)
        #expect(abs(Double(g) - (201.0 / 255.0)) < 0.01)
        #expect(abs(Double(b) - (87.0 / 255.0)) < 0.01)
    }

    @Test func fallbackLight_matchesLightClassicValues() {
        let fallback = SonicMergeSemantic.fallbackLight
        let light = SonicMergeSemantic.resolved(colorScheme: .light, preference: .system)
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        var lr: CGFloat = 0, lg: CGFloat = 0, lb: CGFloat = 0, la: CGFloat = 0
        #expect(fallback.surfaceBase.getRed(&fr, green: &fg, blue: &fb, alpha: &fa))
        #expect(light.surfaceBase.getRed(&lr, green: &lg, blue: &lb, alpha: &la))
        #expect(abs(Double(fr - lr)) < 0.01)
        #expect(abs(Double(fg - lg)) < 0.01)
        #expect(abs(Double(fb - lb)) < 0.01)
    }
}
