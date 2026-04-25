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
    /// into SwiftUI state via a no-op DragGesture(minimumDistance: 0) running in parallel
    /// with the system List.onMove reorder gesture. The system gesture keeps reordering
    /// working (protects the reorder-crash fix); this one only drives visual state.
    @GestureState private var isDragTouch: Bool = false

    var body: some View {
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
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isDragTouch) { _, state, _ in state = true }
        )
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
