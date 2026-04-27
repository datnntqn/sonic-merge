// PauseControlRow.swift
// SonicMerge
//
// Phase 12 (Smart Cut Studio Refactor): content of the long-pauses bento
// card. ⏱ icon + slider (1.0...3.0s, step 0.25s) + rolling-digit threshold
// readout + saves chip. Slider is bound to a local @State so the rolling
// text animates smoothly during drag; on each step change the new value
// is pushed to the VM via setPauseThreshold (which re-runs PauseDetector
// and updates editList.pauses synchronously). Light haptic per step.

import SwiftUI
import UIKit

struct PauseControlRow: View {
    @Bindable var viewModel: SmartCutViewModel
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Drives the slider locally so the rolling-digit readout animates
    /// smoothly during drag. Synced via .onAppear and .onChange.
    @State private var draftThreshold: TimeInterval = 1.5

    private var pauseSavings: TimeInterval {
        viewModel.editList.pauses.filter(\.isEnabled).reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        StudioBentoCard(
            leading: {
                HStack(spacing: 12) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("LONG PAUSES")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                            Spacer()
                            Text(SmartCutFormatting.formatThreshold(draftThreshold))
                                .font(.headline.monospacedDigit())
                                .contentTransition(reduceMotion ? .identity : .numericText())
                        }
                        Slider(value: $draftThreshold, in: 1.0...3.0, step: 0.25)
                            .tint(Color(uiColor: semantic.accentAction))
                            .onChange(of: draftThreshold) { _, new in
                                viewModel.setPauseThreshold(new)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                    }
                }
            },
            trailing: {
                SavesChip(seconds: pauseSavings)
                    .contentTransition(reduceMotion ? .identity : .numericText())
            }
        )
        .onAppear { draftThreshold = viewModel.pauseThreshold }
    }
}
