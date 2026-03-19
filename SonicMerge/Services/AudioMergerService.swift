//
//  AudioMergerService.swift
//  SonicMerge
//
//  Full AVFoundation implementation replacing the Plan 02-03 stub.
//
//  Design constraints (from RESEARCH.md):
//  - Plain `actor` (NOT @MainActor) — all non-Sendable AVFoundation objects stay inside the actor.
//  - Crossfade requires TWO AVMutableCompositionTrack instances. A single track cannot have
//    overlapping time ranges — attempting this silently cuts audio instead of blending.
//  - WAV export requires AVAssetReader + AVAssetWriter. AVAssetExportSession cannot produce
//    WAV from an AAC source composition (Pitfall 1).
//  - exportAsynchronously(completionHandler:) is used for iOS 17 compatibility.
//    export(to:as:isolation:) is iOS 18+ only.
//

import AVFoundation
import Accelerate
import Foundation

/// Export output format — kept as top-level enum to match the stub API locked by Plan 02-03.
enum ExportFormat {
    case m4a
    case wav
}

/// Builds an AVMutableComposition from sorted AudioClips with GapTransitions,
/// then exports to .m4a (AVAssetExportSession) or .wav (AVAssetReader+Writer).
///
/// All AVFoundation work is isolated inside this actor. Only primitive values
/// (URL, Float) cross actor boundaries. Never store AVFoundation objects as
/// properties or pass them to @MainActor.
///
/// Two-track crossfade: Track A carries all clips; Track B carries the incoming
/// clip for each crossfade, starting at the overlap point. Both tracks are mixed
/// by AVAssetExportSession using AVAudioMix with setVolumeRamp parameters.
/// A single track cannot have overlapping time ranges (silent cut instead of blend).
actor AudioMergerService {

    // MARK: - Public API

    /// Export sorted clips with transitions to destinationURL.
    ///
    /// - Parameters:
    ///   - clips: AudioClips in display order (sorted by sortOrder by caller).
    ///   - transitions: All GapTransitions; matched to clips via leadingClipSortOrder.
    ///   - format: .m4a (AVAssetExportSession) or .wav (AVAssetReader+Writer).
    ///   - destinationURL: Output file path.
    ///   - clipsBaseURL: Override clips directory (used in tests to point to bundle fixtures).
    ///                   Defaults to nil — resolves via AppConstants.clipsDirectory().
    ///   - lufsNormalize: When true, measures integrated loudness and applies gain to reach -16 LUFS.
    ///                    Defaults to false — preserves existing behavior exactly.
    /// - Returns: AsyncStream of progress values 0.0...1.0.
    func export(
        clips: [AudioClip],
        transitions: [GapTransition],
        format: ExportFormat,
        destinationURL: URL,
        clipsBaseURL: URL? = nil,
        lufsNormalize: Bool = false
    ) -> AsyncStream<Float> {
        AsyncStream { continuation in
            Task {
                do {
                    let (composition, audioMix) = try await buildComposition(
                        clips: clips,
                        transitions: transitions,
                        clipsBaseURL: clipsBaseURL
                    )

                    // Compute LUFS gain scalar if normalization requested.
                    // For multi-clip export, measure LUFS on the first clip as a proxy
                    // (acceptable approximation for MVP — exact measurement deferred to v2
                    // which would require a temp-WAV measure pass).
                    var lufsGainScalar: Float = 1.0
                    if lufsNormalize, let firstClip = clips.sorted(by: { $0.sortOrder < $1.sortOrder }).first {
                        continuation.yield(0.05)
                        let lufsService = LUFSNormalizationService()
                        let clipURL: URL
                        if let base = clipsBaseURL {
                            clipURL = base.appending(path: firstClip.fileURLRelativePath)
                        } else if let url = try? firstClip.fileURL {
                            clipURL = url
                        } else {
                            clipURL = destinationURL  // fallback — no-op
                        }
                        let scalar = await lufsService.gainScalar(for: clipURL)
                        lufsGainScalar = Float(scalar)
                        continuation.yield(0.15)
                    }

                    switch format {
                    case .m4a:
                        try await exportM4A(
                            composition: composition,
                            audioMix: audioMix,
                            to: destinationURL,
                            progress: continuation,
                            gainScalar: lufsGainScalar,
                            progressRange: lufsNormalize ? (0.15, 1.0) : (0.0, 1.0)
                        )
                    case .wav:
                        try await exportWAV(
                            composition: composition,
                            to: destinationURL,
                            progress: continuation,
                            gainScalar: lufsGainScalar,
                            progressRange: lufsNormalize ? (0.15, 1.0) : (0.0, 1.0)
                        )
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Single-File Export (used by CleaningLabView)

    /// Export a single pre-built audio file (e.g., the intensity-blended denoised .wav)
    /// to the given format without re-merging clips.
    ///
    /// Used by CleaningLabView to export the intensity-blended denoised output.
    /// The source file is treated as a single-track composition.
    ///
    /// - Parameters:
    ///   - inputURL: URL of the pre-built audio file to export.
    ///   - format: Target output format (.m4a or .wav).
    ///   - destinationURL: Output file path.
    ///   - lufsNormalize: When true, measures LUFS on inputURL and applies gain to reach -16 LUFS.
    ///                    Defaults to false — preserves existing behavior exactly.
    /// - Returns: AsyncStream of progress values 0.0...1.0.
    func exportFile(
        inputURL: URL,
        format: ExportFormat,
        destinationURL: URL,
        lufsNormalize: Bool = false
    ) -> AsyncStream<Float> {
        AsyncStream { continuation in
            Task {
                do {
                    let asset = AVURLAsset(url: inputURL)
                    let composition = AVMutableComposition()
                    guard let track = composition.addMutableTrack(
                        withMediaType: .audio,
                        preferredTrackID: kCMPersistentTrackID_Invalid
                    ) else {
                        continuation.finish()
                        return
                    }
                    guard let sourceTrack = try await asset.loadTracks(withMediaType: .audio).first else {
                        continuation.finish()
                        return
                    }
                    let duration = try await asset.load(.duration)
                    try track.insertTimeRange(
                        CMTimeRange(start: .zero, duration: duration),
                        of: sourceTrack,
                        at: .zero
                    )
                    let audioMix = AVMutableAudioMix()

                    // Measure LUFS on the source file directly (single-file path is exact).
                    var lufsGainScalar: Float = 1.0
                    if lufsNormalize {
                        continuation.yield(0.05)
                        let lufsService = LUFSNormalizationService()
                        let scalar = await lufsService.gainScalar(for: inputURL)
                        lufsGainScalar = Float(scalar)
                        continuation.yield(0.15)
                    }

                    switch format {
                    case .m4a:
                        try await exportM4A(
                            composition: composition,
                            audioMix: audioMix,
                            to: destinationURL,
                            progress: continuation,
                            gainScalar: lufsGainScalar,
                            progressRange: lufsNormalize ? (0.15, 1.0) : (0.0, 1.0)
                        )
                    case .wav:
                        try await exportWAV(
                            composition: composition,
                            to: destinationURL,
                            progress: continuation,
                            gainScalar: lufsGainScalar,
                            progressRange: lufsNormalize ? (0.15, 1.0) : (0.0, 1.0)
                        )
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Composition

    private func buildComposition(
        clips: [AudioClip],
        transitions: [GapTransition],
        clipsBaseURL: URL?
    ) async throws -> (AVMutableComposition, AVAudioMix) {
        let composition = AVMutableComposition()

        // Track A: primary track — receives all clip segments
        guard let trackA = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw MergeError.trackCreationFailed }

        // Track B: crossfade-incoming track — only used for crossfade overlaps
        guard let trackB = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw MergeError.trackCreationFailed }

        let paramsA = AVMutableAudioMixInputParameters(track: trackA)
        let paramsB = AVMutableAudioMixInputParameters(track: trackB)
        let crossfadeDuration = CMTimeMakeWithSeconds(0.5, preferredTimescale: 48_000)
        var cursor = CMTime.zero
        var hasCrossfade = false

        let sortedClips = clips.sorted(by: { $0.sortOrder < $1.sortOrder })

        for (index, clip) in sortedClips.enumerated() {
            // Resolve clip URL
            let clipURL: URL
            if let base = clipsBaseURL {
                clipURL = base.appending(path: clip.fileURLRelativePath)
            } else {
                guard let url = try? clip.fileURL else {
                    throw MergeError.clipURLUnavailable
                }
                clipURL = url
            }

            let asset = AVURLAsset(url: clipURL)
            guard let sourceTrack = try await asset.loadTracks(withMediaType: .audio).first else {
                throw MergeError.noAudioTrack
            }
            let clipDuration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: clipDuration)

            // Insert clip into Track A at cursor
            try trackA.insertTimeRange(timeRange, of: sourceTrack, at: cursor)

            // Determine transition after this clip
            let transition = transitions.first(where: { $0.leadingClipSortOrder == clip.sortOrder })
            let isLastClip = index == sortedClips.count - 1

            if !isLastClip, let t = transition {
                if t.isCrossfade && clipDuration > crossfadeDuration {
                    // Crossfade: overlap next clip by 0.5s using Track B
                    hasCrossfade = true
                    let overlapStart = CMTimeAdd(cursor, CMTimeSubtract(clipDuration, crossfadeDuration))

                    // Volume ramp on Track A: 1.0 -> 0.0 over last 0.5s of this clip
                    paramsA.setVolumeRamp(
                        fromStartVolume: 1.0,
                        toEndVolume: 0.0,
                        timeRange: CMTimeRange(start: overlapStart, duration: crossfadeDuration)
                    )
                    // Volume ramp on Track B: 0.0 -> 1.0 over first 0.5s of next clip
                    paramsB.setVolumeRamp(
                        fromStartVolume: 0.0,
                        toEndVolume: 1.0,
                        timeRange: CMTimeRange(start: overlapStart, duration: crossfadeDuration)
                    )

                    // Advance cursor to the overlap start point
                    cursor = overlapStart

                    // Insert next clip into Track B starting at overlap start
                    if index + 1 < sortedClips.count {
                        let nextClip = sortedClips[index + 1]
                        let nextURL: URL
                        if let base = clipsBaseURL {
                            nextURL = base.appending(path: nextClip.fileURLRelativePath)
                        } else {
                            guard let url = try? nextClip.fileURL else {
                                throw MergeError.clipURLUnavailable
                            }
                            nextURL = url
                        }
                        let nextAsset = AVURLAsset(url: nextURL)
                        if let nextSourceTrack = try await nextAsset.loadTracks(withMediaType: .audio).first {
                            let nextDuration = try await nextAsset.load(.duration)
                            let nextRange = CMTimeRange(start: .zero, duration: nextDuration)
                            try? trackB.insertTimeRange(nextRange, of: nextSourceTrack, at: cursor)
                        }
                    }
                } else {
                    // Silence gap: advance past full clip, then insert empty range
                    cursor = CMTimeAdd(cursor, clipDuration)
                    let gapDur = CMTimeMakeWithSeconds(t.gapDuration, preferredTimescale: 48_000)
                    trackA.insertEmptyTimeRange(CMTimeRange(start: cursor, duration: gapDur))
                    cursor = CMTimeAdd(cursor, gapDur)
                }
            } else {
                cursor = CMTimeAdd(cursor, clipDuration)
            }
        }

        // Build AVAudioMix
        let audioMix = AVMutableAudioMix()
        if hasCrossfade {
            audioMix.inputParameters = [paramsA, paramsB]
        } else {
            audioMix.inputParameters = [paramsA]
        }

        return (composition, audioMix)
    }

    // MARK: - m4a Export (EXP-01)

    private func exportM4A(
        composition: AVMutableComposition,
        audioMix: AVAudioMix,
        to url: URL,
        progress: AsyncStream<Float>.Continuation,
        gainScalar: Float = 1.0,
        progressRange: (Float, Float) = (0.0, 1.0)
    ) async throws {
        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else { throw MergeError.exportSessionUnavailable }

        session.outputFileType = .m4a
        session.outputURL = url
        try? FileManager.default.removeItem(at: url)

        // Apply LUFS gain via AVMutableAudioMixInputParameters when gainScalar != 1.0.
        // Merges with existing crossfade parameters — does NOT replace them.
        if gainScalar != 1.0, let firstTrack = composition.tracks(withMediaType: .audio).first {
            let mutableMix = AVMutableAudioMix()
            let existingParams = (audioMix as? AVMutableAudioMix)?.inputParameters ?? audioMix.inputParameters
            let gainParams = AVMutableAudioMixInputParameters(track: firstTrack)
            gainParams.setVolume(gainScalar, at: .zero)
            mutableMix.inputParameters = existingParams + [gainParams]
            session.audioMix = mutableMix
        } else {
            session.audioMix = audioMix
        }

        // Poll progress at 100ms intervals.
        // KVO does not work reliably on AVAssetExportSession.progress across all iOS versions.
        let pollingTask = Task {
            while !Task.isCancelled {
                let rawProgress = session.progress
                let mapped = progressRange.0 + rawProgress * (progressRange.1 - progressRange.0)
                progress.yield(mapped)
                try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
            }
        }

        // iOS 17 compatible: exportAsynchronously with continuation wrapper.
        // export(to:as:isolation:) is iOS 18+ only.
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                pollingTask.cancel()
                switch session.status {
                case .completed:
                    cont.resume()
                default:
                    cont.resume(throwing: session.error ?? MergeError.exportFailed)
                }
            }
        }
        progress.yield(1.0)
    }

    // MARK: - WAV Export (EXP-02)
    //
    // CRITICAL: Cannot use AVAssetExportSession for WAV from an AAC source — Pitfall 1.
    // Decode with AVAssetReader (Linear PCM float32 output when gainScalar != 1.0,
    // int16 otherwise), apply gain via vDSP_vsmul, re-encode to int16 via AVAssetWriter.

    private func exportWAV(
        composition: AVMutableComposition,
        to url: URL,
        progress: AsyncStream<Float>.Continuation,
        gainScalar: Float = 1.0,
        progressRange: (Float, Float) = (0.0, 1.0)
    ) async throws {
        let reader = try AVAssetReader(asset: composition)

        // Use float32 when gain is applied so vDSP_vsmul works correctly.
        // Use int16 otherwise (no precision loss, matches original behavior).
        let useFloat = gainScalar != 1.0
        let readerOutput = AVAssetReaderAudioMixOutput(
            audioTracks: composition.tracks(withMediaType: .audio),
            audioSettings: [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVLinearPCMBitDepthKey: useFloat ? 32 : 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: useFloat,
                AVLinearPCMIsNonInterleaved: false
            ]
        )
        reader.add(readerOutput)

        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .wav)
        let writerInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
        )
        writerInput.expectsMediaDataInRealTime = false
        writer.add(writerInput)

        let totalSeconds = composition.duration.seconds
        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: .zero)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let queue = DispatchQueue(label: "com.sonicmerge.merge.wav", qos: .userInitiated)
            writerInput.requestMediaDataWhenReady(on: queue) {
                while writerInput.isReadyForMoreMediaData {
                    if let buf = readerOutput.copyNextSampleBuffer() {
                        let pts = CMSampleBufferGetPresentationTimeStamp(buf).seconds
                        let rawProgress = Float(min(pts / max(totalSeconds, 1), 0.99))
                        let mappedProgress = progressRange.0 + rawProgress * (progressRange.1 - progressRange.0)
                        progress.yield(mappedProgress)
                        // Apply gain in-place when gainScalar != 1.0 (float32 buffers only)
                        let gained = self.applyGain(to: buf, scalar: gainScalar)
                        writerInput.append(gained ?? buf)
                    } else {
                        writerInput.markAsFinished()
                        Task {
                            await writer.finishWriting()
                            continuation.resume()
                        }
                        return
                    }
                }
            }
        }

        if writer.status == .failed {
            throw writer.error ?? MergeError.exportFailed
        }
        progress.yield(1.0)
    }

    // MARK: - Gain Application (EXP-03 LUFS normalization)

    /// Applies a linear gain scalar to a float32 PCM CMSampleBuffer in-place via vDSP.
    /// Returns nil if the buffer cannot be modified or scalar is 1.0 (no-op).
    /// Caller falls back to appending the original buffer when nil is returned.
    ///
    /// REQUIRES: Reader output settings use AVLinearPCMIsFloatKey: true.
    private func applyGain(to sampleBuffer: CMSampleBuffer, scalar: Float) -> CMSampleBuffer? {
        guard scalar != 1.0 else { return nil }
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
        let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
        guard numSamples > 0 else { return nil }

        var dataLength = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(
            blockBuffer, atOffset: 0,
            lengthAtOffsetOut: nil, totalLengthOut: &dataLength,
            dataPointerOut: &dataPointer
        ) == noErr, let ptr = dataPointer else { return nil }

        let floatPtr = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: Float.self)
        let floatCount = vDSP_Length(dataLength / MemoryLayout<Float>.size)
        var s = scalar
        vDSP_vsmul(floatPtr, 1, &s, floatPtr, 1, floatCount)
        return sampleBuffer  // modified in-place
    }
}

// MARK: - Errors

enum MergeError: Error, LocalizedError {
    case noAudioTrack
    case trackCreationFailed
    case exportSessionUnavailable
    case exportFailed
    case clipURLUnavailable

    var errorDescription: String? {
        switch self {
        case .noAudioTrack:             return "One or more clips contain no audio track."
        case .trackCreationFailed:      return "Could not create AVMutableCompositionTrack."
        case .exportSessionUnavailable: return "AVAssetExportSession could not be created."
        case .exportFailed:             return "Export failed."
        case .clipURLUnavailable:       return "Could not resolve clip file URL."
        }
    }
}
