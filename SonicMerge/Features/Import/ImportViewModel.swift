//
//  ImportViewModel.swift
//  SonicMerge
//
//  @Observable ViewModel driving the import pipeline.
//  Orchestrates security-scoped access, normalization via AudioNormalizationService,
//  and SwiftData persistence for each selected audio file.
//

import Foundation
import SwiftData
import AVFoundation
import Observation

@Observable
@MainActor
final class ImportViewModel {

    private(set) var clips: [AudioClip] = []
    private(set) var isImporting: Bool = false
    private(set) var importErrors: [String] = []

    private let normalizationService = AudioNormalizationService()
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchClips()
    }

    /// Imports an array of URLs through the full normalization and persistence pipeline.
    ///
    /// - Parameter urls: Security-scoped bookmarks provided by the document picker.
    ///   Each URL is accessed, normalized to 48 kHz stereo AAC, and persisted as an
    ///   `AudioClip` in SwiftData. Files that fail are collected in `importErrors`
    ///   rather than halting processing of subsequent files.
    func importFiles(_ urls: [URL]) async {
        isImporting = true
        importErrors = []

        for url in urls {
            await processFile(url)
        }

        isImporting = false
    }

    /// Processes a single URL through the import pipeline.
    private func processFile(_ url: URL) async {
        // 1. Acquire security-scoped access (no-op for file:// URLs without scope)
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let displayName = url.deletingPathExtension().lastPathComponent

        do {
            // 2. Resolve destination in App Group clips/ directory
            let destFilename = "\(UUID().uuidString).m4a"
            let destURL = try AppConstants.clipsDirectory().appending(path: destFilename)

            // 3. Normalize: transcode source to 48 kHz stereo AAC at destURL
            //    The actor hop suspends the main actor only during transcoding;
            //    AVAssetWriter's requestMediaDataWhenReady runs on a background DispatchQueue.
            //    See RESEARCH.md Pitfall 4: this pattern is safe and recommended.
            try await normalizationService.normalize(sourceURL: url, destinationURL: destURL)

            // 4. Read output duration from normalized file
            let asset = AVURLAsset(url: destURL)
            let duration = try await asset.load(.duration).seconds

            // 5. Persist AudioClip on main actor (ModelContext is main-actor bound)
            let clip = AudioClip(
                displayName: displayName,
                fileURLRelativePath: destFilename,
                duration: duration
            )
            clip.sortOrder = clips.count
            modelContext.insert(clip)
            try modelContext.save()

            fetchClips()

        } catch {
            importErrors.append("\(displayName): \(error.localizedDescription)")
        }
    }

    /// Refreshes the in-memory clips array from SwiftData.
    func fetchClips() {
        do {
            let descriptor = FetchDescriptor<AudioClip>(
                sortBy: [SortDescriptor(\.sortOrder)]
            )
            clips = try modelContext.fetch(descriptor)
        } catch {
            clips = []
        }
    }

    /// Surfaces a document picker error in the importErrors array.
    func handlePickerError(_ error: Error) {
        importErrors = ["Picker error: \(error.localizedDescription)"]
    }
}
