//
//  GapTransition.swift
//  SonicMerge
//
//  Created by DATNNT on 11/3/26.
//

import Foundation
import SwiftData

/// Persists the gap or crossfade configuration that follows a specific AudioClip.
///
/// One GapTransition exists per inter-clip boundary (after each clip except the last).
/// The relationship is 1-to-1 with AudioClip via the `audioClip` inverse.
///
/// Both sides of the relationship are optional to satisfy SwiftData's bootstrapping
/// constraint — see RESEARCH.md Pitfall 4.
@Model
final class GapTransition {
    /// The `sortOrder` of the AudioClip that PRECEDES this transition.
    /// Used by AudioMergerService to look up which transition follows which clip.
    var leadingClipSortOrder: Int

    /// Silence duration in seconds. One of: 0, 0.5, 1.0, or 2.0.
    /// 0 = no gap (clips play back-to-back, hard cut).
    /// Ignored when `isCrossfade` is true.
    var gapDuration: Double

    /// When true, apply a 0.5s crossfade (fade-out on the preceding clip,
    /// fade-in on the following clip). Mutually exclusive with silence gap.
    var isCrossfade: Bool

    /// The AudioClip that precedes this transition. Optional per SwiftData requirement
    /// for 1-to-1 relationships (both sides must be optional).
    @Relationship(deleteRule: .nullify, inverse: \AudioClip.gapTransition)
    var audioClip: AudioClip?

    init(leadingClipSortOrder: Int, gapDuration: Double = 0.5, isCrossfade: Bool = false) {
        self.leadingClipSortOrder = leadingClipSortOrder
        self.gapDuration = gapDuration
        self.isCrossfade = isCrossfade
    }
}
