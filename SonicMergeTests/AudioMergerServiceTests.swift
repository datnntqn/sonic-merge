//
//  AudioMergerServiceTests.swift
//  SonicMergeTests
//
//  Failing stubs for MRG-03 (gap duration), MRG-04 (crossfade), EXP-01 (.m4a), EXP-02 (.wav) behaviors.
//  RED state: AudioMergerService and GapTransition do not exist until later plans.
//

import Testing
import Foundation
import AVFoundation
@testable import SonicMerge

struct AudioMergerServiceTests {
    private final class BundleLocator {}

    private func fixtureURL() -> URL {
        Bundle(for: BundleLocator.self)
            .url(forResource: "stereo_48000", withExtension: "m4a")!
    }

    private func makeClip(sortOrder: Int) -> AudioClip {
        let clip = AudioClip(displayName: "clip\(sortOrder)", fileURLRelativePath: "stereo_48000.m4a", duration: 1.0)
        clip.sortOrder = sortOrder
        return clip
    }

    // MARK: - MRG-03: Silent gap

    @Test func compositionIncludesCorrectTotalDurationWithGap() async throws {
        let service = AudioMergerService()
        let clipA = makeClip(sortOrder: 0)
        let clipB = makeClip(sortOrder: 1)

        // 1.0s gap between clips → total = 1 + 1 + 1 = 3s
        let gap = GapTransition(leadingClipSortOrder: 0, gapDuration: 1.0, isCrossfade: false)

        let destURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString + ".m4a")
        var finalProgress: Float = 0
        for await p in await service.export(clips: [clipA, clipB], transitions: [gap], format: .m4a, destinationURL: destURL) {
            finalProgress = p
        }

        #expect(finalProgress == 1.0)
        let asset = AVURLAsset(url: destURL)
        let duration = try await asset.load(.duration)
        // Allow 0.2s tolerance for AAC encoder latency
        #expect(abs(duration.seconds - 3.0) < 0.2)
    }

    // MARK: - MRG-04: Crossfade

    @Test func compositionWithCrossfadeHasNonNilAudioMix() async throws {
        let service = AudioMergerService()
        let clipA = makeClip(sortOrder: 0)
        let clipB = makeClip(sortOrder: 1)
        let crossfade = GapTransition(leadingClipSortOrder: 0, gapDuration: 0, isCrossfade: true)

        let destURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString + ".m4a")
        for await _ in await service.export(clips: [clipA, clipB], transitions: [crossfade], format: .m4a, destinationURL: destURL) {}

        // Verify file exists and has audio track (crossfade rendered correctly)
        let asset = AVURLAsset(url: destURL)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        #expect(!tracks.isEmpty)
        // Crossfade reduces total duration by 0.5s overlap
        let duration = try await asset.load(.duration)
        #expect(abs(duration.seconds - 1.5) < 0.2)
    }

    // MARK: - EXP-01: .m4a export

    @Test func exportM4AProducesValidNonEmptyFile() async throws {
        let service = AudioMergerService()
        let clip = makeClip(sortOrder: 0)
        let destURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString + ".m4a")

        for await _ in await service.export(clips: [clip], transitions: [], format: .m4a, destinationURL: destURL) {}

        let attrs = try FileManager.default.attributesOfItem(atPath: destURL.path)
        let size = attrs[.size] as! Int
        #expect(size > 1000)  // at least 1KB

        let asset = AVURLAsset(url: destURL)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        #expect(!tracks.isEmpty)
    }

    // MARK: - EXP-02: .wav export

    @Test func exportWAVProducesValidNonEmptyFile() async throws {
        let service = AudioMergerService()
        let clip = makeClip(sortOrder: 0)
        let destURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString + ".wav")

        for await _ in await service.export(clips: [clip], transitions: [], format: .wav, destinationURL: destURL) {}

        let attrs = try FileManager.default.attributesOfItem(atPath: destURL.path)
        let size = attrs[.size] as! Int
        #expect(size > 1000)

        let asset = AVURLAsset(url: destURL)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        #expect(!tracks.isEmpty)
    }
}
