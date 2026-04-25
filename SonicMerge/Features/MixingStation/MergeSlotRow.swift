// MergeSlotRow.swift
// SonicMerge
//
// Phase 7: SquircleCard-wrapped slot with gradient waveform and drag micro-animation.

import SwiftUI
import UIKit
import AVFoundation

struct MergeSlotRow: View {
    let clip: AudioClip
    let isPreviewing: Bool
    let onPreviewTap: () -> Void
    var onDelete: (() -> Void)? = nil

    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var peaks: [Float] = Array(repeating: 0, count: 50)

    /// Phase 7 drag micro-animation (MIX-05). Mirrors "is a finger currently on this row"
    /// into SwiftUI state via a no-op DragGesture(minimumDistance: 0). In Phase 10 the
    /// outer reorder gesture is .draggable (long-press based) — these two coexist via
    /// .simultaneousGesture and don't conflict.
    @GestureState private var isDragTouch: Bool = false

    /// Phase 10 (R-02 option 1): custom trailing-swipe-to-delete offset.
    /// Negative values reveal the red Delete swatch behind the card.
    @State private var swipeOffset: CGFloat = 0

    /// Past this magnitude, releasing the swipe commits the delete. Tunable.
    private static let swipeCommitThreshold: CGFloat = 80
    /// Maximum reveal width while finger is down — provides rubber-band feel.
    private static let swipeMaxReveal: CGFloat = 120

    var body: some View {
        ZStack(alignment: .trailing) {
            // Behind layer: red Delete swatch revealed by trailing swipe.
            if onDelete != nil {
                deleteSwatch
            }

            // Front layer: the card. Translates left as the user swipes.
            cardContent
                .offset(x: swipeOffset)
        }
        // Existing Phase 7 touch-tracking — fires on touch-down for visual feedback.
        // Kept as the primary .gesture; Phase 10 swipe is added as .simultaneousGesture
        // so they coexist without one stealing the other's events.
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isDragTouch) { _, state, _ in state = true }
        )
        // Phase 10 (R-02 option 1): horizontal swipe-to-delete.
        .simultaneousGesture(swipeGesture, including: onDelete == nil ? .none : .all)
        .sensoryFeedback(.impact(weight: .medium), trigger: isDragTouch)
        .sensoryFeedback(.impact(weight: .light), trigger: !isDragTouch)
        .contextMenu {
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Clip", systemImage: "trash")
                }
            }
        }
        .task { loadPeaks() }
    }

    private var cardContent: some View {
        SquircleCard(
            glassEnabled: false,
            glowEnabled: isDragTouch,
            // Phase 10: 10pt vertical / 14pt horizontal vs. Phase 7's 16pt uniform.
            contentPadding: EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        ) {
            HStack(alignment: .center, spacing: SonicMergeTheme.Spacing.md) {
                MergeSlotWaveformView(peaks: peaks)
                    .frame(width: 96, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: SonicMergeTheme.Spacing.xs) {
                    Text(clip.displayName)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color(uiColor: semantic.textPrimary))
                        .lineLimit(1)
                    Text(ClipDurationFormatting.mmss(from: clip.duration))
                        .font(.system(.caption, design: .rounded, weight: .regular))
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                }

                Spacer(minLength: 8)

                Button(action: onPreviewTap) {
                    Image(systemName: isPreviewing ? "stop.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(PillButtonStyle(variant: .filled, size: .icon))
                .accessibilityLabel(isPreviewing ? "Stop preview" : "Preview clip")
            }
        }
        .scaleEffect(isDragTouch ? 1.03 : 1.0)
        .animation(
            reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.72),
            value: isDragTouch
        )
    }

    private var deleteSwatch: some View {
        // The swatch grows with the swipe distance. Tinted system red, white trash icon.
        let reveal = max(0, -swipeOffset)
        let opacity = min(1, reveal / Self.swipeCommitThreshold)
        return ZStack(alignment: .trailing) {
            Color.red
                .opacity(opacity)
                .clipShape(RoundedRectangle(cornerRadius: SonicMergeTheme.Radius.card, style: .continuous))
            Image(systemName: "trash.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .opacity(opacity)
                .padding(.trailing, max(16, reveal / 4))
        }
        .accessibilityHidden(true)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                // Only react to horizontal-dominant left swipes.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                guard value.translation.width < 0 else {
                    if swipeOffset != 0 { swipeOffset = 0 }
                    return
                }
                // Linear up to threshold, then rubber-banded resistance beyond.
                let raw = value.translation.width
                if raw >= -Self.swipeCommitThreshold {
                    swipeOffset = raw
                } else {
                    let extra = raw + Self.swipeCommitThreshold
                    swipeOffset = -Self.swipeCommitThreshold + extra * 0.35
                }
                swipeOffset = max(swipeOffset, -Self.swipeMaxReveal)
            }
            .onEnded { value in
                let shouldDelete = value.translation.width < -Self.swipeCommitThreshold
                    && abs(value.translation.width) > abs(value.translation.height)
                withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78)) {
                    swipeOffset = shouldDelete ? -1000 : 0
                }
                if shouldDelete {
                    onDelete?()
                }
            }
    }

    private func loadPeaks() {
        guard let url = clip.waveformSidecarURL,
              let data = try? Data(contentsOf: url),
              data.count == 50 * MemoryLayout<Float>.size else { return }
        peaks = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
}

private struct MergeSlotWaveformView: View {
    let peaks: [Float]
    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        ZStack {
            // Backing well — mode-dependent contrast. Light: off-white, dark: near-black.
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: semantic.surfaceBase).opacity(0.85))

            // Full-thumbnail gradient, masked by the bar shapes so only the bars are visible.
            waveformGradient
                .mask {
                    Canvas { context, size in
                        guard !peaks.isEmpty else { return }
                        let barWidth = size.width / CGFloat(peaks.count)
                        for (i, peak) in peaks.enumerated() {
                            let barHeight = CGFloat(peak) * size.height * 0.92
                            let x = CGFloat(i) * barWidth
                            let y = (size.height - barHeight) / 2
                            let rect = CGRect(
                                x: x,
                                y: y,
                                width: max(barWidth - 1.2, 1),
                                height: max(barHeight, 2)
                            )
                            context.fill(Path(rect), with: .color(.white))
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var waveformGradient: some View {
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
                    Color(uiColor: semantic.accentAction),       // top-left Deep Indigo
                    Color(uiColor: semantic.accentAction),       // top-mid  Deep Indigo
                    Color(uiColor: semantic.accentGradientEnd),  // top-right Purple mix
                    Color(uiColor: semantic.accentAction),       // mid-left Deep Indigo
                    Color(uiColor: semantic.accentGradientEnd),  // center   Purple mix
                    Color(uiColor: semantic.accentGradientEnd),  // mid-right Purple
                    Color(uiColor: semantic.accentGradientEnd),  // bot-left Purple mix
                    Color(uiColor: semantic.accentGradientEnd),  // bot-mid  Purple
                    Color(uiColor: semantic.accentGradientEnd)   // bot-right Purple
                ]
            )
        } else {
            LinearGradient(
                colors: [
                    Color(uiColor: semantic.accentAction),
                    Color(uiColor: semantic.accentGradientEnd)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
