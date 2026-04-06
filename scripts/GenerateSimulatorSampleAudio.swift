#!/usr/bin/env swift
// GenerateSimulatorSampleAudio.swift
// Writes short test clips into SimulatorSampleAudio/ for drag-and-drop onto the Simulator.
// Run from repo root: swift scripts/GenerateSimulatorSampleAudio.swift

import AVFoundation
import Foundation

let repoRoot = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let outDir = repoRoot.appendingPathComponent("SimulatorSampleAudio", isDirectory: true)

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func generateWAV(outputURL: URL, sampleRate: Double, channelCount: AVAudioChannelCount, frequency: Double, durationSeconds: Double = 2.0) throws {
    let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: sampleRate,
        channels: channelCount,
        interleaved: false
    )!
    let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
    buffer.frameLength = frameCount

    for ch in 0..<Int(channelCount) {
        let data = buffer.floatChannelData![ch]
        for i in 0..<Int(frameCount) {
            data[i] = Float(0.35 * sin(2.0 * .pi * frequency * Double(i) / sampleRate))
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
}

// Distinct tones for easy order checking after merge (WAV only — reliable from command-line Swift).
try generateWAV(
    outputURL: outDir.appendingPathComponent("sample_A_440Hz_mono.wav"),
    sampleRate: 44100,
    channelCount: 1,
    frequency: 440,
    durationSeconds: 2.5
)
try generateWAV(
    outputURL: outDir.appendingPathComponent("sample_B_523Hz_stereo.wav"),
    sampleRate: 48000,
    channelCount: 2,
    frequency: 523.25,
    durationSeconds: 2.5
)
try generateWAV(
    outputURL: outDir.appendingPathComponent("sample_C_659Hz_mono.wav"),
    sampleRate: 48000,
    channelCount: 1,
    frequency: 659.25,
    durationSeconds: 2.0
)

print("Samples written to: \(outDir.path)")
