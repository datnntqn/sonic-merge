//
//  ShareExtensionTests.swift
//  SonicMergeTests
//
//  Wave 0 failing stubs for Share Extension behaviors (IMP-02).
//  RED state: tests fail intentionally — implementation added in Plan 05-01 Tasks 1 & 2.
//

import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct ShareExtensionTests {

    // MARK: - IMP-02: File copy into App Group container

    @Test func testFileCopyToClipsDirectory() async throws {
        // Stub: Verify that a file placed in clipsDirectory() is accessible
        // Will be implemented when ShareExtensionViewController file-copy logic
        // is extracted into a testable helper.
        #expect(Bool(false), "STUB — not yet implemented")
    }

    // MARK: - IMP-02: Large file copy does not OOM

    @Test func testLargeFileCopyDoesNotCrash() async throws {
        // Stub: Verify that copying a large file (~1 MB synthetic fixture)
        // to clipsDirectory completes without error.
        // Validates the loadFileRepresentation pathway (not loadDataRepresentation).
        #expect(Bool(false), "STUB — not yet implemented")
    }

    // MARK: - IMP-02: Pending key written and cleared

    @Test func testPendingKeyWrittenAndCleared() async throws {
        // Stub: Write pendingImportFilename to App Group UserDefaults,
        // verify it can be read, then clear it and verify removal.
        #expect(Bool(false), "STUB — not yet implemented")
    }
}
