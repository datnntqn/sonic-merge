//
//  TranscriptionService.swift
//  SonicMerge
//
//  Chunked SFSpeechRecognizer wrapper. Streams TranscriptionState updates as
//  each chunk completes. Resumes from any persisted partial state matching the
//  source's SHA256 hash (spec §7.5).
//

import Foundation
import Speech
import AVFoundation

actor TranscriptionService {

    enum TranscriptionError: Error {
        case recognizerUnavailable
        case onDeviceUnsupported
        case recognitionFailed(Error)
    }

    private let chunkDurationSeconds: TimeInterval
    private let stateStore: TranscriptionStateStore
    private let locale: Locale

    init(chunkDurationSeconds: TimeInterval = 30,
         stateStore: TranscriptionStateStore = .default,
         locale: Locale = Locale(identifier: "en-US")) {
        self.chunkDurationSeconds = chunkDurationSeconds
        self.stateStore = stateStore
        self.locale = locale
    }

    /// Streams TranscriptionState updates after each chunk completes.
    /// Resumes from any persisted partial state matching the source's hash.
    func transcribe(input: URL) -> AsyncThrowingStream<TranscriptionState, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let recognizer = SFSpeechRecognizer(locale: locale),
                          recognizer.isAvailable else {
                        throw TranscriptionError.recognizerUnavailable
                    }
                    guard recognizer.supportsOnDeviceRecognition else {
                        throw TranscriptionError.onDeviceUnsupported
                    }

                    let sourceHash = try await SourceHasher.sha256Hex(of: input)
                    let asset = AVURLAsset(url: input)
                    let totalDuration = try await asset.load(.duration).seconds

                    var state = (try? await stateStore.load(sourceHash))
                        ?? TranscriptionState(
                            sourceHash: sourceHash,
                            sourceDuration: totalDuration,
                            chunkDurationSeconds: chunkDurationSeconds,
                            completedChunkCount: 0,
                            recognizedSegments: [],
                            isComplete: false
                        )

                    while state.nextChunkStartTime < totalDuration {
                        let startSec = state.nextChunkStartTime
                        let endSec = min(startSec + chunkDurationSeconds, totalDuration)
                        let segments = try await recognize(asset: asset,
                                                          recognizer: recognizer,
                                                          startSec: startSec,
                                                          endSec: endSec)
                        let shifted = segments.map { seg in
                            TranscriptionState.RecognizedSegment(
                                text: seg.text,
                                startTime: seg.startTime + startSec,
                                endTime: seg.endTime + startSec,
                                confidence: seg.confidence
                            )
                        }
                        state.recognizedSegments.append(contentsOf: shifted)
                        state.completedChunkCount += 1
                        try await stateStore.save(state)
                        continuation.yield(state)
                    }

                    state.isComplete = true
                    try await stateStore.save(state)
                    continuation.yield(state)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func recognize(asset: AVURLAsset,
                           recognizer: SFSpeechRecognizer,
                           startSec: TimeInterval,
                           endSec: TimeInterval) async throws -> [TranscriptionState.RecognizedSegment] {
        let chunkURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("transcribe-chunk-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: chunkURL) }

        try await exportChunk(asset: asset, startSec: startSec, endSec: endSec, to: chunkURL)

        let request = SFSpeechURLRecognitionRequest(url: chunkURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            let didResumeBox = DidResumeBox()
            let task = recognizer.recognitionTask(with: request) { result, error in
                guard !didResumeBox.didResume else { return }
                if let error {
                    didResumeBox.didResume = true
                    continuation.resume(throwing: TranscriptionError.recognitionFailed(error))
                    return
                }
                guard let result, result.isFinal else { return }
                didResumeBox.didResume = true
                let segments: [TranscriptionState.RecognizedSegment] = result.bestTranscription.segments.map { seg in
                    .init(text: seg.substring,
                          startTime: seg.timestamp,
                          endTime: seg.timestamp + seg.duration,
                          confidence: seg.confidence)
                }
                continuation.resume(returning: segments)
            }
            _ = task
        }
    }

    private final class DidResumeBox: @unchecked Sendable {
        var didResume = false
    }

    /// Decode [startSec...endSec] of `asset` to a linear PCM WAV at `to`.
    /// Uses AVAssetReader/AVAssetWriter explicitly so output is uncompressed PCM
    /// regardless of source codec (M4A/AAC merge output OR PCM WAV — AudioMergerService
    /// can produce either; SFSpeechURLRecognitionRequest needs PCM).
    private func exportChunk(asset: AVURLAsset,
                             startSec: TimeInterval,
                             endSec: TimeInterval,
                             to outURL: URL) async throws {
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw TranscriptionError.recognitionFailed(NSError(domain: "TranscriptionService", code: -10))
        }

        let reader = try AVAssetReader(asset: asset)
        let timeRange = CMTimeRange(
            start: CMTime(seconds: startSec, preferredTimescale: 44100),
            end: CMTime(seconds: endSec, preferredTimescale: 44100)
        )
        reader.timeRange = timeRange

        let pcmSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: assetTrack, outputSettings: pcmSettings)
        reader.add(readerOutput)

        let writer = try AVAssetWriter(outputURL: outURL, fileType: .wav)
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: pcmSettings)
        writerInput.expectsMediaDataInRealTime = false
        writer.add(writerInput)

        guard reader.startReading() else {
            throw TranscriptionError.recognitionFailed(reader.error
                ?? NSError(domain: "TranscriptionService", code: -11))
        }
        guard writer.startWriting() else {
            throw TranscriptionError.recognitionFailed(writer.error
                ?? NSError(domain: "TranscriptionService", code: -12))
        }
        writer.startSession(atSourceTime: .zero)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            writerInput.requestMediaDataWhenReady(on: DispatchQueue(label: "TranscriptionService.export")) {
                while writerInput.isReadyForMoreMediaData {
                    if let buffer = readerOutput.copyNextSampleBuffer() {
                        if !writerInput.append(buffer) {
                            writerInput.markAsFinished()
                            cont.resume(throwing: writer.error
                                ?? NSError(domain: "TranscriptionService", code: -13))
                            return
                        }
                    } else {
                        writerInput.markAsFinished()
                        writer.finishWriting {
                            if writer.status == .completed {
                                cont.resume()
                            } else {
                                cont.resume(throwing: writer.error
                                    ?? NSError(domain: "TranscriptionService", code: -14))
                            }
                        }
                        return
                    }
                }
            }
        }
    }
}

/// Pluggable persistence for TranscriptionState. Default writes JSON to
/// Library/Caches/SmartCut/<sourceHash>.transcription-state.json (spec §7.5).
struct TranscriptionStateStore {
    let load: (_ sourceHash: String) async throws -> TranscriptionState?
    let save: (TranscriptionState) async throws -> Void

    static let `default`: TranscriptionStateStore = {
        let dir = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SmartCut", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        return TranscriptionStateStore(
            load: { hash in
                let url = dir.appendingPathComponent("\(hash).transcription-state.json")
                guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode(TranscriptionState.self, from: data)
            },
            save: { state in
                let url = dir.appendingPathComponent("\(state.sourceHash).transcription-state.json")
                let data = try JSONEncoder().encode(state)
                try data.write(to: url, options: .atomic)
            }
        )
    }()
}
