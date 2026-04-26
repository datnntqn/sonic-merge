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
    /// Phase 10 discoverability: when supplied, a "Move Up" item is rendered in
    /// the long-press context menu — gives a non-gesture path to reorder for
    /// users who don't think to drag the card.
    var onMoveUp: (() -> Void)? = nil
    /// Likewise for "Move Down". Pass nil at the column edges to hide the option.
    var onMoveDown: (() -> Void)? = nil

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
        // Phase 7 touch-tracking + Phase 10 swipe-to-delete are BOTH attached as
        // .simultaneousGesture so neither claims touch ownership. .draggable
        // (Wave 5, applied by the parent MergeTimelineView) is a long-press-based
        // system gesture; if any DragGesture(minimumDistance: 0) here is attached
        // via .gesture (primary), the long-press never fires and reorder breaks.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isDragTouch) { _, state, _ in state = true }
        )
        // Phase 10 (R-02 option 1): horizontal swipe-to-delete.
        .simultaneousGesture(swipeGesture, including: onDelete == nil ? .none : .all)
        .sensoryFeedback(.impact(weight: .medium), trigger: isDragTouch)
        .sensoryFeedback(.impact(weight: .light), trigger: !isDragTouch)
        .contextMenu {
            if let onMoveUp {
                Button(action: onMoveUp) {
                    Label("Move Up", systemImage: "arrow.up")
                }
            }
            if let onMoveDown {
                Button(action: onMoveDown) {
                    Label("Move Down", systemImage: "arrow.down")
                }
            }
            if onMoveUp != nil || onMoveDown != nil, onDelete != nil {
                Divider()
            }
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
                WaveformPathView(peaks: peaks, verticalInset: 4, shadowRadius: 4)
                    .frame(width: 96, height: 44)
                    .background(
                        // Phase 7/10 backing well preserved for contrast on
                        // low-amplitude waveforms.
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(uiColor: semantic.surfaceBase).opacity(0.85))
                    )
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

