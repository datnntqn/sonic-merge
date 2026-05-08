// SonicMerge/DesignSystem/ImportSourceDispatcher.swift
//
// Pure helper used by ImportSourceSheet to decouple "user tapped a row"
// from "host view performs the action." Tests verify dispatch routing
// without touching the SwiftUI view tree.
//

import Foundation

enum ImportSourceAction {
    case files
    case record
    case photos
}

@MainActor
struct ImportSourceDispatcher {
    let onFiles: () -> Void
    let onRecord: () -> Void
    let onPhotos: () -> Void

    func dispatch(_ action: ImportSourceAction) {
        switch action {
        case .files:  onFiles()
        case .record: onRecord()
        case .photos: onPhotos()
        }
    }
}
