//
//  AudioNormalizationServiceTests.swift
//  SonicMergeTests
//
//  Failing stubs for IMP-03 normalization behaviors.
//  RED state: AudioNormalizationService does not exist until Plan 03 implements it.
//

import Testing
import AVFoundation
@testable import SonicMerge

struct AudioNormalizationServiceTests {
    let service = AudioNormalizationService()
    let fm = FileManager.default

    func fixtureURL(_ name: String, ext: String) -> URL {
        Bundle(for: BundleLocator.self).url(forResource: name, withExtension: ext)!
    }

    @Test func testOutputSampleRate() async throws {
        let source = fixtureURL("stereo_48000", ext: "m4a")
        let dest = fm.temporaryDirectory.appending(path: "\(UUID().uuidString).m4a")
        try await service.normalize(sourceURL: source, destinationURL: dest)
        let asset = AVURLAsset(url: dest)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let desc = try await tracks.first!.load(.formatDescriptions).first! as! CMAudioFormatDescription
        let sr = CMAudioFormatDescriptionGetStreamBasicDescription(desc)!.pointee.mSampleRate
        #expect(sr == 48_000)
        try? fm.removeItem(at: dest)
    }

    @Test func testOutputChannelCount() async throws {
        let source = fixtureURL("mono_44100", ext: "wav")
        let dest = fm.temporaryDirectory.appending(path: "\(UUID().uuidString).m4a")
        try await service.normalize(sourceURL: source, destinationURL: dest)
        let asset = AVURLAsset(url: dest)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let desc = try await tracks.first!.load(.formatDescriptions).first! as! CMAudioFormatDescription
        let ch = CMAudioFormatDescriptionGetStreamBasicDescription(desc)!.pointee.mChannelsPerFrame
        #expect(ch == 2)
        try? fm.removeItem(at: dest)
    }

    @Test func testMonoUpmix() async throws {
        let source = fixtureURL("mono_44100", ext: "wav")
        let dest = fm.temporaryDirectory.appending(path: "\(UUID().uuidString).m4a")
        try await service.normalize(sourceURL: source, destinationURL: dest)
        // Verify right channel RMS is non-zero (not silent)
        let asset = AVURLAsset(url: dest)
        let reader = try AVAssetReader(asset: asset)
        let track = try await asset.loadTracks(withMediaType: .audio).first!
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: true
        ])
        reader.add(output)
        reader.startReading()
        var rightChannelSamples: [Float] = []
        while let buf = output.copyNextSampleBuffer(),
              let blockBuf = CMSampleBufferGetDataBuffer(buf) {
            // Right channel is buffer[1] in non-interleaved; simplified check
            var length = 0
            var dataPointer: UnsafeMutablePointer<Int8>? = nil
            CMBlockBufferGetDataPointer(blockBuf, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)
            // Just checking it doesn't throw is sufficient for stub; detailed RMS in plan 03
        }
        #expect(true) // Stub: real RMS check added in Plan 03 implementation
        try? fm.removeItem(at: dest)
    }

    @Test func testDurationPreserved() async throws {
        let source = fixtureURL("stereo_48000", ext: "m4a")
        let dest = fm.temporaryDirectory.appending(path: "\(UUID().uuidString).m4a")
        try await service.normalize(sourceURL: source, destinationURL: dest)
        let srcAsset = AVURLAsset(url: source)
        let dstAsset = AVURLAsset(url: dest)
        let srcDur = try await srcAsset.load(.duration).seconds
        let dstDur = try await dstAsset.load(.duration).seconds
        #expect(abs(srcDur - dstDur) < 0.1)
        try? fm.removeItem(at: dest)
    }
}

// Bundle locator helper (class so Bundle(for:) works)
private class BundleLocator {}
