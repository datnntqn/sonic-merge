//
//  MixingStationViewModel.swift
//  SonicMerge
//
//  Compilation stub — replaced by full implementation in Plan 03.
//  Exposes the API surface locked by MixingStationViewModelTests.swift (Plan 02-01).
//

import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class MixingStationViewModel {
    var clips: [AudioClip] = []
    var isExporting: Bool = false
    var exportedFileURL: URL?

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() async {
        // Stub — Plan 03 provides full implementation
    }

    func moveClip(fromOffsets: IndexSet, toOffset: Int) {
        // Stub — Plan 03 provides full implementation
    }

    func deleteClip(atOffsets: IndexSet) {
        // Stub — Plan 03 provides full implementation
    }

    func exportMerged(format: ExportFormat) {
        // Stub — Plan 03/04 provides full implementation
    }

    func cancelExport() {
        // Stub — Plan 03 provides full implementation
    }
}
