// StudioGlassChrome.swift
// SonicMerge
//
// Phase 12 (Smart Cut Studio Refactor): two reusable view modifiers that
// produce the layered-glass surfaces called out in the design spec
// (§4.3): a glassmorphic outer card chassis and a frosted capsule for
// tag-style chips. Both honor accessibilityReduceTransparency by swapping
// the material for an opaque surface — same pattern as Phase 10/11.

import SwiftUI
import UIKit

// MARK: - Modifiers

private struct StudioGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(reduceTransparency
                        ? AnyShapeStyle(Color(uiColor: semantic.surfaceCard))
                        : AnyShapeStyle(.ultraThinMaterial))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        Color(uiColor: semantic.accentGlow)
                            .opacity(reduceTransparency ? 0.30 : 0.18),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color(uiColor: semantic.accentGlow).opacity(0.10),
                radius: 16, x: 0, y: 6
            )
    }
}

private struct StudioFrostedCapsuleModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(reduceTransparency
                        ? AnyShapeStyle(Color(uiColor: semantic.surfaceCard))
                        : AnyShapeStyle(.ultraThinMaterial))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        Color(uiColor: semantic.accentAction)
                            .opacity(reduceTransparency ? 0.35 : 0.20),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - View extensions

extension View {
    /// Phase 12: glass card chassis used by StudioSummaryCard.
    /// 24pt corner radius default.
    func studioGlassCard(cornerRadius: CGFloat = 24) -> some View {
        modifier(StudioGlassCardModifier(cornerRadius: cornerRadius))
    }

    /// Phase 12: frosted capsule used by tag chips, occurrence sheet rows,
    /// and the saves chip.
    func studioFrostedCapsule(cornerRadius: CGFloat = 14) -> some View {
        modifier(StudioFrostedCapsuleModifier(cornerRadius: cornerRadius))
    }
}
