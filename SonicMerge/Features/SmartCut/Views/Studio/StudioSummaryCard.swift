// StudioSummaryCard.swift
// SonicMerge
//
// Phase 12 (Smart Cut Studio Refactor): glassmorphic top-of-screen card
// anchoring the Smart Cut tab. Eyebrow ("✨ SMART CUT SUMMARY"), stats
// line ("7 fillers + 2 long pauses"), pulsating saves badge, and a
// Reset link in the trailing edge of the eyebrow row.

import SwiftUI

struct StudioSummaryCard: View {
    let fillerCount: Int
    let pauseCount: Int
    let savings: TimeInterval
    let onReset: () -> Void

    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("✨ SMART CUT SUMMARY")
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color(uiColor: semantic.accentAction))
                Spacer()
                Button(action: onReset) {
                    Text("Reset")
                        .font(.subheadline)
                        .foregroundStyle(Color(uiColor: semantic.accentAction).opacity(0.5))
                }
                .accessibilityHint("Clear current Smart Cut analysis")
            }
            Text(statsLine)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
            StudioPulseSavesBadge(seconds: savings)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioGlassCard(cornerRadius: 24)
        .accessibilityElement(children: .combine)
    }

    private var statsLine: String {
        let f = "\(fillerCount) filler\(fillerCount == 1 ? "" : "s")"
        let p = "\(pauseCount) long pause\(pauseCount == 1 ? "" : "s")"
        return "\(f) + \(p)"
    }
}

#Preview("StudioSummaryCard") {
    StudioSummaryCard(fillerCount: 7, pauseCount: 2, savings: 31, onReset: {})
        .padding()
}
