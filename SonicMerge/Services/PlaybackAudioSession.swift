//
//  PlaybackAudioSession.swift
//  SonicMerge
//
//  Lazily activates AVAudioSession so cold launch does not touch Core Audio on the Simulator
//  (reduces noisy "AddInstanceForFactory" logs until the user actually plays audio).
//

import AVFAudio

enum PlaybackAudioSession {
    private static var didActivate = false

    /// Call from `@MainActor` before the first `AVAudioPlayer.play()` in a session.
    static func activateIfNeeded() {
        guard !didActivate else { return }
        didActivate = true
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            didActivate = false
            #if DEBUG
            print("[PlaybackAudioSession] activation failed: \(error)")
            #endif
        }
    }
}
