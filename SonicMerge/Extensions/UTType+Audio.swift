//
//  UTType+Audio.swift
//  SonicMerge
//
//  Created by DATNNT on 8/3/26.
//

import UniformTypeIdentifiers

extension UTType {
    /// Raw AAC audio (`public.aac-audio`).
    ///
    /// `UTType.aac` does not exist as a static member on all SDK versions.
    /// This private constant resolves the identifier directly.
    private static let aacAudio = UTType("public.aac-audio")!

    /// Apple Core Audio Format (`com.apple.coreaudio-format`, .caf).
    /// No static member; resolved by identifier.
    private static let coreAudio = UTType("com.apple.coreaudio-format")!

    /// Convenience array for `.fileImporter(allowedContentTypes:)`.
    ///
    /// Covers every audio container AVAsset decodes natively on iOS 17+:
    /// - `.wav`        — Waveform Audio (uncompressed PCM)
    /// - `.aacAudio`   — Raw Advanced Audio Coding (`public.aac-audio`)
    /// - `.mpeg4Audio` — AAC wrapped in MPEG-4 container (.m4a)
    /// - `.mp3`        — MPEG-1 Audio Layer III
    /// - `.aiff`       — Audio Interchange File Format
    /// - `.coreAudio`  — Apple Core Audio Format (.caf)
    static var audioImportTypes: [UTType] {
        [.wav, aacAudio, .mpeg4Audio, .mp3, .aiff, coreAudio]
    }

    /// Broader type list for SwiftUI `.onDrop` so drag-from-Finder / Files matches common audio payloads.
    static var audioDropTypes: [UTType] {
        var list: [UTType] = [.audio, .mp3]
        for t in audioImportTypes where !list.contains(where: { $0.identifier == t.identifier }) {
            list.append(t)
        }
        return list
    }
}
