//
//  AudioClip.swift
//  SonicMerge
//
//  Created by DATNNT on 8/3/26.
//

import Foundation
import SwiftData

/// SwiftData model representing an imported audio clip.
///
/// `fileURLRelativePath` stores only the filename component (e.g. "A1B2C3.m4a").
/// The absolute URL is reconstructed at runtime via `AppConstants.clipsDirectory()`.
/// This avoids persisting device-specific App Group container paths that can shift
/// between simulator restarts and real-device provisioning.
@Model
final class AudioClip {
    var id: UUID
    var displayName: String

    /// Filename-only component. Reconstruct absolute URL via:
    /// `try AppConstants.clipsDirectory().appending(path: fileURLRelativePath)`
    var fileURLRelativePath: String

    var duration: TimeInterval

    /// Always 48,000 Hz after normalization.
    var sampleRate: Double

    /// Always 2 (stereo) after normalization. Mono inputs are upmixed.
    var channelCount: Int

    var importedAt: Date
    var sortOrder: Int

    init(displayName: String, fileURLRelativePath: String, duration: TimeInterval) {
        self.id = UUID()
        self.displayName = displayName
        self.fileURLRelativePath = fileURLRelativePath
        self.duration = duration
        self.sampleRate = 48_000
        self.channelCount = 2
        self.importedAt = .now
        self.sortOrder = 0
    }

    /// Convenience initialiser that accepts a full URL and extracts the last path component.
    /// Used by tests and callers that already have an absolute URL.
    convenience init(displayName: String, fileURL: URL, duration: TimeInterval) {
        self.init(
            displayName: displayName,
            fileURLRelativePath: fileURL.lastPathComponent,
            duration: duration
        )
    }

    /// Computed absolute URL — not stored in SwiftData (reconstructed at runtime).
    var fileURL: URL {
        get throws {
            try AppConstants.clipsDirectory().appending(path: fileURLRelativePath)
        }
    }
}
