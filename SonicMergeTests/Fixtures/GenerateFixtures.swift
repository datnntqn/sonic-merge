#!/usr/bin/env swift
// GenerateFixtures.swift
// One-time utility to generate binary audio fixture files for SonicMergeTests.
// This file is NOT part of the SonicMergeTests target.
// Run once from repo root: swift SonicMergeTests/Fixtures/GenerateFixtures.swift

import AVFoundation
import Foundation

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()

// MARK: - Generate WAV (PCM Float32, non-interleaved)

func generateWAV(outputURL: URL, sampleRate: Double, channelCount: AVAudioChannelCount, durationSeconds: Double = 1.0) throws {
    let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: sampleRate,
        channels: channelCount,
        interleaved: false
    )!
    let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
    buffer.frameLength = frameCount

    let frequency: Double = 440.0
    for ch in 0..<Int(channelCount) {
        let data = buffer.floatChannelData![ch]
        for i in 0..<Int(frameCount) {
            data[i] = Float(0.5 * sin(2.0 * .pi * frequency * Double(i) / sampleRate))
        }
    }

    let wavSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: sampleRate,
        AVNumberOfChannelsKey: channelCount,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsFloatKey: false
    ]

    let file = try AVAudioFile(forWriting: outputURL, settings: wavSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
    try file.write(from: buffer)
    print("Written: \(outputURL.lastPathComponent) (\(Int(sampleRate)) Hz, \(channelCount)ch, WAV)")
}

// MARK: - Generate M4A/AAC

func generateM4A(outputURL: URL, sampleRate: Double, channelCount: AVAudioChannelCount, durationSeconds: Double = 1.0) throws {
    // Build PCM buffer
    let pcmFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: sampleRate,
        channels: channelCount,
        interleaved: false
    )!
    let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
    let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: frameCount)!
    buffer.frameLength = frameCount

    let frequency: Double = 440.0
    for ch in 0..<Int(channelCount) {
        let data = buffer.floatChannelData![ch]
        for i in 0..<Int(frameCount) {
            data[i] = Float(0.3 * sin(2.0 * .pi * frequency * Double(i) / sampleRate))
        }
    }

    // Write to temporary WAV file
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: tempURL) }

    let wavSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: sampleRate,
        AVNumberOfChannelsKey: channelCount,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsFloatKey: false
    ]
    let wavFile = try AVAudioFile(forWriting: tempURL, settings: wavSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
    try wavFile.write(from: buffer)

    // Export WAV -> AAC M4A
    let asset = AVURLAsset(url: tempURL)
    guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
        throw NSError(domain: "GenerateFixtures", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create export session"])
    }
    session.outputURL = outputURL
    session.outputFileType = .m4a

    let group = DispatchGroup()
    group.enter()
    session.exportAsynchronously {
        group.leave()
    }
    group.wait()

    if session.status != .completed {
        throw session.error ?? NSError(domain: "GenerateFixtures", code: 2, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
    }
    print("Written: \(outputURL.lastPathComponent) (\(Int(sampleRate)) Hz, \(channelCount)ch)")
}

// MARK: - Main

// 1. mono_44100.wav — 44,100 Hz, 1-channel, WAV
let monoWAV = scriptDir.appendingPathComponent("mono_44100.wav")
do {
    try generateWAV(outputURL: monoWAV, sampleRate: 44100, channelCount: 1)
} catch {
    print("ERROR generating mono_44100.wav: \(error)")
    exit(1)
}

// 2. stereo_48000.m4a — 48,000 Hz, 2-channel, AAC M4A
let stereoM4A = scriptDir.appendingPathComponent("stereo_48000.m4a")
do {
    try generateM4A(outputURL: stereoM4A, sampleRate: 48000, channelCount: 2)
} catch {
    print("ERROR generating stereo_48000.m4a: \(error)")
    exit(1)
}

// 3. aac_22050.aac — 22,050 Hz, 1-channel, AAC (M4A container, .aac extension)
// The test code references it with ext:"aac", so we use .aac extension.
// AVFoundation can read M4A-container files regardless of extension.
let aacFile = scriptDir.appendingPathComponent("aac_22050.aac")
do {
    try generateM4A(outputURL: aacFile, sampleRate: 22050, channelCount: 1)
} catch {
    print("ERROR generating aac_22050.aac: \(error)")
    exit(1)
}

print("\nAll fixtures written to: \(scriptDir.path)")
