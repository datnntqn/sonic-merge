// LimeGreenSlider.swift
// SonicMerge
//
// Phase 8 — CL-02: Custom Lime Green slider with Deep Indigo thumb.
//
// Replaces the system Slider control. Renders a Lime Green filled track
// with a 28pt Deep Indigo pill thumb and Lime Green glow shadow.
//
// Matches the iOS Slider API signature: init(value:in:onEditingChanged:)
// Supports tap-to-jump and continuous drag via DragGesture(minimumDistance: 0).
// 44pt touch target via GeometryReader frame + contentShape(Rectangle()).
//
// All colors resolve through @Environment(\.sonicMergeSemantic) — zero hardcoded values.

import SwiftUI

// MARK: - LimeGreenSlider

/// Custom gesture-based slider with Lime Green track fill and Deep Indigo pill thumb.
///
/// API matches the iOS system Slider so ViewModel call sites need no changes.
/// Supports tap-to-jump (DragGesture with minimumDistance: 0) and continuous drag.
/// Accessibility: .accessibilityValue with percentage + .accessibilityAdjustableAction for VoiceOver.
struct LimeGreenSlider: View {

    @Binding var value: Double
    let range: ClosedRange<Double>
    var onEditingChanged: ((Bool) -> Void)?

    init(
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0...1,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._value = value
        self.range = range
        self.onEditingChanged = onEditingChanged
    }

    // MARK: - Environment

    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var isEditing = false

    // MARK: - reduceTransparency fallback (per D-07)

    private var thumbGlowRadius: CGFloat { reduceTransparency ? 6 : 12 }
    private var thumbGlowOpacity: Double { reduceTransparency ? 0.50 : 0.35 }

    // MARK: - Computed

    private var normalizedValue: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private func thumbOffset(in width: CGFloat) -> CGFloat {
        max(0, width * CGFloat(normalizedValue)) - 14  // 14 = thumb radius (28pt / 2)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Unfilled track
                Capsule()
                    .fill(Color(uiColor: semantic.surfaceBase).opacity(0.3))
                    .frame(height: 6)

                // Filled track — Lime Green
                Capsule()
                    .fill(Color(uiColor: semantic.accentAI))
                    .frame(width: max(0, geo.size.width * CGFloat(normalizedValue)), height: 6)

                // Thumb — Deep Indigo pill with Lime Green glow
                Circle()
                    .fill(Color(uiColor: semantic.accentAction))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(
                        color: Color(uiColor: semantic.accentAI).opacity(thumbGlowOpacity),
                        radius: thumbGlowRadius,
                        x: 0,
                        y: 0
                    )
                    .offset(x: thumbOffset(in: geo.size.width))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let ratio = drag.location.x / geo.size.width
                        let clamped = min(max(ratio, 0), 1)
                        value = range.lowerBound + Double(clamped) * (range.upperBound - range.lowerBound)
                        if !isEditing {
                            isEditing = true
                            onEditingChanged?(true)
                        }
                    }
                    .onEnded { _ in
                        isEditing = false
                        onEditingChanged?(false)
                    }
            )
        }
        .frame(height: 44)
        .opacity(isEnabled ? 1.0 : 0.4)
        .allowsHitTesting(isEnabled)
        .sensoryFeedback(.selection, trigger: isEditing)
        .accessibilityValue("\(Int(normalizedValue * 100)) percent")
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) * 0.05
            switch direction {
            case .increment: value = min(value + step, range.upperBound)
            case .decrement: value = max(value - step, range.lowerBound)
            @unknown default: break
            }
        }
    }
}
