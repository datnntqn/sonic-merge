//
//  ShareHUDModel.swift
//  SonicMergeShareExtension
//

import Foundation
import Observation

@Observable
final class ShareHUDModel {
    enum HUDState {
        case copying
        case success
        case error
    }

    var state: HUDState = .copying
    var filename: String = ""
}
