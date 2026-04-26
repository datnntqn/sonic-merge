// PillButtonStyle.swift
// SonicMerge
//
// DS-03: Pill button style with inner glow and haptic. English comments.
// Phase 7: extended with Variant (filled/outline) and Size (regular/compact/icon) parameters.
// Phase 8: extended with Tint enum (.accent/.ai) for Lime Green AI action pills.
// Defaults (variant: .filled, size: .regular, tint: .accent) preserve Phase 6/7 visual exactly.

import SwiftUI

struct PillButtonStyle: ButtonStyle {
    enum Variant {
        case filled     // Deep Indigo background, white label, inner glow (Phase 6 default)
        case outline    // Transparent background, 1pt accentAction@0.5 stroke, textPrimary label
    }

    enum Size {
        case regular    // 24pt horizontal, 12pt vertical, 44pt min-height (Phase 6 default)
        case compact    // 16pt horizontal, 12pt vertical, 44pt min-height (Phase 7 gap row)
        case icon       //  0pt horizontal,  0pt vertical, 44x44 fixed frame (Phase 7 play button)
    }

    enum Tint {
        case accent  // Deep Indigo (Phase 6/7 default) — white label, accentAction fill
        case ai      // Lime Green (Phase 8 AI actions) — dark #1C1C1E label, accentAI fill (WCAG AAA 7.38:1)
    }

    let variant: Variant
    let size: Size
    let tint: Tint

    init(variant: Variant = .filled, size: Size = .regular, tint: Tint = .accent) {
        self.variant = variant
        self.size = size
        self.tint = tint
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
            .overlay(specularHighlight)
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
        switch (variant, tint) {
        case (.filled, .accent): return .white
        case (.filled, .ai):     return Color(uiColor: SonicMergeTheme.ColorPalette.primaryText) // #1C1C1E — 7.38:1 AAA on Lime Green
        case (.outline, _):      return Color(uiColor: semantic.textPrimary)
        }
    }

    @ViewBuilder
    private var backgroundFill: some View {
        switch (variant, tint) {
        case (.filled, .accent):
            Color(uiColor: semantic.accentAction)
                .opacity(isEnabled ? 1.0 : 0.35)
        case (.filled, .ai):
            Color(uiColor: semantic.accentAI)
                .opacity(isEnabled ? 1.0 : 0.35)
        case (.outline, _):
            Color.clear
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if variant == .outline {
            let strokeColor = tint == .ai
                ? Color(uiColor: semantic.accentAI)
                : Color(uiColor: semantic.accentAction)
            Capsule()
                .strokeBorder(
                    strokeColor.opacity(isEnabled ? 0.5 : 0.2),
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

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Phase 11: thin white line at the top inner edge — a specular
    /// highlight that reads as light reflecting off a glass surface.
    /// Layered ON TOP of innerGlowOverlay (the broad soft glow) for a
    /// premium glass effect: soft glow + sharp top highlight.
    /// Suppressed for outline variants (no surface to reflect off) and
    /// when accessibilityReduceTransparency is on.
    @ViewBuilder
    private var specularHighlight: some View {
        if variant == .filled && isEnabled && !reduceTransparency {
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.white.opacity(0.10),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.45)
                    ),
                    lineWidth: 1
                )
                .blendMode(.screen)
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
        Button("Clean Audio") { }
            .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
        Button("AI Denoise") { }
            .buttonStyle(PillButtonStyle(variant: .outline, size: .regular, tint: .ai))
    }
    .padding()
}
