//
//  ShareHUDModel.swift
//  SonicMergeShareExtension
//

import Foundation
import Observation

@Observable
final class ShareHUDModel {
    enum HUDState: Equatable {
        case copying
        case success
        case error
        /// Free-tier user shared an audio file longer than
        /// `AppConstants.FreeCap.smartCutMaxSeconds`. Carries the actual
        /// duration so the HUD can format `m:ss` in the subtitle copy.
        case freeLimitReached(durationSeconds: Double)
    }

    var state: HUDState = .copying
    var filename: String = ""
}
