import Testing
import SwiftUI
import UIKit
@testable import SonicMerge

struct SonicMergeSemanticGradientTests {

    /// Helper — assert a UIColor matches the given 0-255 channel values within a small
    /// tolerance. UIColor stores normalized CGFloat; round-trip rounding can produce
    /// off-by-one Int() results, so compare normalized channels with epsilon.
    private func expectChannels(_ color: UIColor, r: Int, g: Int, b: Int,
                                tolerance: CGFloat = 0.01) {
        var rr: CGFloat = 0, gg: CGFloat = 0, bb: CGFloat = 0, aa: CGFloat = 0
        color.getRed(&rr, green: &gg, blue: &bb, alpha: &aa)
        #expect(abs(rr - CGFloat(r) / 255) < tolerance)
        #expect(abs(gg - CGFloat(g) / 255) < tolerance)
        #expect(abs(bb - CGFloat(b) / 255) < tolerance)
    }

    @Test func darkResolverExposesFourFireGradientStops() {
        let s = SonicMergeSemantic.resolved(colorScheme: .dark, preference: .dark)
        #expect(s.accentAIGradientStops.count == 4)
    }

    @Test func lightResolverExposesFourFireGradientStops() {
        let s = SonicMergeSemantic.resolved(colorScheme: .light, preference: .light)
        #expect(s.accentAIGradientStops.count == 4)
    }

    @Test func firstStopIsEmberRed() {
        let s = SonicMergeSemantic.resolved(colorScheme: .light, preference: .light)
        expectChannels(s.accentAIGradientStops[0], r: 255, g: 78, b: 80)
    }

    @Test func lastStopIsDeepViolet() {
        let s = SonicMergeSemantic.resolved(colorScheme: .dark, preference: .dark)
        expectChannels(s.accentAIGradientStops[3], r: 111, g: 45, b: 189)
    }

    @Test func accentActionIsDeepVioletInBothSchemes() {
        let dark = SonicMergeSemantic.resolved(colorScheme: .dark, preference: .dark)
        let light = SonicMergeSemantic.resolved(colorScheme: .light, preference: .light)
        expectChannels(dark.accentAction, r: 111, g: 45, b: 189)
        expectChannels(light.accentAction, r: 111, g: 45, b: 189)
    }

    @Test func accentAIIsMagentaFlat() {
        let s = SonicMergeSemantic.resolved(colorScheme: .light, preference: .light)
        expectChannels(s.accentAI, r: 240, g: 80, b: 110)
    }

    @Test func darkSurfaceBaseIsDeepNavy() {
        let s = SonicMergeSemantic.resolved(colorScheme: .dark, preference: .dark)
        expectChannels(s.surfaceBase, r: 10, g: 10, b: 24)
    }
}
