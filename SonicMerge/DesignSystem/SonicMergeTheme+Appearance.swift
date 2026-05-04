// SonicMergeTheme+Appearance.swift
// SonicMerge
//
// Light / dark semantic colors for conveyor UI (v1.1 Modern Spatial Utility). English comments.

import SwiftUI
import UIKit

/// Stored in UserDefaults via `@AppStorage("sonicMergeThemePreference")`.
enum ThemePreference: String, CaseIterable, Sendable {
    case light
    case dark

    /// The next state in the binary toggle cycle. Pure — easily unit-testable.
    static func next(after current: ThemePreference) -> ThemePreference {
        current == .light ? .dark : .light
    }
}

/// Resolved semantic palette for the current screen (light conveyor vs dark "Merge" style).
///
/// v1.1 adds 4 new token slots: `accentAI`, `accentGlow`, `surfaceCard`, `surfaceGlass`.
/// All new slots are accessible via `@Environment(\.sonicMergeSemantic)`.
struct SonicMergeSemantic {
    // MARK: - Existing slots (v1.0 — preserved for backward compatibility)

    var surfaceBase: UIColor
    var surfaceSlot: UIColor
    var surfaceElevated: UIColor
    var accentAction: UIColor
    var accentWaveform: UIColor
    var textPrimary: UIColor
    var textSecondary: UIColor
    var trustIcon: UIColor

    // MARK: - New slots (v1.1)

    /// Lime Green #A7C957 — AI features (denoising progress, noise slider, AI Orb)
    var accentAI: UIColor

    /// Deep Indigo #5856D6 — glow shadows and ring borders on glassmorphism surfaces
    var accentGlow: UIColor

    /// Squircle card fill — #FFFFFF light / #0F0F0F dark
    var surfaceCard: UIColor

    /// Glassmorphism header tint — #FBFBFC at 0.6 opacity light / #000000 at 0.7 opacity dark
    var surfaceGlass: UIColor

    /// System Purple #AF52DE — waveform mesh gradient end-stop (Phase 7, MIX-03)
    var accentGradientEnd: UIColor

    /// Fire-gradient stops red → orange → magenta → violet (CleanCut rebrand 2026-05-04).
    /// Use as `LinearGradient(colors: stops.map { Color(uiColor: $0) }, startPoint: ..., endPoint: ...)`.
    /// Callsites that need a single flat color should keep using `accentAI` (the magenta stop).
    var accentAIGradientStops: [UIColor]

    // MARK: - Factory methods

    static func resolved(
        colorScheme: ColorScheme,
        preference: ThemePreference
    ) -> SonicMergeSemantic {
        let useDark: Bool = {
            switch preference {
            case .light: return false
            case .dark: return true
            }
        }()
        return useDark ? darkConveyor() : lightClassic()
    }

    /// Environment default and previews when `sonicMergeSemantic` is not injected.
    static var fallbackLight: SonicMergeSemantic { lightClassic() }

    // MARK: - Light classic palette (v1.1)

    private static func lightClassic() -> SonicMergeSemantic {
        SonicMergeSemantic(
            surfaceBase: SonicMergeTheme.ColorPalette.canvasBackground,       // #FBFBFC (unchanged)
            surfaceSlot: SonicMergeTheme.ColorPalette.cardSurface,            // #FFFFFF (unchanged)
            surfaceElevated: UIColor.white,
            accentAction: SonicMergeTheme.ColorPalette.deepViolet,            // #6F2DBD (was #5856D6)
            accentWaveform: SonicMergeTheme.ColorPalette.deepViolet,          // #6F2DBD (was #5856D6)
            textPrimary: SonicMergeTheme.ColorPalette.primaryText,
            textSecondary: UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.6),
            trustIcon: SonicMergeTheme.ColorPalette.deepViolet,               // #6F2DBD (was #5856D6)
            accentAI: SonicMergeTheme.ColorPalette.magentaAccent,             // #F0506E (was lime #A7C957)
            accentGlow: SonicMergeTheme.ColorPalette.magentaAccent,           // #F0506E (was indigo)
            surfaceCard: SonicMergeTheme.ColorPalette.cardSurface,            // #FFFFFF (unchanged)
            surfaceGlass: UIColor(red: 251 / 255, green: 251 / 255, blue: 252 / 255, alpha: 0.6),
            accentGradientEnd: SonicMergeTheme.ColorPalette.deepViolet,       // #6F2DBD (was #AF52DE)
            accentAIGradientStops: [
                SonicMergeTheme.ColorPalette.emberRed,                        // #FF4E50
                SonicMergeTheme.ColorPalette.emberOrange,                     // #F9A66C
                SonicMergeTheme.ColorPalette.magentaAccent,                   // #F0506E
                SonicMergeTheme.ColorPalette.deepViolet                       // #6F2DBD
            ]
        )
    }

    // MARK: - Dark conveyor palette (v1.1 — replaces charcoal v1.0 per D-02)

    private static func darkConveyor() -> SonicMergeSemantic {
        SonicMergeSemantic(
            surfaceBase: SonicMergeTheme.ColorPalette.deepNavy,               // #0A0A18 (was #000000)
            surfaceSlot: SonicMergeTheme.ColorPalette.deepNavyCard,           // #15172B (was #0F0F0F)
            surfaceElevated: SonicMergeTheme.ColorPalette.deepNavyCard,       // #15172B (was #0F0F0F)
            accentAction: SonicMergeTheme.ColorPalette.deepViolet,            // #6F2DBD (was #5856D6)
            accentWaveform: SonicMergeTheme.ColorPalette.deepViolet,          // #6F2DBD (was #5856D6)
            textPrimary: SonicMergeTheme.ColorPalette.darkTextPrimary,
            textSecondary: SonicMergeTheme.ColorPalette.darkTextSecondary,
            trustIcon: SonicMergeTheme.ColorPalette.deepViolet,               // #6F2DBD (was #5856D6)
            accentAI: SonicMergeTheme.ColorPalette.magentaAccent,             // #F0506E (was lime)
            accentGlow: SonicMergeTheme.ColorPalette.magentaAccent,           // #F0506E (was indigo)
            surfaceCard: SonicMergeTheme.ColorPalette.deepNavyCard,           // #15172B (was #0F0F0F)
            surfaceGlass: UIColor(red: 10 / 255, green: 10 / 255, blue: 24 / 255, alpha: 0.7), // deep navy @ 0.7
            accentGradientEnd: SonicMergeTheme.ColorPalette.deepViolet,       // #6F2DBD (was #AF52DE)
            accentAIGradientStops: [
                SonicMergeTheme.ColorPalette.emberRed,
                SonicMergeTheme.ColorPalette.emberOrange,
                SonicMergeTheme.ColorPalette.magentaAccent,
                SonicMergeTheme.ColorPalette.deepViolet
            ]
        )
    }
}

// MARK: - SwiftUI environment

private enum SonicMergeSemanticKey: EnvironmentKey {
    static let defaultValue = SonicMergeSemantic.fallbackLight
}

extension EnvironmentValues {
    var sonicMergeSemantic: SonicMergeSemantic {
        get { self[SonicMergeSemanticKey.self] }
        set { self[SonicMergeSemanticKey.self] = newValue }
    }
}
