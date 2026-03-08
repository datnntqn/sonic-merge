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

    /// Convenience array for `.fileImporter(allowedContentTypes:)`.
    ///
    /// Covers:
    /// - `.wav`        — Waveform Audio (uncompressed PCM)
    /// - `.aacAudio`   — Raw Advanced Audio Coding (`public.aac-audio`)
    /// - `.mpeg4Audio` — AAC wrapped in MPEG-4 container (.m4a)
    static var audioImportTypes: [UTType] {
        [.wav, aacAudio, .mpeg4Audio]
    }
}
