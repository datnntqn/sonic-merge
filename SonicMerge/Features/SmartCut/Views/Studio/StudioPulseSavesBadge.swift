// StudioPulseSavesBadge.swift
// SonicMerge
//
// Phase 12 (Smart Cut Studio Refactor): the pulsating "saves ~31s"
// badge that anchors the Summary Card. TimelineView drives a single
// animation pump producing both the scale (1.0 ↔ 1.04) and the lime
// green outer glow alpha (0.40 ↔ 0.65) over a ~1.6s sine cycle.
// Halts when reduceMotion is on OR when seconds == 0 (no savings to
// celebrate — static, dimmer presentation).

import SwiftUI
import UIKit

struct StudioPulseSavesBadge: View {
    let seconds: TimeInterval

    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shouldPause: Bool { reduceMotion || seconds == 0 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: shouldPause)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = (sin(t * (2 * .pi / 1.6)) + 1) / 2  // 0...1 over ~1.6s
            let scale = shouldPause ? 1.0 : 1.0 + 0.04 * phase
            let glowAlpha = shouldPause ? 0.40 : 0.40 + 0.25 * phase

            Text(label)
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundStyle(Color.black)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    Capsule().fill(Color(uiColor: semantic.accentAI))
                )
                .scaleEffect(scale)
                .shadow(
                    color: Color(uiColor: semantic.accentAI).opacity(glowAlpha),
                    radius: 12, x: 0, y: 0
                )
                .contentTransition(reduceMotion ? .identity : .numericText())
                .accessibilityLabel("saves \(Int(seconds)) seconds")
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    private var label: String {
        // "saves ~31s" / "saves ~1m 5s"
        let total = Int(seconds.rounded())
        if total < 60 { return "saves ~\(total)s" }
        let m = total / 60
        let s = total % 60
        return s == 0 ? "saves ~\(m)m" : "saves ~\(m)m \(s)s"
    }
}

#Preview("StudioPulseSavesBadge") {
    VStack(spacing: 24) {
        StudioPulseSavesBadge(seconds: 31)
        StudioPulseSavesBadge(seconds: 0)
        StudioPulseSavesBadge(seconds: 65)
    }
    .padding()
}
