// MixingStationViewModel.swift
// SonicMerge
//
// Primary ViewModel for the Mixing Station — the app's root screen.
//
// Orchestrates clip import (normalization + waveform generation), reorder,
// delete, GapTransition management, and export. Mirrors the @Observable @MainActor
// pattern established by ImportViewModel in Phase 1.
//
// AudioNormalizationService, WaveformService, and AudioMergerService are all
// plain actors — actor hops from @MainActor are safe (no Sendable violations).

import Foundation
import SwiftUI
import SwiftData
import Observation
import AVFoundation

/// Primary ViewModel for the Mixing Station — the app's root screen.
///
/// Orchestrates clip import (normalization + waveform generation), reorder,
/// delete, GapTransition management, and export. Mirrors the @Observable @MainActor
/// pattern established by ImportViewModel in Phase 1.
///
/// AudioNormalizationService, WaveformService, and AudioMergerService are all
/// plain actors — actor hops from @MainActor are safe (no Sendable violations).
@Observable
@MainActor
final class MixingStationViewModel {

    // MARK: - Published State

    private(set) var clips: [AudioClip] = []
    private(set) var transitions: [GapTransition] = []
    private(set) var isImporting = false
    private(set) var isExporting = false
    private(set) var exportProgress: Float = 0
    private(set) var exportedFileURL: URL? = nil
    private(set) var showShareSheet = false
    private(set) var isNormalizingExport: Bool = false
    var importErrors: [String] = []

    /// Set while a clip preview is actively playing (`AVAudioPlayer`).
    private(set) var previewingClipID: UUID?

    // MARK: - Private

    private let modelContext: ModelContext
    private let normalizationService = AudioNormalizationService()
    private let waveformService = WaveformService()
    private let mergerService = AudioMergerService()
    private var exportTask: Task<Void, Never>?
    private var previewPlayer: AVAudioPlayer?

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Fetch

    /// Loads AudioClips sorted by sortOrder and all GapTransitions from SwiftData.
    /// Declared async so callers (including tests) can await it before exercising state.
    func fetchAll() async {
        let clipDescriptor = FetchDescriptor<AudioClip>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        clips = (try? modelContext.fetch(clipDescriptor)) ?? []

        let transitionDescriptor = FetchDescriptor<GapTransition>()
        transitions = (try? modelContext.fetch(transitionDescriptor)) ?? []
    }

    // MARK: - Import

    func importFiles(_ urls: [URL]) {
        stopClipPreview()
        isImporting = true
        importErrors = []
        Task {
            await performImport(urls: urls)
            await fetchAll()
            isImporting = false
        }
    }

    /// Returns true if any currently-loaded clip has the given displayName.
    ///
    /// Extracted as a public helper so tests can directly verify duplicate detection
    /// without going through the full security-scoped import pathway.
    func isDisplayNameDuplicate(_ name: String) -> Bool {
        clips.contains { $0.displayName == name }
    }

    private func performImport(urls: [URL]) async {
        let clipsDir: URL
        do { clipsDir = try AppConstants.clipsDirectory() } catch {
            importErrors.append("App Group container not available.")
            return
        }

        var newClips: [AudioClip] = []

        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            // D-10 / D-11: Deduplicate by displayName before normalization.
            // Check both persisted clips AND clips being imported in the current batch.
            let displayName = url.deletingPathExtension().lastPathComponent
            let isDuplicate = isDisplayNameDuplicate(displayName) ||
                              newClips.contains { $0.displayName == displayName }
            guard !isDuplicate else { continue }

            let filename = UUID().uuidString + ".m4a"
            let destURL = clipsDir.appending(path: filename)

            do {
                try await normalizationService.normalize(sourceURL: url, destinationURL: destURL)

                // Generate waveform sidecar immediately after normalization
                let stem = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
                let waveformDest = clipsDir.appending(path: stem + ".waveform")
                try? await waveformService.generate(audioURL: destURL, destinationURL: waveformDest)

                // Measure duration of normalized file
                let asset = AVURLAsset(url: destURL)
                let duration = (try? await asset.load(.duration))?.seconds ?? 0

                let clip = AudioClip(
                    displayName: displayName,
                    fileURLRelativePath: filename,
                    duration: duration
                )
                clip.sortOrder = (clips.count + newClips.count)
                modelContext.insert(clip)
                newClips.append(clip)
            } catch {
                importErrors.append("Failed to import \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        // Save new clips, refresh state, then create GapTransitions for all but the last clip
        try? modelContext.save()
        await fetchAll()

        // Create gap transitions for new clips except the very last overall clip
        let allSorted = clips.sorted(by: { $0.sortOrder < $1.sortOrder })
        for clip in allSorted.dropLast() {
            if clip.gapTransition == nil {
                let gap = GapTransition(leadingClipSortOrder: clip.sortOrder)
                gap.audioClip = clip
                modelContext.insert(gap)
            }
        }
        try? modelContext.save()
    }

    // MARK: - Reorder (MRG-01)

    func moveClip(fromOffsets: IndexSet, toOffset: Int) {
        clips.move(fromOffsets: fromOffsets, toOffset: toOffset)
        // Reassign contiguous sortOrder after move
        for (index, clip) in clips.enumerated() {
            clip.sortOrder = index
        }
        // Re-sync leadingClipSortOrder on all transitions
        for clip in clips {
            clip.gapTransition?.leadingClipSortOrder = clip.sortOrder
        }
        try? modelContext.save()
    }

    // MARK: - Delete (MRG-02)

    func deleteClip(atOffsets offsets: IndexSet) {
        let toDelete = offsets.map { clips[$0] }
        if toDelete.contains(where: { $0.id == previewingClipID }) {
            stopClipPreview()
        }
        for clip in toDelete {
            // Delete gap transition
            if let gap = clip.gapTransition {
                modelContext.delete(gap)
            }
            // Delete audio and sidecar files from disk
            if let audioURL = try? clip.fileURL {
                try? FileManager.default.removeItem(at: audioURL)
            }
            if let waveformURL = clip.waveformSidecarURL {
                try? FileManager.default.removeItem(at: waveformURL)
            }
            modelContext.delete(clip)
        }
        try? modelContext.save()

        // Refresh and reassign contiguous sortOrder after deletion (Pitfall 5)
        let clipDescriptor = FetchDescriptor<AudioClip>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        clips = (try? modelContext.fetch(clipDescriptor)) ?? []
        let transitionDescriptor = FetchDescriptor<GapTransition>()
        transitions = (try? modelContext.fetch(transitionDescriptor)) ?? []

        for (index, clip) in clips.enumerated() {
            clip.sortOrder = index
            clip.gapTransition?.leadingClipSortOrder = index
        }
        // Ensure last clip has no gap transition
        if let lastClip = clips.last, let gap = lastClip.gapTransition {
            modelContext.delete(gap)
        }
        try? modelContext.save()

        // Final refresh
        clips = (try? modelContext.fetch(FetchDescriptor<AudioClip>(
            sortBy: [SortDescriptor(\.sortOrder)]
        ))) ?? []
        transitions = (try? modelContext.fetch(FetchDescriptor<GapTransition>())) ?? []
    }

    /// Deletes a single clip by stable id (avoids index mismatch with List/Section layouts).
    func deleteClip(id: UUID) {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        deleteClip(atOffsets: IndexSet(integer: index))
    }

    // MARK: - Gap/Crossfade Update

    func updateTransition(_ transition: GapTransition, gapDuration: Double? = nil, isCrossfade: Bool? = nil) {
        if let d = gapDuration { transition.gapDuration = d }
        if let cf = isCrossfade { transition.isCrossfade = cf }
        try? modelContext.save()
    }

    // MARK: - Export (EXP-01, EXP-02, EXP-04)

    func exportMerged(options: ExportOptions) {
        guard !clips.isEmpty else { return }
        stopClipPreview()
        isExporting = true
        exportProgress = 0
        exportedFileURL = nil
        isNormalizingExport = options.lufsNormalize

        let format = options.format
        let ext = format == .m4a ? "m4a" : "wav"
        let destURL = FileManager.default.temporaryDirectory
            .appending(path: "SonicMerge-Export-\(UUID().uuidString).\(ext)")

        exportTask = Task {
            let stream = await mergerService.export(
                clips: clips.sorted(by: { $0.sortOrder < $1.sortOrder }),
                transitions: transitions,
                format: format,
                destinationURL: destURL,
                lufsNormalize: options.lufsNormalize
            )
            for await progress in stream {
                guard !Task.isCancelled else { break }
                exportProgress = progress
            }
            if !Task.isCancelled {
                exportedFileURL = destURL
                showShareSheet = true
            }
            isExporting = false
            isNormalizingExport = false
        }
    }

    func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        // Clean up any partial export files in temp directory (Pitfall 8)
        let tempDir = FileManager.default.temporaryDirectory
        if let items = try? FileManager.default.contentsOfDirectory(
            at: tempDir, includingPropertiesForKeys: nil
        ) {
            for item in items where item.lastPathComponent.hasPrefix("SonicMerge-Export-") {
                try? FileManager.default.removeItem(at: item)
            }
        }
        exportedFileURL = nil
        exportProgress = 0
        isExporting = false
    }

    func dismissShareSheet() {
        showShareSheet = false
        exportedFileURL = nil
        exportProgress = 0   // FIX: was missing — testDismissShareSheetResetsState now GREEN
    }

    // MARK: - Clip preview

    func toggleClipPreview(_ clip: AudioClip) {
        if previewingClipID == clip.id {
            stopClipPreview()
            return
        }
        stopClipPreview()
        guard let url = try? clip.fileURL else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            guard player.play() else { return }
            previewPlayer = player
            previewingClipID = clip.id
        } catch {
            previewPlayer = nil
            previewingClipID = nil
        }
    }

    func stopClipPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
        previewingClipID = nil
    }
}
