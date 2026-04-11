// PillButtonStyle.swift
// SonicMerge
//
// DS-03: Pill button style with inner glow and haptic. English comments.

import SwiftUI

struct PillButtonStyle: ButtonStyle {
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .frame(minHeight: 44)
            .background(backgroundFill)
            .clipShape(Capsule())
            .overlay(innerGlowOverlay)
            .scaleEffect(scaleValue(configuration.isPressed))
            .animation(
                reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6),
                value: configuration.isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)
    }

    private var backgroundFill: some ShapeStyle {
        Color(uiColor: semantic.accentAction)
            .opacity(isEnabled ? 1.0 : 0.35)
    }

    @ViewBuilder
    private var innerGlowOverlay: some View {
        if isEnabled {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.6)
                    )
                )
                .allowsHitTesting(false)
        }
    }

    private func scaleValue(_ isPressed: Bool) -> CGFloat {
        guard !reduceMotion else { return 1.0 }
        return isPressed ? 0.96 : 1.0
    }
}

#Preview("PillButton") {
    VStack(spacing: 20) {
        Button("Get Started") { }
            .buttonStyle(PillButtonStyle())
        Button("Disabled") { }
            .buttonStyle(PillButtonStyle())
            .disabled(true)
    }
    .padding()
}
