// SonicMergeTheme.swift
// SonicMerge
//
// Design tokens (UX-01). Comments in English per project convention.

import UIKit

enum SonicMergeTheme {

    enum ColorPalette {
        /// UX-01 canvas `#F8F9FA` (existing MixingStation background)
        static let canvasBackground = UIColor(red: 0.973, green: 0.976, blue: 0.980, alpha: 1)
        /// Primary accent `#007AFF`
        static let primaryAccent = UIColor(red: 0, green: 0.478, blue: 1, alpha: 1)
        /// UX-01 AI accent `#5856D6`
        static let aiAccent = UIColor(red: 88 / 255, green: 86 / 255, blue: 214 / 255, alpha: 1)
        static let primaryText = UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1)
        static let cardSurface = UIColor.white
    }

    enum Radius {
        static let card: CGFloat = 12
        static let chip: CGFloat = 8
    }
}
