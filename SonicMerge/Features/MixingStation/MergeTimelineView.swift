// MergeTimelineView.swift
// SonicMerge
//
// Vertical "conveyor": trust strip, sequence header, clip column with junctions,
// equals operator, output card. Phase 10: List → ScrollView { LazyVStack } so the
// 3-line reorder handles disappear; reorder is now via .draggable + .dropDestination.
// See docs/superpowers/specs/2026-04-24-main-screen-continuous-stream-design.md
// (D-08). Wave 8 adds D-05 "Insert clip here" via a pendingInsert async gate.

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MergeTimelineView: View {
    @Environment(MixingStationViewModel.self) private var viewModel
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Phase 10 D-06: shared with MixingStationView via @AppStorage. Once the user
    /// has imported a clip, this flips to true permanently and the trust banner is
    /// hidden on every subsequent launch.
    @AppStorage("sonicMerge.hasImportedFirstClip") private var hasImportedFirstClip: Bool = false

    /// Phase 10 Wave-8 (D-05 / R-03): captures (target index, clips.count at the
    /// time of the junction tap) so the .onChange(of: viewModel.clips.count)
    /// observer can move newly-imported tail clips into the right slot. Cleared
    /// after the reorder fires, on cancel, or on a delta <= 0 import result.
    @State private var pendingInsert: (index: Int, oldCount: Int)?
    @State private var showInsertPicker: Bool = false

    let onExportTap: () -> Void

    private var totalDuration: TimeInterval {
        viewModel.clips.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !hasImportedFirstClip {
                    LocalFirstTrustStrip()
                        .padding(.horizontal, 16)
                        .padding(.vertical, SonicMergeTheme.Spacing.sm)
                }

                sequenceHeader
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)

                ForEach(Array(viewModel.clips.enumerated()), id: \.element.id) { index, clip in
                    clipRow(index: index, clip: clip)
                }
                .animation(
                    reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78),
                    value: viewModel.clips.map(\.id)
                )

                MergeOperatorLabel(kind: .equals)
                    .padding(.horizontal, 16)
                    .padding(.top, SonicMergeTheme.Spacing.sm)
                    .padding(.bottom, 4)

                mergeOutputCard
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 20)
            }
        }
        .background(Color(uiColor: semantic.surfaceBase))
        .fileImporter(
            isPresented: $showInsertPicker,
            allowedContentTypes: UTType.audioImportTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.importFiles(urls)
            case .failure:
                // User cancelled or an error fired before any clip was added.
                // Drop the pending gate so a later toolbar import can't be
                // mis-attributed to this junction tap.
                pendingInsert = nil
            }
        }
        .onChange(of: viewModel.clips.count) { _, newCount in
            guard let pending = pendingInsert else { return }
            let delta = newCount - pending.oldCount
            guard delta > 0 else {
                // Cancel, all-duplicates skip, or unrelated decrease — abandon.
                pendingInsert = nil
                return
            }
            // Newly-imported clips occupy the tail positions [oldCount ..< newCount].
            // Move them as a batch to the requested junction position.
            let tail = pending.oldCount ..< newCount
            viewModel.moveClip(fromOffsets: IndexSet(tail), toOffset: pending.index)
            pendingInsert = nil
        }
    }

    // MARK: - Subviews

    private var sequenceHeader: some View {
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
        .padding(.vertical, SonicMergeTheme.Spacing.sm)
    }

    private func clipRow(index: Int, clip: AudioClip) -> some View {
        VStack(spacing: 0) {
            MergeSlotRow(
                clip: clip,
                isPreviewing: viewModel.previewingClipID == clip.id,
                onPreviewTap: { viewModel.toggleClipPreview(clip) },
                onDelete: { viewModel.deleteClip(id: clip.id) }
            )
            // Phase 10: 6pt vertical so card↔junction gap totals 12pt
            // (6pt below card + 6pt above junction).
            .padding(.vertical, 6)
            // .draggable / .dropDestination scoped to ONLY the card so the
            // junction below isn't draggable and isn't a drop target — both
            // would produce confusing reorder behavior.
            // UUID isn't Transferable by default; the uuidString is the drag
            // payload, decoded back via UUID(uuidString:) in handleDrop.
            .draggable(clip.id.uuidString)
            .dropDestination(for: String.self) { droppedIDStrings, _ in
                handleDrop(droppedIDStrings: droppedIDStrings, ontoIndex: index)
            }
            .accessibilityActions {
                // SwiftUI moveClip uses "insert before this offset" semantics,
                // so moving down from index `i` targets `i + 2` (not `i + 1`).
                if index > 0 {
                    Button("Move up") {
                        viewModel.moveClip(fromOffsets: IndexSet([index]), toOffset: index - 1)
                    }
                }
                if index < viewModel.clips.count - 1 {
                    Button("Move down") {
                        viewModel.moveClip(fromOffsets: IndexSet([index]), toOffset: index + 2)
                    }
                }
            }

            if index < viewModel.clips.count - 1,
               let transition = clip.gapTransition {
                JunctionView(
                    transition: transition,
                    onTransitionChange: { gapDuration, isCrossfade in
                        viewModel.updateTransition(
                            transition,
                            gapDuration: gapDuration,
                            isCrossfade: isCrossfade
                        )
                    },
                    onInsertClip: {
                        // Junction at row index `index` sits AFTER clip[index]
                        // and BEFORE clip[index + 1]. Insert target is therefore
                        // position index + 1 (uses moveClip's "insert before
                        // this offset" semantic).
                        pendingInsert = (index: index + 1, oldCount: viewModel.clips.count)
                        showInsertPicker = true
                    }
                )
                .padding(.vertical, 6)
            }
        }
        .background(alignment: .leading) {
            // Phase 7 MIX-02 / Phase 10: central connecting line. Hidden when
            // only one clip exists.
            if viewModel.clips.count >= 2 {
                TimelineSpineView()
            }
        }
        .padding(.horizontal, 16)
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

    // MARK: - Reorder Helpers

    /// Computes the moveClip toOffset based on the drop's destination row.
    /// Returns true if a reorder was performed, false if the drop was a no-op
    /// (drop onto self, or the dragged ID is no longer in the collection).
    @discardableResult
    private func handleDrop(droppedIDStrings: [String], ontoIndex destIndex: Int) -> Bool {
        guard let droppedString = droppedIDStrings.first,
              let droppedID = UUID(uuidString: droppedString),
              let from = viewModel.clips.firstIndex(where: { $0.id == droppedID }),
              from != destIndex
        else { return false }

        // SwiftUI moveClip uses "insert before this offset" semantics:
        //   - moving DOWN (from < destIndex): toOffset = destIndex + 1
        //   - moving UP   (from > destIndex): toOffset = destIndex
        let toOffset = from < destIndex ? destIndex + 1 : destIndex
        viewModel.moveClip(fromOffsets: IndexSet([from]), toOffset: toOffset)
        return true
    }

    private var summarySubtitle: String {
        let n = viewModel.clips.count
        let dur = ClipDurationFormatting.mmss(from: totalDuration)
        return "\(n) clip\(n == 1 ? "" : "s") · ~\(dur)"
    }
}
