// IdleSettingsCards.swift
// SonicMerge
//
// Pre-analyze controls on the Smart Cut idle screen: the long-pause
// threshold slider and a read-only filler-word summary with an Edit
// link. The pause card writes directly to viewModel.pauseThreshold;
// the filler card displays library.allWords as read-only chips and
// calls back via `onEditFillerList` to open the existing
// EditFillerListStudioSheet (sheet attachment lives at the
// SmartCutStudioContainer body level).
//
// Spec: docs/superpowers/specs/2026-05-04-smart-cut-idle-controls-design.md

import SwiftUI
import UIKit

struct IdleSettingsCards: View {
    @Bindable var viewModel: SmartCutViewModel
    @Binding var library: FillerLibrary
    let onEditFillerList: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            IdlePauseCard(viewModel: viewModel)
            IdleFillerCard(library: library, onEdit: onEditFillerList)
        }
    }
}

// MARK: - Pause card

private struct IdlePauseCard: View {
    @Bindable var viewModel: SmartCutViewModel
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Drives the slider locally so the rolling-digit readout animates
    /// smoothly during drag. Synced via .onAppear (initial) and pushed to
    /// viewModel.pauseThreshold on each step change.
    @State private var draftThreshold: TimeInterval = 1.5

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
                                // Pre-analyze direct write — setPauseThreshold(_:) bails
                                // when cachedSegments is empty, which is always true here.
                                viewModel.pauseThreshold = new
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        Text("Cuts silences longer than \(SmartCutFormatting.formatThreshold(draftThreshold)).")
                            .font(.caption)
                            .foregroundStyle(Color(uiColor: semantic.textSecondary))
                            .contentTransition(reduceMotion ? .identity : .numericText())
                    }
                }
            },
            trailing: { EmptyView() }
        )
        .onAppear { draftThreshold = viewModel.pauseThreshold }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pause threshold: \(SmartCutFormatting.formatThreshold(draftThreshold))")
        .accessibilityHint("Adjust to set the minimum silence length that gets cut.")
    }
}

// MARK: - Filler card

private struct IdleFillerCard: View {
    let library: FillerLibrary
    let onEdit: () -> Void
    @Environment(\.sonicMergeSemantic) private var semantic

    private var words: [String] { library.allWords }

    var body: some View {
        StudioBentoCard(
            leading: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "text.bubble")
                            .foregroundStyle(Color(uiColor: semantic.textSecondary))
                            .font(.title3)
                        Text("FILLER WORDS")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(uiColor: semantic.textSecondary))
                        Spacer()
                        Text("\(words.count) word\(words.count == 1 ? "" : "s")")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Capsule().fill(Color(uiColor: semantic.accentAction).opacity(0.14)))
                            .foregroundStyle(Color(uiColor: semantic.accentAction))
                    }

                    if words.isEmpty {
                        Text("No filler words. Tap Edit list to add some.")
                            .font(.subheadline)
                            .foregroundStyle(Color(uiColor: semantic.textSecondary))
                    } else {
                        ChipFlow(words: words)
                            .accessibilityHidden(true)
                    }

                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Edit list")
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(uiColor: semantic.accentAction))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit filler list")
                }
            },
            trailing: { EmptyView() }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filler words. \(words.count) word\(words.count == 1 ? "" : "s"). Tap Edit list to modify.")
    }
}

// MARK: - Chip flow (uses existing StudioFlowLayout)

private struct ChipFlow: View {
    let words: [String]

    var body: some View {
        StudioFlowLayout(spacing: 6) {
            ForEach(words, id: \.self) { word in
                WordCapsule(word: word, onRemove: nil)
            }
        }
    }
}
