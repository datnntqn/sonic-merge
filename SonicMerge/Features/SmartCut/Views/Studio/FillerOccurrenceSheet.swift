// FillerOccurrenceSheet.swift
// SonicMerge
//
// Phase 12 (Smart Cut Studio Refactor): the detail sheet that opens when
// the user taps a filler-category bento card. Glassmorphic background,
// header with word + total saves + "Disable all"/"Enable all" link,
// wrap-flow of capsule pill rows (▶ preview · excerpt · timestamp ·
// checkbox), per-row preview state for the 4-second window playback.
//
// The playWindow helper is migrated from FillerListPanel:146-167 with
// ONE deliberate extension: a previewingId reset inside the
// stop-and-clear pre-amble and inside the dispatch-after closure (drives
// the new ▶/■ icon swap). The previewPlayer === player self-comparison
// and the 33162e6 stop-in-flight-player guard are preserved intact —
// do not "improve" them during the move (the self-compare works because
// of @State value semantics; refactoring risks behavioral drift).

import SwiftUI
import AVFoundation
import UIKit

struct FillerOccurrenceSheet: View {
    let category: String
    let edits: [FillerEdit]              // occurrences for this category
    let inputURL: URL?
    let onToggleEdit: (_ id: String, _ enabled: Bool) -> Void
    let onToggleCategory: (_ enabled: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.sonicMergeSemantic) private var semantic
    @State private var previewPlayer: AVAudioPlayer?
    @State private var previewingId: String?

    private var totalSavings: TimeInterval {
        edits.filter(\.isEnabled).reduce(0) { $0 + ($1.timeRange.upperBound - $1.timeRange.lowerBound) }
    }

    private var allEnabled: Bool { edits.allSatisfy(\.isEnabled) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category)
                                .font(.title2.weight(.bold))
                            Text("\(edits.count) occurrence\(edits.count == 1 ? "" : "s") · saves \(SmartCutFormatting.formatTimestamp(totalSavings))")
                                .font(.subheadline)
                                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                        }
                        Spacer()
                        Button(allEnabled ? "Disable all" : "Enable all") {
                            onToggleCategory(!allEnabled)
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color(uiColor: semantic.accentAction).opacity(0.5))
                    }
                    .padding(.horizontal, 16)

                    // Capsule rows
                    VStack(spacing: 8) {
                        ForEach(edits) { edit in
                            occurrenceRow(edit: edit)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Occurrences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(.ultraThinMaterial)
        }
        .onDisappear {
            previewPlayer?.stop()
            previewPlayer = nil
            previewingId = nil
        }
    }

    private func occurrenceRow(edit: FillerEdit) -> some View {
        HStack(spacing: 12) {
            Button {
                playWindow(around: edit.timeRange, id: edit.id)
            } label: {
                Image(systemName: previewingId == edit.id ? "stop.fill" : "play.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: semantic.accentAction))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            Text(edit.contextExcerpt)
                .lineLimit(1)
                .font(.subheadline)
                .foregroundStyle(edit.isEnabled
                    ? Color(uiColor: semantic.textPrimary)
                    : Color(uiColor: semantic.textSecondary))
            Spacer()
            Text(SmartCutFormatting.formatTimestamp(edit.timeRange.lowerBound))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
            Button {
                onToggleEdit(edit.id, !edit.isEnabled)
            } label: {
                Image(systemName: edit.isEnabled ? "checkmark.square.fill" : "square")
                    .foregroundStyle(edit.isEnabled
                        ? Color(uiColor: semantic.accentAI)
                        : Color(uiColor: semantic.textSecondary))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .studioFrostedCapsule(cornerRadius: 14)
    }

    // MARK: - Preview playback (migrated from FillerListPanel.swift:146-167
    // with previewingId reset added)

    private func playWindow(around range: ClosedRange<TimeInterval>, id: String) {
        guard let inputURL else { return }
        // Activate the shared audio session before constructing the player.
        // Without this, on a fresh app launch where the user opens a session
        // and taps a filler-occurrence Play before any other playback has
        // happened, AVAudioPlayer.play() returns true but emits silence —
        // the session has never been activated. Idempotent (early-returns
        // after first call), so safe to call on every preview.
        PlaybackAudioSession.activateIfNeeded()
        // Stop any in-flight preview before starting a new one. AVAudioPlayer
        // keeps playing even after its @State reference is overwritten, so
        // without this a rapid re-tap (or different occurrence tap) produces
        // overlapping playback. (Migrated from 33162e6.)
        previewPlayer?.stop()
        previewPlayer = nil
        previewingId = nil
        let centerSeconds = range.lowerBound
        let windowStart = max(0, centerSeconds - 2)
        do {
            let player = try AVAudioPlayer(contentsOf: inputURL)
            player.prepareToPlay()
            player.currentTime = windowStart
            guard player.play() else { return }
            previewPlayer = player
            previewingId = id
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                if previewPlayer === player {
                    player.stop()
                    previewingId = nil
                }
            }
        } catch {
            // Surface via a non-crash channel; UI shows nothing — silent on failure.
        }
    }
}
