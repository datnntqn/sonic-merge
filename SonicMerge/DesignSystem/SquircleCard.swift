// SquircleCard.swift
// SonicMerge
//
// DS-02: Reusable squircle card with optional glass material. English comments.

import SwiftUI
import UIKit

struct SquircleCard<Content: View>: View {
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let glassEnabled: Bool
    let glowEnabled: Bool
    @ViewBuilder let content: () -> Content

    init(
        glassEnabled: Bool = false,
        glowEnabled: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.glassEnabled = glassEnabled
        self.glowEnabled = glowEnabled
        self.content = content
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SonicMergeTheme.Radius.card, style: .continuous)
    }

    var body: some View {
        content()
            .padding(SonicMergeTheme.Spacing.md)       // 16pt internal padding
            .background(backgroundLayer)
            .clipShape(shape)
            .overlay(borderOverlay)
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if glassEnabled && !reduceTransparency {
            // Glass material with surfaceGlass tint
            ZStack {
                Color(uiColor: semantic.surfaceGlass)
                Rectangle().fill(.ultraThinMaterial)
            }
        } else {
            // Solid card surface (also reduceTransparency fallback)
            Color(uiColor: semantic.surfaceCard)
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if glassEnabled {
            shape.strokeBorder(
                Color(uiColor: semantic.accentGlow).opacity(0.18),
                lineWidth: 1
            )
        }
    }

    private var shadowColor: Color {
        if glowEnabled {
            return Color(uiColor: semantic.accentGlow).opacity(0.25)
        }
        return Color.black.opacity(0.10)
    }

    private var shadowRadius: CGFloat {
        glowEnabled ? 24 : 16
    }

    private var shadowY: CGFloat {
        glowEnabled ? 10 : 6
    }
}

#Preview("SquircleCard") {
    VStack(spacing: 20) {
        SquircleCard {
            Text("Default Card")
                .font(.subheadline.weight(.semibold))
        }
        SquircleCard(glassEnabled: true) {
            Text("Glass Card")
                .font(.subheadline.weight(.semibold))
        }
        SquircleCard(glowEnabled: true) {
            Text("Glow Card")
                .font(.subheadline.weight(.semibold))
        }
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
