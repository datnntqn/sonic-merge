// MixingStationClipIndexResolver.swift
// SonicMerge

import Foundation

enum MixingStationClipIndexResolver {
    /// Maps a stable clip id to a list index for the current ordered `clips` array.
    static func index(for clipID: UUID, in clips: [AudioClip]) -> Int? {
        clips.firstIndex { $0.id == clipID }
    }
}
