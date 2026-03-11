//
//  WaveformServiceTests.swift
//  SonicMergeTests
//
//  Failing stubs for IMP-04 waveform generation behaviors.
//  RED state: WaveformService does not exist until Plan 02 implements it.
//

import Testing
import Foundation
@testable import SonicMerge

struct WaveformServiceTests {
    private final class BundleLocator {}

    @Test func waveformServiceGeneratesNonEmptyPeaks() async throws {
        // Arrange
        let fixtureURL = Bundle(for: BundleLocator.self)
            .url(forResource: "stereo_48000", withExtension: "m4a")!
        let destURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString + ".waveform")
        let service = WaveformService()

        // Act
        try await service.generate(audioURL: fixtureURL, destinationURL: destURL)

        // Assert: sidecar file exists and contains Float data for 50 peaks
        let data = try Data(contentsOf: destURL)
        #expect(data.count == 50 * MemoryLayout<Float>.size)
        let peaks = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        #expect(peaks.max()! > 0)  // at least one non-zero peak
    }

    @Test func waveformServiceWritesSidecarAtDestinationURL() async throws {
        // Arrange
        let fixtureURL = Bundle(for: BundleLocator.self)
            .url(forResource: "stereo_48000", withExtension: "m4a")!
        let destURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString + ".waveform")
        let service = WaveformService()

        // Act
        try await service.generate(audioURL: fixtureURL, destinationURL: destURL)

        // Assert
        #expect(FileManager.default.fileExists(atPath: destURL.path))
    }
}
