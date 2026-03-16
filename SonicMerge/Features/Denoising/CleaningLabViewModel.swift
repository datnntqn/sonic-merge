//
//  CleaningLabViewModel.swift
//  SonicMerge
//
//  @Observable @MainActor coordinator for the Cleaning Lab (Plan 03-03).
//
//  Wires NoiseReductionService, WaveformService, dual-player A/B playback,
//  intensity blending, and haptic feedback into a single observable state object
//  for CleaningLabView (Plan 03-04).
//
//  Design decisions (from CONTEXT.md and RESEARCH.md):
//  - intensity default = 0.75 (locked in CONTEXT.md)
//  - Slider drives wet/dry blend only — NO re-inference per change
//  - Autoplay denoised audio after denoise completes
//  - Stale result banner when clips mutate after a prior denoise
//  - Non-dismissible progress modal — cancellable via Cancel button
//  - A/B toggle preserves current playback position (DNS-03)
//  - UIImpactFeedbackGenerator(.medium) fires on holdEnded() release (UX-02)
//
//  AVAudioPlayer note: Both players are pre-loaded via prepareToPlay() before
//  holdBegan()/holdEnded() is ever called. Switching is O(1) — just swap
//  currentTime and start/pause.
//

import AVFoundation
import Accelerate
import Foundation
import Observation
import UIKit

// MARK: - CleaningLabViewModel

/// Observable coordinator for the Cleaning Lab denoising workflow.
///
/// CleaningLabView is a pure rendering layer over this ViewModel.
/// All business logic (pipeline orchestration, A/B playback, blending) lives here.
@Observable
@MainActor
final class CleaningLabViewModel {

    // MARK: - Published State

    /// True while the denoise AsyncStream is running.
    var isProcessing: Bool = false

    /// 0.0–1.0 progress from AsyncStream; drives the progress modal.
    var progress: Float = 0.0

    /// True after denoise() completes successfully with a valid output file.
    var hasDenoisedResult: Bool = false

    /// Wet/dry blend intensity. Default 0.75 per CONTEXT.md locked decision.
    /// Slider drives blend only — NO re-inference on change.
    var intensity: Float = 0.75

    /// True while the "Listen Original" button is held (A/B toggle).
    var isHoldingOriginal: Bool = false

    /// True when clips change after a prior denoise result (stale banner trigger).
    var showsStaleResultBanner: Bool = false

    /// 50 peaks from WaveformService for the denoised audio waveform display.
    var waveformPeaks: [Float] = []

    /// Set if denoise() throws. Cleared on next startDenoising() call.
    var errorMessage: String?

    // MARK: - Private State

    private let noiseReductionService: NoiseReductionService
    private let waveformService: WaveformService

    /// The in-flight denoise+waveform Task. Cancelled by cancelDenoising().
    private var denoisingTask: Task<Void, Never>?

    /// The merged (unprocessed) audio player — active during "Listen Original" hold.
    private var originalPlayer: AVAudioPlayer?

    /// The denoised audio player — active by default after hasDenoisedResult=true.
    private var denoisedPlayer: AVAudioPlayer?

    /// URL of the blended temp file currently loaded into denoisedPlayer.
    /// Updated by onIntensityChanged() after each blend write.
    var denoisedTempURL: URL?

    /// Raw Float32 samples from the original merged file (for blend()).
    private var originalFrames: [Float] = []

    /// Raw Float32 samples from the denoised output file (for blend()).
    private var denoisedFrames: [Float] = []

    // MARK: - Init

    init(
        noiseReductionService: NoiseReductionService = NoiseReductionService(),
        waveformService: WaveformService = WaveformService()
    ) {
        self.noiseReductionService = noiseReductionService
        self.waveformService = waveformService
    }

    // MARK: - Pipeline: startDenoising

    /// Triggers the merge → denoise → waveform pipeline.
    ///
    /// Sequence:
    /// 1. Set isProcessing=true, progress=0.0, clear any prior error
    /// 2. Create temp URL for denoised .wav in temporaryDirectory
    /// 3. Call noiseReductionService.denoise(inputURL:outputURL:) → AsyncStream<Float>
    /// 4. Consume stream: for await p in stream { progress = p }
    /// 5. On stream finish: call waveformService.generate() for denoised file
    /// 6. Set waveformPeaks, hasDenoisedResult=true, isProcessing=false
    /// 7. Prepare both AVAudioPlayers with prepareToPlay()
    /// 8. Start denoisedPlayer.play() (autoplay per CONTEXT.md)
    /// 9. On error: set errorMessage, isProcessing=false
    /// 10. On cancel: task.cancel() → break stream loop → discard temp file
    func startDenoising(mergedFileURL: URL) {
        // Cancel any previous run
        denoisingTask?.cancel()
        denoisingTask = nil

        // Reset state
        isProcessing = true
        progress = 0.0
        errorMessage = nil
        hasDenoisedResult = false
        showsStaleResultBanner = false

        denoisingTask = Task {
            // Create denoised temp file URL
            let tempURL = FileManager.default.temporaryDirectory
                .appending(path: "SonicMerge-Denoised-\(UUID().uuidString).wav")

            do {
                // Step 3–4: Run inference; consume progress stream
                let stream = await noiseReductionService.denoise(
                    inputURL: mergedFileURL,
                    outputURL: tempURL
                )
                for try await p in stream {
                    guard !Task.isCancelled else { break }
                    progress = p
                }

                guard !Task.isCancelled else {
                    // Clean up partial output
                    try? FileManager.default.removeItem(at: tempURL)
                    isProcessing = false
                    return
                }

                // Step 5: Generate waveform for denoised audio
                let waveformURL = FileManager.default.temporaryDirectory
                    .appending(path: "SonicMerge-Waveform-\(UUID().uuidString).waveform")
                try await waveformService.generate(
                    audioURL: tempURL,
                    destinationURL: waveformURL
                )

                // Load waveform peaks from sidecar
                if let data = try? Data(contentsOf: waveformURL) {
                    let count = data.count / MemoryLayout<Float>.size
                    waveformPeaks = data.withUnsafeBytes { ptr in
                        Array(ptr.bindMemory(to: Float.self).prefix(count))
                    }
                }

                // Load raw PCM samples for future blend() calls
                originalFrames = loadPCMFrames(from: mergedFileURL)
                denoisedFrames = loadPCMFrames(from: tempURL)

                // Step 7: Prepare both players
                let origPlayer = try AVAudioPlayer(contentsOf: mergedFileURL)
                let denPlayer  = try AVAudioPlayer(contentsOf: tempURL)
                origPlayer.prepareToPlay()
                denPlayer.prepareToPlay()

                originalPlayer = origPlayer
                denoisedPlayer = denPlayer
                denoisedTempURL = tempURL

                // Step 6: Update observable state
                hasDenoisedResult = true
                isProcessing = false

                // Step 8: Autoplay denoised result
                denoisedPlayer?.play()

            } catch {
                errorMessage = error.localizedDescription
                isProcessing = false
                // Clean up any partial temp file
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
    }

    // MARK: - Pipeline: cancelDenoising

    /// Cancels the in-flight denoise Task, discards temp output, resets isProcessing.
    func cancelDenoising() {
        denoisingTask?.cancel()
        denoisingTask = nil

        // Clean up any partial temp file in temporaryDirectory
        let tempDir = FileManager.default.temporaryDirectory
        if let items = try? FileManager.default.contentsOfDirectory(
            at: tempDir, includingPropertiesForKeys: nil
        ) {
            for item in items where item.lastPathComponent.hasPrefix("SonicMerge-Denoised-") {
                try? FileManager.default.removeItem(at: item)
            }
        }

        isProcessing = false
    }

    // MARK: - Intensity Blend

    /// Called when the intensity slider value changes.
    ///
    /// Actor hops to NoiseReductionService to call blend() (vDSP SIMD vectorized).
    /// Writes blended buffer to a new temp .wav and reinitializes denoisedPlayer.
    /// Does NOT trigger re-inference — slider is wet/dry mix only (CONTEXT.md).
    func onIntensityChanged(_ value: Float) {
        intensity = value
        guard hasDenoisedResult,
              !originalFrames.isEmpty,
              !denoisedFrames.isEmpty else { return }

        Task {
            let blended = blend(
                original: originalFrames,
                denoised: denoisedFrames,
                intensity: value
            )

            // Write blended buffer to new temp .wav
            let blendedURL = FileManager.default.temporaryDirectory
                .appending(path: "SonicMerge-Blended-\(UUID().uuidString).wav")
            do {
                try writePCMSamples(blended, to: blendedURL)

                // Capture currentTime before reinitializing player
                let currentTime = denoisedPlayer?.currentTime ?? 0
                let wasPlaying = denoisedPlayer?.isPlaying ?? false

                let newPlayer = try AVAudioPlayer(contentsOf: blendedURL)
                newPlayer.prepareToPlay()
                newPlayer.currentTime = currentTime
                if wasPlaying { newPlayer.play() }

                // Clean up old blended temp file (not original denoised output)
                if let oldURL = denoisedTempURL,
                   oldURL.lastPathComponent.hasPrefix("SonicMerge-Blended-") {
                    try? FileManager.default.removeItem(at: oldURL)
                }

                denoisedPlayer = newPlayer
                denoisedTempURL = blendedURL
            } catch {
                // Non-fatal: blend write failure is recoverable — continue with prior player
            }
        }
    }

    // MARK: - A/B Playback

    /// Switch to originalPlayer at the denoised player's current position.
    ///
    /// Both players must be prepareToPlay()'d before this is called.
    /// No-op if hasDenoisedResult=false (players not yet loaded).
    func holdBegan() {
        guard hasDenoisedResult,
              let orig = originalPlayer,
              let den = denoisedPlayer else { return }

        let pos = den.currentTime
        orig.currentTime = pos
        den.pause()
        orig.play()
        isHoldingOriginal = true
    }

    /// Switch back to denoisedPlayer at the original player's current position.
    ///
    /// Fires UIImpactFeedbackGenerator(.medium) on release (UX-02).
    /// No-op if hasDenoisedResult=false.
    func holdEnded() {
        guard hasDenoisedResult,
              let orig = originalPlayer,
              let den = denoisedPlayer else { return }

        let pos = orig.currentTime
        den.currentTime = pos
        orig.pause()
        den.play()
        isHoldingOriginal = false

        // UX-02: Haptic feedback on release
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Stale Result Banner

    /// Called when the clip list changes after a prior denoise result.
    ///
    /// Sets showsStaleResultBanner=true only when hasDenoisedResult==true.
    /// The banner prompts the user to re-process with the updated clips.
    func markClipsChanged() {
        guard hasDenoisedResult else { return }
        showsStaleResultBanner = true
    }

    // MARK: - Private Helpers

    /// Load all Float32 PCM samples from an audio file (left channel only for memory efficiency).
    ///
    /// Returns empty array on any read error (non-fatal — blend will skip if empty).
    private func loadPCMFrames(from url: URL) -> [Float] {
        guard let file = try? AVAudioFile(forReading: url) else { return [] }
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              (try? file.read(into: buffer, frameCount: frameCount)) != nil,
              let channelData = buffer.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
    }

    /// Write Float32 mono samples to a .wav file at 48 kHz stereo (duplicate to both channels).
    private func writePCMSamples(_ samples: [Float], to url: URL) throws {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 2,
            interleaved: false
        )!
        try? FileManager.default.removeItem(at: url)
        let file = try AVAudioFile(forWriting: url, settings: format.settings)

        let frameCount = AVAudioFrameCount(samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        if let channelData = buffer.floatChannelData {
            samples.withUnsafeBufferPointer { src in
                channelData[0].update(from: src.baseAddress!, count: samples.count)
                channelData[1].update(from: src.baseAddress!, count: samples.count)
            }
        }

        try file.write(from: buffer)
    }
}
