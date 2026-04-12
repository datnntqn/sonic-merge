// MergeTimelineView.swift
// SonicMerge
//
// Vertical “conveyor”: trust strip, sequence slots with + between clips, = then output card.

import SwiftUI
import UIKit

struct MergeTimelineView: View {
    @Environment(MixingStationViewModel.self) private var viewModel
    @Environment(\.sonicMergeSemantic) private var semantic

    let onExportTap: () -> Void

    private var totalDuration: TimeInterval {
        viewModel.clips.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        List {
            Section {
                LocalFirstTrustStrip()
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SEQUENCE")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color(uiColor: semantic.accentAction))
                    Text(summarySubtitle)
                        .font(.system(.caption, design: .rounded, weight: .medium))
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
                        .padding(.vertical, 6)

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
        VStack(alignment: .leading, spacing: 14) {
            Text("OUTPUT")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(Color(uiColor: semantic.accentAction))

            Text("Estimated merged length ~\(ClipDurationFormatting.mmss(from: totalDuration))")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))

            Button(action: onExportTap) {
                Label("Export merged audio", systemImage: "square.and.arrow.up")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(Color(uiColor: semantic.surfaceBase))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(uiColor: semantic.accentAction))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: SonicMergeTheme.Radius.card, style: .continuous)
                .fill(Color(uiColor: semantic.surfaceSlot))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SonicMergeTheme.Radius.card, style: .continuous)
                .strokeBorder(Color(uiColor: semantic.accentAction).opacity(0.35), lineWidth: 1)
        )
    }
}
