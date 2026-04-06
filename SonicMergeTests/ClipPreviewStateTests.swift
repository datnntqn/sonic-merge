// ClipPreviewStateTests.swift
// SonicMergeTests

import AVFoundation
import Foundation
import SwiftData
import Testing
@testable import SonicMerge

@MainActor
struct ClipPreviewStateTests {

    @Test func togglePreview_missingClipFile_doesNotSetPlayingID() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AudioClip.self, GapTransition.self, configurations: config)
        let context = ModelContext(container)
        let vm = MixingStationViewModel(modelContext: context)

        let clip = AudioClip(
            displayName: "Missing",
            fileURLRelativePath: "definitely-not-on-disk-\(UUID().uuidString).m4a",
            duration: 0.1
        )
        clip.sortOrder = 0
        context.insert(clip)
        try context.save()
        await vm.fetchAll()

        vm.toggleClipPreview(clip)
        #expect(vm.previewingClipID == nil)
        vm.stopClipPreview()
        #expect(vm.previewingClipID == nil)
    }

    @Test func togglePreview_existingClipFile_setsAndClearsPlayingID() async throws {
        let clipsDir = try AppConstants.clipsDirectory()
        let filename = "preview-\(UUID().uuidString).wav"
        let absolute = clipsDir.appending(path: filename)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 8000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        let file = try AVAudioFile(forWriting: absolute, settings: settings)
        let frames: AVAudioFrameCount = 800
        guard let format = AVAudioFormat(settings: settings),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            throw NSError(domain: "ClipPreviewStateTests", code: 1)
        }
        buffer.frameLength = frames
        try file.write(from: buffer)

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AudioClip.self, GapTransition.self, configurations: config)
        let context = ModelContext(container)
        let vm = MixingStationViewModel(modelContext: context)

        let clip = AudioClip(displayName: "P", fileURLRelativePath: filename, duration: 0.1)
        clip.sortOrder = 0
        context.insert(clip)
        try context.save()
        await vm.fetchAll()

        vm.toggleClipPreview(clip)
        #expect(vm.previewingClipID == clip.id)

        vm.toggleClipPreview(clip)
        #expect(vm.previewingClipID == nil)

        vm.toggleClipPreview(clip)
        vm.stopClipPreview()
        #expect(vm.previewingClipID == nil)
    }
}
