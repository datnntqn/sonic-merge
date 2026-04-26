//
//  SourceHasherTests.swift
//  SonicMergeTests
//
//  TDD tests for SourceHasher (Smart Cut Plan, task sc-t1).
//  RED phase: SourceHasher does not exist yet.
//
//  Covers:
//    1. Known content ("hello world") produces the canonical SHA256 hex digest.
//    2. Two distinct files with identical bytes produce identical hashes.
//    3. Hashing a missing file throws.
//

import Testing
import Foundation
@testable import SonicMerge

struct SourceHasherTests {

    @Test func testKnownContentProducesKnownHash() async throws {
        let bytes = Data("hello world".utf8)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hasher-known-\(UUID().uuidString).bin")
        try bytes.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let hash = try await SourceHasher.sha256Hex(of: url)
        // sha256("hello world") = b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9
        #expect(hash == "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9")
    }

    @Test func testIdenticalContentInDifferentFilesProducesSameHash() async throws {
        let bytes = Data(repeating: 0x42, count: 100_000)
        let url1 = FileManager.default.temporaryDirectory
            .appendingPathComponent("hasher-a-\(UUID().uuidString).bin")
        let url2 = FileManager.default.temporaryDirectory
            .appendingPathComponent("hasher-b-\(UUID().uuidString).bin")
        try bytes.write(to: url1)
        try bytes.write(to: url2)
        defer {
            try? FileManager.default.removeItem(at: url1)
            try? FileManager.default.removeItem(at: url2)
        }

        let h1 = try await SourceHasher.sha256Hex(of: url1)
        let h2 = try await SourceHasher.sha256Hex(of: url2)
        #expect(h1 == h2)
    }

    @Test func testMissingFileThrows() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).bin")
        await #expect(throws: (any Error).self) {
            _ = try await SourceHasher.sha256Hex(of: url)
        }
    }
}
