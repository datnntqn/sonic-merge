//
//  SpeechAnalyzerTranscriptionService.swift
//  SonicMerge
//
//  iOS 26+ long-form transcription engine. SpeechAnalyzer + SpeechTranscriber
//  stream finalized text segments out as the analyzer makes progress on the
//  source audio file. State is snapshotted every ~30s of recognized audio so
//  BackgroundTranscriptionTask can resume on the same engine via
//  TranscriptionServiceFactory.
//

import Foundation
import Speech
import AVFoundation

@available(iOS 26, *)
actor SpeechAnalyzerTranscriptionService: TranscriptionServicing {

    enum AnalyzerError: LocalizedError {
        case audioFileFailed(Error)
        case modelDownloadRequired
        case localeNotSupported(String)

        var errorDescription: String? {
            switch self {
            case .audioFileFailed:
                return "Couldn't read this audio file. Try re-importing."
            case .modelDownloadRequired:
                return "Language model is downloading. Please try again in a moment."
            case .localeNotSupported(let identifier):
                return "Speech recognition isn't available for \(identifier) on this device."
            }
        }
    }

    private let stateStore: TranscriptionStateStore
    private let locale: Locale
    private let snapshotInterval: TimeInterval

    init(locale: Locale,
         stateStore: TranscriptionStateStore = .default,
         snapshotInterval: TimeInterval = 30) {
        self.locale = locale
        self.stateStore = stateStore
        self.snapshotInterval = snapshotInterval
    }

    nonisolated func transcribe(input: URL) -> AsyncThrowingStream<TranscriptionState, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await runTranscription(input: input, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func runTranscription(input: URL,
                                  continuation: AsyncThrowingStream<TranscriptionState, Error>.Continuation) async throws {
        let rawHash = try await SourceHasher.sha256Hex(of: input)
        // Namespaced key (mirrors TranscriptionService's "#cloud" / "#local")
        // so SF and SpeechAnalyzer caches never collide for the same source.
        let sourceHash = "\(rawHash)#analyzer"

        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: input)
        } catch {
            throw AnalyzerError.audioFileFailed(error)
        }

        let format = audioFile.processingFormat
        let totalDuration = format.sampleRate > 0
            ? Double(audioFile.length) / format.sampleRate
            : 0

        // Resolve the requested locale against what's actually supported. If
        // not, surface a typed error so the UI can show a sensible message.
        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw AnalyzerError.localeNotSupported(locale.identifier)
        }

        var state: TranscriptionState
        if let existing = try? await stateStore.load(sourceHash) {
            state = existing
        } else {
            state = TranscriptionState(
                sourceHash: sourceHash,
                sourceDuration: totalDuration,
                chunkDurationSeconds: 0,
                completedChunkCount: 0,
                recognizedSegments: [],
                isComplete: false,
                localeIdentifier: locale.identifier,
                engine: .speechAnalyzer,
                completedRecognizedDuration: 0,
                liveTranscriptText: ""
            )
        }

        if state.isComplete {
            continuation.yield(state)
            return
        }

        // Empty-source / fully-recognized short-circuit.
        guard totalDuration > state.completedRecognizedDuration else {
            state.isComplete = true
            try await stateStore.save(state)
            continuation.yield(state)
            return
        }

        // Seek to resume position. AVAudioFile.framePosition is settable.
        if state.completedRecognizedDuration > 0 {
            let resumeFrame = AVAudioFramePosition(state.completedRecognizedDuration * format.sampleRate)
            audioFile.framePosition = min(resumeFrame, audioFile.length)
        }

        let transcriber = SpeechTranscriber(
            locale: supportedLocale,
            preset: .progressiveTranscription
        )

        // Verify the model is installed. If the locale is supported but the
        // model isn't on this device, surface a typed error so the caller can
        // either trigger a download or show a "still downloading" message.
        let inventoryStatus = await AssetInventory.status(forModules: [transcriber])
        switch inventoryStatus {
        case .installed:
            break
        case .supported, .downloading:
            throw AnalyzerError.modelDownloadRequired
        case .unsupported:
            throw AnalyzerError.localeNotSupported(locale.identifier)
        @unknown default:
            throw AnalyzerError.modelDownloadRequired
        }

        let analyzer: SpeechAnalyzer
        do {
            analyzer = try await SpeechAnalyzer(
                inputAudioFile: audioFile,
                modules: [transcriber],
                finishAfterFile: true
            )
        } catch {
            throw AnalyzerError.audioFileFailed(error)
        }

        // The analyzer above starts on construction. Consume finalized results.
        var lastSnapshotAt = state.completedRecognizedDuration
        do {
            for try await result in transcriber.results {
                appendResult(result, into: &state)
                if state.completedRecognizedDuration - lastSnapshotAt >= snapshotInterval {
                    try await stateStore.save(state)
                    lastSnapshotAt = state.completedRecognizedDuration
                }
                continuation.yield(state)
            }
        } catch {
            await analyzer.cancelAndFinishNow()
            throw error
        }

        state.isComplete = true
        try await stateStore.save(state)
        continuation.yield(state)
    }

    /// Translate one finalized SpeechTranscriber result into a RecognizedSegment,
    /// append to `state`, update `liveTranscriptText` (no leading space on the
    /// first append), and bump `completedRecognizedDuration`.
    private func appendResult(_ result: SpeechTranscriber.Result,
                              into state: inout TranscriptionState) {
        let plainText = String(result.text.characters)
        let startTime = result.range.start.seconds
        let endTime = result.range.end.seconds

        state.recognizedSegments.append(.init(
            text: plainText,
            startTime: startTime,
            endTime: endTime,
            // SpeechTranscriber exposes per-character transcriptionConfidence on
            // the AttributedString, but FillerDetector only propagates the value
            // (doesn't gate on it), so a constant 1.0 here is equivalent and
            // avoids the AttributedString-attribute walk.
            confidence: 1.0
        ))

        if state.liveTranscriptText.isEmpty {
            state.liveTranscriptText = plainText
        } else {
            state.liveTranscriptText += " \(plainText)"
        }

        state.completedRecognizedDuration = max(state.completedRecognizedDuration, endTime)
    }
}
