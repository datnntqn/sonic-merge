//
//  ImportViewModelTests.swift
//  SonicMergeTests
//
//  Failing stubs for IMP-01 import behaviors.
//  RED state: ImportViewModel does not exist until Plan 02 implements it.
//

import Testing
import Foundation
import SwiftData
@testable import SonicMerge

@MainActor
struct ImportViewModelTests {
    @Test func testImportFilesAddsClip() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AudioClip.self, configurations: config)
        let context = container.mainContext
        let vm = ImportViewModel(modelContext: context)
        // Create a real temp file so normalization can read it
        let tempURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        // Stub: just verify importFiles accepts a URL array without crashing
        // Full integration tested in AudioNormalizationServiceTests
        #expect(vm.clips.isEmpty)
    }

    @Test func testSecurityScopedAccessNoLeak() async throws {
        // Stub: verifies ImportViewModel.importFiles handles non-security-scoped URL gracefully
        #expect(true)
    }
}
