// WaveformPathView.swift
// SonicMerge
//
// Phase 11 (Premium Studio Polish): continuous glowing waveform path,
// replacing the Phase 7/8 bar-style renderers. Closes a single Canvas path
// through every peak top, mirrors back through the bottom for a symmetric
// silhouette, then fills with the existing Deep Indigo → Purple gradient.
// A drop-shadow filter gives the waveform depth inside its card.

import SwiftUI
import UIKit

/// Shared continuous-path waveform renderer.
///
/// `peaks` are normalized [0, 1] amplitudes; the renderer assumes pre-
/// normalized peaks (call sites already provide this — same input shape
/// the previous bar renderers used).
struct WaveformPathView: View {
    let peaks: [Float]

    /// Vertical inset from the canvas top/bottom so the path doesn't kiss
    /// the card edges. Tunable per call site (clip thumbnail vs. full-width
    /// Cleaning Lab readout).
    var verticalInset: CGFloat = 4

    /// Drop-shadow blur radius. Set to 0 for no shadow.
    var shadowRadius: CGFloat = 6

    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Canvas { ctx, size in
            guard peaks.count > 1 else { return }
            let centerY = size.height / 2
            let usable = max(centerY - verticalInset, 1)
            let stepX = size.width / CGFloat(peaks.count - 1)

            var path = Path()
            // Top edge — left to right through every peak.
            for (i, peak) in peaks.enumerated() {
                let x = CGFloat(i) * stepX
                let amplitude = CGFloat(max(0.02, min(1.0, peak))) * usable
                let y = centerY - amplitude
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            // Bottom edge — right to left, mirrored through center.
            for (i, peak) in peaks.enumerated().reversed() {
                let x = CGFloat(i) * stepX
                let amplitude = CGFloat(max(0.02, min(1.0, peak))) * usable
                let y = centerY + amplitude
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.closeSubpath()

            // Drop shadow filter — affects subsequent fill draws.
            // Suppressed when reduceTransparency for cleaner rendering.
            if shadowRadius > 0 && !reduceTransparency {
                ctx.addFilter(.shadow(
                    color: Color(uiColor: semantic.accentAction).opacity(0.30),
                    radius: shadowRadius,
                    x: 0,
                    y: 3
                ))
            }

            // Fill with the same Indigo → Purple gradient as the prior
            // bar renderer used, but applied to the whole closed silhouette.
            let gradient = LinearGradient(
                colors: [
                    Color(uiColor: semantic.accentAction),
                    Color(uiColor: semantic.accentGradientEnd)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            ctx.fill(path, with: .style(gradient))
        }
    }
}

#Preview("WaveformPathView") {
    WaveformPathView(
        peaks: (0..<50).map { Float(0.3 + 0.6 * sin(Double($0) * 0.4)) }
    )
    .frame(width: 320, height: 80)
    .padding()
}
