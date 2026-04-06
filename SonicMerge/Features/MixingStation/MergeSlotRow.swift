// MergeSlotRow.swift
// SonicMerge
//
// Conveyor-style slot: larger waveform, play, reorder handle.

import SwiftUI
import UIKit
import AVFoundation

struct MergeSlotRow: View {
    let clip: AudioClip
    let isPreviewing: Bool
    let onPreviewTap: () -> Void
    var onDelete: (() -> Void)? = nil

    @Environment(\.sonicMergeSemantic) private var semantic
    @State private var peaks: [Float] = Array(repeating: 0, count: 50)

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            MergeSlotWaveformView(peaks: peaks)
                .frame(width: 100, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(clip.displayName)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
                    .lineLimit(1)
                Text(ClipDurationFormatting.mmss(from: clip.duration))
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
            }

            Spacer(minLength: 8)

            Button(action: onPreviewTap) {
                Image(systemName: isPreviewing ? "stop.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(uiColor: semantic.surfaceBase))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color(uiColor: semantic.accentAction))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPreviewing ? "Stop preview" : "Preview clip")

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                .accessibilityLabel("Reorder clip")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: SonicMergeTheme.Radius.card, style: .continuous)
                .fill(Color(uiColor: semantic.surfaceSlot))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SonicMergeTheme.Radius.card, style: .continuous)
                .strokeBorder(Color(uiColor: semantic.accentAction).opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
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
        Canvas { context, size in
            guard !peaks.isEmpty else { return }
            let barWidth = size.width / CGFloat(peaks.count)
            let color = Color(uiColor: semantic.accentWaveform)

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
                context.fill(Path(rect), with: .color(color.opacity(0.95)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(uiColor: semantic.surfaceBase).opacity(0.85))
        )
    }
}
