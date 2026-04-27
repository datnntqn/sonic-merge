// StudioBentoCard.swift
// SonicMerge
//
// Phase 12 (Smart Cut Studio Refactor): generic single-column wide bento
// card chassis used by both filler-category cards and the long-pauses
// card. 28pt continuous squircle, opaque white surfaceCard fill (NOT
// glass — sits on the page background, not on another glass surface),
// soft Deep Indigo shadow, leading + trailing content slots.
//
// The `isDisabled` flag drives the toggle-off treatment: opacity 0.40,
// text bold + strikethrough + Deep Indigo (applied at the content site
// via a wrapping modifier — see FillerCategoryRow for the call shape).
// The card itself dampens its shadow when disabled.

import SwiftUI

struct StudioBentoCard<Leading: View, Trailing: View>: View {
    let leading: Leading
    let trailing: Trailing
    var isDisabled: Bool = false
    var onTap: (() -> Void)? = nil

    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        isDisabled: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.isDisabled = isDisabled
        self.onTap = onTap
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        // The card body. If onTap is provided, wrap the content area in a
        // Button so the card-body region is one tappable target. Trailing
        // content (typically containing its own Buttons) stays as a sibling
        // outside that Button so SwiftUI's hit-test prefers it.
        HStack(spacing: 12) {
            if let onTap {
                Button(action: onTap) {
                    HStack { leading; Spacer(minLength: 0) }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                leading
                Spacer(minLength: 0)
            }
            trailing
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(uiColor: semantic.surfaceCard))
        )
        .shadow(
            color: Color(uiColor: semantic.accentGlow).opacity(isDisabled ? 0.04 : 0.10),
            radius: isDisabled ? 6 : 16,
            x: 0,
            y: isDisabled ? 2 : 6
        )
        .opacity(isDisabled ? 0.40 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.75), value: isDisabled)
    }
}
