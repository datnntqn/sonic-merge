//
//  AudioMergerService.swift
//  SonicMerge
//
//  Compilation stub — replaced by full implementation in Plan 04.
//  Exposes the API surface locked by AudioMergerServiceTests.swift (Plan 02-01).
//

import AVFoundation
import Foundation

/// Export output format.
enum ExportFormat {
    case m4a
    case wav
}

/// Stub — Plan 04 provides full implementation.
actor AudioMergerService {
    func export(
        clips: [AudioClip],
        transitions: [GapTransition],
        format: ExportFormat,
        destinationURL: URL
    ) async -> AsyncStream<Float> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
