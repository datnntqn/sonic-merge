// SonicMerge/Features/Recording/RecordPermissionProvider.swift
//
// DI seam over AVAudioApplication's mic-permission request. Production
// uses `SystemRecordPermissionProvider()`; tests pass a stub that
// returns a fixed grant/deny result.
//

import AVFoundation

protocol RecordPermissionProvider: Sendable {
    /// Returns `true` if the user grants microphone access (or has previously
    /// granted it). `false` if denied.
    func request() async -> Bool
}

struct SystemRecordPermissionProvider: RecordPermissionProvider {
    func request() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
