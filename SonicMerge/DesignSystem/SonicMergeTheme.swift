// SonicMergeTheme.swift
// SonicMerge
//
// Design tokens (v1.1 Modern Spatial Utility palette). Comments in English per project convention.

import UIKit

enum SonicMergeTheme {

    /// Prefer `SonicMergeSemantic` from the SwiftUI environment for screens that support light/dark conveyor styling (`SonicMergeTheme+Appearance.swift`).
    enum ColorPalette {
        // MARK: Light mode primitives

        /// Canvas background #FBFBFC (v1.1, replaces #F8F9FA — per D-05)
        static let canvasBackground = UIColor(red: 251 / 255, green: 251 / 255, blue: 252 / 255, alpha: 1)

        /// Primary accent Deep Indigo #5856D6 (v1.1, replaces #007AFF — per D-03)
        static let primaryAccent = UIColor(red: 88 / 255, green: 86 / 255, blue: 214 / 255, alpha: 1)

        /// AI accent Deep Indigo #5856D6 (unchanged)
        static let aiAccent = UIColor(red: 88 / 255, green: 86 / 255, blue: 214 / 255, alpha: 1)

        /// Primary text #1C1C1E (unchanged)
        static let primaryText = UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1)

        /// Light mode card surface #FFFFFF (unchanged)
        static let cardSurface = UIColor.white

        // MARK: New v1.1 tokens

        /// Lime Green #A7C957 — AI features (accentAI token — per D-04)
        static let limeGreen = UIColor(red: 167 / 255, green: 201 / 255, blue: 87 / 255, alpha: 1)

        /// Dark mode background #000000 — pure black (per D-02)
        static let darkBackground = UIColor(red: 0 / 255, green: 0 / 255, blue: 0 / 255, alpha: 1)

        /// Dark mode card surface #0F0F0F — near-black for card lift
        static let darkCardSurface = UIColor(red: 15 / 255, green: 15 / 255, blue: 15 / 255, alpha: 1)

        /// Dark mode primary text — near-white 0.96 luminance
        static let darkTextPrimary = UIColor(white: 0.96, alpha: 1)

        /// Dark mode secondary text — muted 0.55 luminance
        static let darkTextSecondary = UIColor(white: 0.55, alpha: 1)
    }

    enum Radius {
        /// Squircle card radius 24pt (v1.1, replaces 12pt — per DS-02)
        static let card: CGFloat = 24

        /// Pill/chip radius 8pt (unchanged)
        static let chip: CGFloat = 8
    }

    /// Spacing scale (multiples of 4pt, per UI-SPEC spacing table)
    enum Spacing {
        /// 4pt — icon gaps, tight inline padding, waveform bar gaps
        static let xs: CGFloat = 4
        /// 8pt — compact element spacing, VStack inter-item gaps
        static let sm: CGFloat = 8
        /// 16pt — default element padding, HStack spacing in cards
        static let md: CGFloat = 16
        /// 24pt — section padding, card internal padding
        static let lg: CGFloat = 24
        /// 32pt — layout gaps between major sections
        static let xl: CGFloat = 32
        /// 48pt — navigation header clearance, major section breaks
        static let xxl: CGFloat = 48
        /// 64pt — page-level vertical rhythm
        static let xxxl: CGFloat = 64
    }
}
