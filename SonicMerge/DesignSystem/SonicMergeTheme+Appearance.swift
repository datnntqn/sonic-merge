// SonicMergeTheme+Appearance.swift
// SonicMerge
//
// Light / dark semantic colors for conveyor UI (v1.1 Modern Spatial Utility). English comments.

import SwiftUI
import UIKit

/// Stored in UserDefaults via `@AppStorage("sonicMergeThemePreference")`.
enum ThemePreference: String, CaseIterable, Sendable {
    case system
    case light
    case dark
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

    // MARK: - Factory methods

    static func resolved(
        colorScheme: ColorScheme,
        preference: ThemePreference
    ) -> SonicMergeSemantic {
        let useDark: Bool = {
            switch preference {
            case .system: return colorScheme == .dark
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
            surfaceBase: SonicMergeTheme.ColorPalette.canvasBackground,       // #FBFBFC
            surfaceSlot: SonicMergeTheme.ColorPalette.cardSurface,            // #FFFFFF
            surfaceElevated: UIColor.white,
            accentAction: SonicMergeTheme.ColorPalette.primaryAccent,         // Deep Indigo #5856D6
            accentWaveform: SonicMergeTheme.ColorPalette.primaryAccent,       // Deep Indigo #5856D6
            textPrimary: SonicMergeTheme.ColorPalette.primaryText,
            textSecondary: UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.6),
            trustIcon: SonicMergeTheme.ColorPalette.aiAccent,                 // Deep Indigo #5856D6
            accentAI: SonicMergeTheme.ColorPalette.limeGreen,                 // #A7C957
            accentGlow: SonicMergeTheme.ColorPalette.aiAccent,                // Deep Indigo #5856D6
            surfaceCard: SonicMergeTheme.ColorPalette.cardSurface,            // #FFFFFF
            surfaceGlass: UIColor(red: 251 / 255, green: 251 / 255, blue: 252 / 255, alpha: 0.6),
            accentGradientEnd: SonicMergeTheme.ColorPalette.systemPurple      // #AF52DE
        )
    }

    // MARK: - Dark conveyor palette (v1.1 — replaces charcoal v1.0 per D-02)

    private static func darkConveyor() -> SonicMergeSemantic {
        SonicMergeSemantic(
            surfaceBase: SonicMergeTheme.ColorPalette.darkBackground,         // #000000 pure black
            surfaceSlot: SonicMergeTheme.ColorPalette.darkCardSurface,        // #0F0F0F near-black
            surfaceElevated: SonicMergeTheme.ColorPalette.darkCardSurface,    // #0F0F0F
            accentAction: SonicMergeTheme.ColorPalette.aiAccent,              // Deep Indigo #5856D6
            accentWaveform: SonicMergeTheme.ColorPalette.aiAccent,            // Deep Indigo #5856D6
            textPrimary: SonicMergeTheme.ColorPalette.darkTextPrimary,        // near-white 0.96
            textSecondary: SonicMergeTheme.ColorPalette.darkTextSecondary,    // muted 0.55
            trustIcon: SonicMergeTheme.ColorPalette.aiAccent,                 // Deep Indigo #5856D6
            accentAI: SonicMergeTheme.ColorPalette.limeGreen,                 // #A7C957
            accentGlow: SonicMergeTheme.ColorPalette.aiAccent,                // Deep Indigo #5856D6
            surfaceCard: SonicMergeTheme.ColorPalette.darkCardSurface,        // #0F0F0F
            surfaceGlass: UIColor(red: 0, green: 0, blue: 0, alpha: 0.7),     // black@0.7
            accentGradientEnd: SonicMergeTheme.ColorPalette.systemPurple      // #AF52DE
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
