// ClipCardView.swift
// SonicMerge

import SwiftUI
import AVFoundation

/// A row in the Mixing Station List showing waveform thumbnail, file name, and duration.
///
/// Waveform thumbnail: Canvas-rendered bar chart, 50 bars, accent blue (#007AFF).
/// The .waveform sidecar (50 Float32 peak values) is loaded on appear.
struct ClipCardView: View {
    let clip: AudioClip

    @State private var peaks: [Float] = Array(repeating: 0, count: 50)

    var body: some View {
        HStack(spacing: 12) {
            // Waveform thumbnail
            WaveformThumbnailView(peaks: peaks)
                .frame(width: 60, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Metadata
            VStack(alignment: .leading, spacing: 2) {
                Text(clip.displayName)
                    .font(.system(.body, design: .default, weight: .medium))
                    .foregroundStyle(Color(red: 0.110, green: 0.110, blue: 0.118))
                    .lineLimit(1)
                Text(formattedDuration(clip.duration))
                    .font(.system(.caption, design: .default))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task { loadPeaks() }
    }

    private func loadPeaks() {
        guard let url = clip.waveformSidecarURL,
              let data = try? Data(contentsOf: url),
              data.count == 50 * MemoryLayout<Float>.size else { return }
        peaks = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

/// Canvas-based bar chart rendering 50 Float amplitude peaks.
private struct WaveformThumbnailView: View {
    let peaks: [Float]

    var body: some View {
        Canvas { context, size in
            guard !peaks.isEmpty else { return }
            let barWidth = size.width / CGFloat(peaks.count)
            let accentBlue = Color(red: 0, green: 0.478, blue: 1.0)

            for (i, peak) in peaks.enumerated() {
                let barHeight = CGFloat(peak) * size.height
                let x = CGFloat(i) * barWidth
                let y = (size.height - barHeight) / 2
                let rect = CGRect(x: x, y: y, width: max(barWidth - 1, 1), height: max(barHeight, 1))
                context.fill(Path(rect), with: .color(accentBlue))
            }
        }
        .background(Color(red: 0.973, green: 0.976, blue: 0.980))
    }
}
