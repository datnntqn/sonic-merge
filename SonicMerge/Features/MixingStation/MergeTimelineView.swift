// MergeTimelineView.swift
// SonicMerge
//
// Vertical “conveyor”: trust strip, sequence slots with + between clips, = then output card.

import SwiftUI
import UIKit

struct MergeTimelineView: View {
    @Environment(MixingStationViewModel.self) private var viewModel
    @Environment(\.sonicMergeSemantic) private var semantic

    /// Phase 10 D-06: shared with MixingStationView via @AppStorage. Once the user
    /// has imported a clip, this flips to true permanently and the trust banner is
    /// hidden on every subsequent launch.
    @AppStorage("sonicMerge.hasImportedFirstClip") private var hasImportedFirstClip: Bool = false

    let onExportTap: () -> Void

    private var totalDuration: TimeInterval {
        viewModel.clips.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        List {
            if !hasImportedFirstClip {
                Section {
                    LocalFirstTrustStrip()
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SEQUENCE")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Color(uiColor: semantic.accentAction))
                    Text(summarySubtitle)
                        .font(.system(.caption, design: .rounded, weight: .regular))
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                ForEach(Array(viewModel.clips.enumerated()), id: \.element.id) { index, clip in
                    VStack(spacing: 0) {
                        if index > 0 {
                            MergeOperatorLabel(kind: .plus)
                                .padding(.top, 4)
                                .padding(.bottom, 2)
                        }

                        MergeSlotRow(
                            clip: clip,
                            isPreviewing: viewModel.previewingClipID == clip.id,
                            onPreviewTap: { viewModel.toggleClipPreview(clip) },
                            onDelete: { viewModel.deleteClip(id: clip.id) }
                        )
                        .padding(.vertical, SonicMergeTheme.Spacing.sm)

                        if index < viewModel.clips.count - 1,
                           let transition = clip.gapTransition {
                            GapRowView(transition: transition) { gapDuration, isCrossfade in
                                viewModel.updateTransition(
                                    transition,
                                    gapDuration: gapDuration,
                                    isCrossfade: isCrossfade
                                )
                            }
                        }
                    }
                    .background(alignment: .leading) {
                        // Phase 7 MIX-02: central connecting line. Hidden when only one clip exists.
                        if viewModel.clips.count >= 2 {
                            TimelineSpineView()
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.deleteClip(id: clip.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove { from, to in viewModel.moveClip(fromOffsets: from, toOffset: to) }
            }

            Section {
                MergeOperatorLabel(kind: .equals)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                mergeOutputCard
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 20, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: semantic.surfaceBase))
        .environment(\.editMode, .constant(.active))
    }

    private var summarySubtitle: String {
        let n = viewModel.clips.count
        let dur = ClipDurationFormatting.mmss(from: totalDuration)
        return "\(n) clip\(n == 1 ? "" : "s") · ~\(dur)"
    }

    private var mergeOutputCard: some View {
        SquircleCard(glassEnabled: false, glowEnabled: false) {
            VStack(alignment: .leading, spacing: SonicMergeTheme.Spacing.md) {
                Text("OUTPUT")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color(uiColor: semantic.accentAction))

                Text("Estimated merged length ~\(ClipDurationFormatting.mmss(from: totalDuration))")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))

                Button(action: onExportTap) {
                    Label("Export merged audio", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle(variant: .filled, size: .regular))
            }
        }
    }
}
