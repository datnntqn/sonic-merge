// SonicMergeTheme+Appearance.swift
// SonicMerge
//
// Light / dark semantic colors for conveyor UI. English comments.

import SwiftUI
import UIKit

/// Stored in UserDefaults via `@AppStorage("sonicMergeThemePreference")`.
enum ThemePreference: String, CaseIterable, Sendable {
    case system
    case light
    case dark
}

/// Resolved palette for the current screen (light conveyor vs dark “Merge” style).
struct SonicMergeSemantic {
    var surfaceBase: UIColor
    var surfaceSlot: UIColor
    var surfaceElevated: UIColor
    var accentAction: UIColor
    var accentWaveform: UIColor
    var textPrimary: UIColor
    var textSecondary: UIColor
    var trustIcon: UIColor

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

    private static func lightClassic() -> SonicMergeSemantic {
        SonicMergeSemantic(
            surfaceBase: SonicMergeTheme.ColorPalette.canvasBackground,
            surfaceSlot: SonicMergeTheme.ColorPalette.cardSurface,
            surfaceElevated: UIColor.white,
            accentAction: SonicMergeTheme.ColorPalette.primaryAccent,
            accentWaveform: SonicMergeTheme.ColorPalette.primaryAccent,
            textPrimary: SonicMergeTheme.ColorPalette.primaryText,
            textSecondary: UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.6),
            trustIcon: SonicMergeTheme.ColorPalette.aiAccent
        )
    }

    /// Dark conveyor reference: charcoal shell + neon-mint accent (SonicMerge-specific, not a copy of any store listing).
    private static func darkConveyor() -> SonicMergeSemantic {
        SonicMergeSemantic(
            surfaceBase: UIColor(red: 0.07, green: 0.08, blue: 0.09, alpha: 1),
            surfaceSlot: UIColor(red: 0.12, green: 0.13, blue: 0.15, alpha: 1),
            surfaceElevated: UIColor(red: 0.18, green: 0.19, blue: 0.22, alpha: 1),
            accentAction: UIColor(red: 0.18, green: 0.92, blue: 0.62, alpha: 1),
            accentWaveform: UIColor(red: 0.18, green: 0.92, blue: 0.62, alpha: 1),
            textPrimary: UIColor(white: 0.96, alpha: 1),
            textSecondary: UIColor(white: 0.55, alpha: 1),
            trustIcon: SonicMergeTheme.ColorPalette.aiAccent
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
