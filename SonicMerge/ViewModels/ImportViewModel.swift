//
//  ImportViewModel.swift
//  SonicMerge
//
//  STUB — Plan 01 placeholder to allow ImportViewModelTests.swift to compile.
//  Replace with full implementation in Plan 04.
//

import Combine
import Foundation
import SwiftData

@MainActor
final class ImportViewModel: ObservableObject {
    @Published var clips: [AudioClip] = []
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func importFiles(from urls: [URL]) async {
        // Stub: Plan 04 implements the full import pipeline using AudioNormalizationService
    }
}
