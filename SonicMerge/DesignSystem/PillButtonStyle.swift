// PillButtonStyle.swift
// SonicMerge
//
// DS-03: Pill button style with inner glow and haptic. English comments.
// Phase 7: extended with Variant (filled/outline) and Size (regular/compact/icon) parameters.
// Defaults (variant: .filled, size: .regular) preserve Phase 6 visual exactly.

import SwiftUI

struct PillButtonStyle: ButtonStyle {
    enum Variant {
        case filled     // Deep Indigo background, white label, inner glow (Phase 6 default)
        case outline    // Transparent background, 1pt accentAction@0.5 stroke, textPrimary label
    }

    enum Size {
        case regular    // 24pt horizontal, 12pt vertical, 44pt min-height (Phase 6 default)
        case compact    // 16pt horizontal, 12pt vertical, 44pt min-height (Phase 7 gap row)
        case icon       //  0pt horizontal,  0pt vertical, 44×44 fixed frame (Phase 7 play button)
    }

    let variant: Variant
    let size: Size

    init(variant: Variant = .filled, size: Size = .regular) {
        self.variant = variant
        self.size = size
    }

    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(labelColor)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .frame(
                minWidth: size == .icon ? 44 : nil,
                minHeight: 44,
                maxHeight: size == .icon ? 44 : nil
            )
            .frame(width: size == .icon ? 44 : nil, height: size == .icon ? 44 : nil)
            .background(backgroundFill)
            .clipShape(Capsule())
            .overlay(borderOverlay)
            .overlay(innerGlowOverlay)
            .scaleEffect(scaleValue(configuration.isPressed))
            .animation(
                reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6),
                value: configuration.isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)
    }

    // MARK: - Layout

    private var horizontalPadding: CGFloat {
        switch size {
        case .regular: return 24
        case .compact: return 16
        case .icon:    return 0
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .regular, .compact: return 12
        case .icon:              return 0
        }
    }

    // MARK: - Colors

    private var labelColor: Color {
        switch variant {
        case .filled:  return .white
        case .outline: return Color(uiColor: semantic.textPrimary)
        }
    }

    @ViewBuilder
    private var backgroundFill: some View {
        switch variant {
        case .filled:
            Color(uiColor: semantic.accentAction)
                .opacity(isEnabled ? 1.0 : 0.35)
        case .outline:
            Color.clear
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if variant == .outline {
            Capsule()
                .strokeBorder(
                    Color(uiColor: semantic.accentAction).opacity(isEnabled ? 0.5 : 0.2),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var innerGlowOverlay: some View {
        if variant == .filled && isEnabled {
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
        Button("0.5s") { }
            .buttonStyle(PillButtonStyle(variant: .outline, size: .compact))
        Button("1.0s") { }
            .buttonStyle(PillButtonStyle(variant: .filled, size: .compact))
        Button {
        } label: {
            Image(systemName: "play.fill")
                .font(.system(size: 16, weight: .semibold))
        }
        .buttonStyle(PillButtonStyle(variant: .filled, size: .icon))
    }
    .padding()
}
