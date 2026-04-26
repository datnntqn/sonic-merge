// PremiumBackground.swift
// SonicMerge
//
// Phase 11 (Premium Studio Polish): subtle mesh gradient that lays a 3%
// Deep Indigo wash over the four screen corners on top of the existing
// semantic.surfaceBase fill. iOS 18+ uses native MeshGradient; iOS 17
// falls back to two crossed LinearGradient overlays.
//
// Decorative — accessibilityHidden. No animation, no motion impact.

import SwiftUI
import UIKit

struct PremiumBackground: View {
    @Environment(\.sonicMergeSemantic) private var semantic

    private static let cornerOpacity: Double = 0.03

    var body: some View {
        ZStack {
            Color(uiColor: semantic.surfaceBase)

            if #available(iOS 18.0, *) {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                        [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                    ],
                    colors: [
                        accentTint,    Color.clear, accentTint,
                        Color.clear,   Color.clear, Color.clear,
                        accentTint,    Color.clear, accentTint
                    ]
                )
            } else {
                // iOS 17 fallback — two crossed LinearGradients approximate
                // the corner-anchored wash of the iOS 18 mesh.
                LinearGradient(
                    colors: [accentTint, Color.clear, accentTint],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [accentTint, Color.clear, accentTint],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var accentTint: Color {
        Color(uiColor: semantic.accentAction).opacity(Self.cornerOpacity)
    }
}

#Preview("PremiumBackground") {
    PremiumBackground()
        .frame(width: 390, height: 844)
}
