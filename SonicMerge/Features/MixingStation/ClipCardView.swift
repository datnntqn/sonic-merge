// ClipCardView.swift
// SonicMerge

import SwiftUI
import UIKit
import AVFoundation

/// A row in the Mixing Station List showing waveform thumbnail, file name, duration, and preview.
struct ClipCardView: View {
    let clip: AudioClip
    let isPreviewing: Bool
    let onPreviewTap: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var peaks: [Float] = Array(repeating: 0, count: 50)

    var body: some View {
        HStack(spacing: 12) {
            WaveformThumbnailView(peaks: peaks)
                .frame(width: 60, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(clip.displayName)
                    .font(.system(.body, design: .default, weight: .medium))
                    .foregroundStyle(Color(uiColor: SonicMergeTheme.ColorPalette.primaryText))
                    .lineLimit(1)
                Text(ClipDurationFormatting.mmss(from: clip.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(action: onPreviewTap) {
                Image(systemName: isPreviewing ? "stop.fill" : "play.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(uiColor: SonicMergeTheme.ColorPalette.primaryAccent))
                    .padding(10)
                    .background(Color(uiColor: SonicMergeTheme.ColorPalette.primaryAccent).opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPreviewing ? "Stop preview" : "Preview clip")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(uiColor: SonicMergeTheme.ColorPalette.cardSurface))
        .clipShape(RoundedRectangle(cornerRadius: SonicMergeTheme.Radius.card, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
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

/// Canvas-based bar chart rendering 50 Float amplitude peaks.
private struct WaveformThumbnailView: View {
    let peaks: [Float]

    var body: some View {
        Canvas { context, size in
            guard !peaks.isEmpty else { return }
            let barWidth = size.width / CGFloat(peaks.count)
            let accentBlue = Color(uiColor: SonicMergeTheme.ColorPalette.primaryAccent)

            for (i, peak) in peaks.enumerated() {
                let barHeight = CGFloat(peak) * size.height
                let x = CGFloat(i) * barWidth
                let y = (size.height - barHeight) / 2
                let rect = CGRect(x: x, y: y, width: max(barWidth - 1, 1), height: max(barHeight, 1))
                context.fill(Path(rect), with: .color(accentBlue))
            }
        }
        .background(Color(uiColor: SonicMergeTheme.ColorPalette.canvasBackground))
    }
}
