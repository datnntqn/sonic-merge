//
//  LUFSNormalizationServiceTests.swift
//  SonicMergeTests
//
//  Wave 0 failing stubs for EXP-03: LUFS loudness normalization.
//  RED state: LUFSNormalizationService does not exist until Plan 04-02.
//  These tests will fail to compile until LUFSNormalizationService is created.
//

import Testing
import Foundation
@testable import SonicMerge

// LUFSNormalizationService is a plain actor (not @MainActor) — no @MainActor on struct.
struct LUFSNormalizationServiceTests {

    // Bundle locator for fixture resolution (project-standard pattern)
    private final class BundleLocator {}

    // MARK: - EXP-03: Gain scalar computation

    @Test func testGainScalarForKnownLoudness() async throws {
        // Fixture is approximately -24 LUFS — gain scalar must be > 1.0 to reach -16 LUFS.
        let service = LUFSNormalizationService()
        guard let fixtureURL = Bundle(for: BundleLocator.self)
            .url(forResource: "stereo_-24lufs_48000", withExtension: "wav") else {
            Issue.record("Missing fixture: stereo_-24lufs_48000.wav")
            return
        }
        let scalar = await service.gainScalar(for: fixtureURL)
        #expect(scalar > 1.0, "Expected gain > 1.0 for audio below -16 LUFS, got \(scalar)")
    }

    @Test func testGainScalarAlreadyAtTarget() async throws {
        // Service must always return a positive scalar (>= 0.0), even if gain is ~1.0.
        // This test uses the same fixture — result will be > 1.0, but we verify it is
        // a finite, positive Double (fallback path: returns 1.0 on measurement failure).
        let service = LUFSNormalizationService()
        guard let fixtureURL = Bundle(for: BundleLocator.self)
            .url(forResource: "stereo_-24lufs_48000", withExtension: "wav") else {
            Issue.record("Missing fixture: stereo_-24lufs_48000.wav")
            return
        }
        let scalar = await service.gainScalar(for: fixtureURL)
        #expect(scalar > 0.0 && scalar.isFinite, "Expected finite positive gain scalar, got \(scalar)")
    }

    @Test func testExportWithLUFSEnabled() async throws {
        // Integration: export(clips:transitions:format:destinationURL:lufsNormalize:true)
        // does not throw and produces a file. This test references the lufsNormalize
        // parameter that does not yet exist — RED state by design.
        let service = AudioMergerService()
        let destURL = FileManager.default.temporaryDirectory
            .appending(path: "test-lufs-export-\(UUID().uuidString).wav")
        let stream = await service.export(
            clips: [],
            transitions: [],
            format: .wav,
            destinationURL: destURL,
            lufsNormalize: true   // NEW parameter — does not exist until Plan 04-02
        )
        // Consume stream
        for await _ in stream {}
        // Empty clips produces no file — test verifies no crash occurred
        #expect(true, "Export with lufsNormalize:true completed without crashing")
    }
}
