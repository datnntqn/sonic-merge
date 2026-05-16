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

        var errorDescription: String? {
            switch self {
            case .audioFileFailed:
                return "Couldn't read this audio file. Try re-importing."
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
        // Probe whether SpeechAnalyzer can actually run on this device for this
        // locale. Simulators and freshly-set-up devices often lack the model;
        // when that's the case we fall back to chunked SFSpeechRecognizer so the
        // user can still use Smart Cut while the analyzer model downloads.
        guard let supportedLocale = await prepareAnalyzerModel(for: locale) else {
            try await delegateToSF(input: input, continuation: continuation)
            return
        }

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

        // `.timeIndexedProgressiveTranscription` is the only preset that
        // attaches per-word `audioTimeRange` attributes on the result's
        // AttributedString. Setting `attributeOptions: [.audioTimeRange]`
        // alone on `.progressiveTranscription` is NOT enough — the SDK
        // gates per-word timing on the preset, not on the attribute option.
        // FillerDetector/PauseDetector both assume per-word segmentation,
        // so this preset is load-bearing for downstream filler/pause work.
        let transcriber = SpeechTranscriber(
            locale: supportedLocale,
            preset: .timeIndexedProgressiveTranscription
        )

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

        // The analyzer above starts on construction. Consume finalized results
        // only. With `.timeIndexedProgressiveTranscription` the stream also
        // emits volatile partial results (cumulative growing snapshots); the
        // `where result.isFinal` filter drops those so `appendResult` sees
        // each segment exactly once with its tight per-word audioTimeRange.
        var lastSnapshotAt = state.completedRecognizedDuration
        do {
            for try await result in transcriber.results where result.isFinal {
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
        // Split the finalized result into per-word RecognizedSegments using
        // the per-character `audioTimeRange` attribute. FillerDetector and
        // PauseDetector both assume one-segment-per-spoken-word with tight
        // start/end timestamps; the whole-result `range` is the bounding box
        // of the entire phrase, which makes single-token filler matching
        // ("like") impossible and collapses inter-segment gaps to ~0.
        let attributed = result.text
        var perWord: [TranscriptionState.RecognizedSegment] = []
        for (cmRange, charRange) in attributed.runs[\.audioTimeRange] {
            guard let cmRange else { continue }
            let token = String(attributed[charRange].characters)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else { continue }
            perWord.append(.init(
                text: token,
                startTime: cmRange.start.seconds,
                endTime: cmRange.end.seconds,
                confidence: 1.0
            ))
        }
        // Fallback: if the SDK didn't attach audioTimeRange (some locales or
        // future SDK changes), emit the whole result as one segment so we
        // still advance completedRecognizedDuration and live-transcript.
        if perWord.isEmpty {
            perWord = [.init(
                text: String(attributed.characters),
                startTime: result.range.start.seconds,
                endTime: result.range.end.seconds,
                confidence: 1.0
            )]
        }
        state.recognizedSegments.append(contentsOf: perWord)

        let plainText = String(attributed.characters)
        if state.liveTranscriptText.isEmpty {
            state.liveTranscriptText = plainText
        } else {
            state.liveTranscriptText += " \(plainText)"
        }

        state.completedRecognizedDuration = max(state.completedRecognizedDuration, result.range.end.seconds)
    }

    /// Determines whether SpeechAnalyzer + SpeechTranscriber can transcribe in
    /// `locale` on this device, downloading the language model if needed.
    /// Returns the supported `Locale` to construct the transcriber with, or
    /// `nil` if the engine isn't usable (locale truly unsupported, simulator
    /// without model assets, model still downloading on another flow, etc.).
    /// Callers fall back to SFSpeechRecognizer on `nil`.
    private func prepareAnalyzerModel(for locale: Locale) async -> Locale? {
        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            return nil
        }
        let probe = SpeechTranscriber(locale: supportedLocale, preset: .progressiveTranscription)
        let status = await AssetInventory.status(forModules: [probe])
        switch status {
        case .installed:
            return supportedLocale
        case .supported:
            // Model is shippable but not on this device yet — try to fetch it.
            // If the request returns nil or download fails (e.g., simulator
            // doesn't carry the asset), surface `nil` so the caller falls back.
            do {
                guard let request = try await AssetInventory.assetInstallationRequest(supporting: [probe]) else {
                    return nil
                }
                try await request.downloadAndInstall()
                return supportedLocale
            } catch {
                return nil
            }
        case .downloading:
            // Another flow is already downloading; don't queue a second request.
            // Fall back this run; next analyze likely hits `.installed`.
            return nil
        case .unsupported:
            return nil
        @unknown default:
            return nil
        }
    }

    /// Delegate the transcribe-stream to the chunked SFSpeechRecognizer engine.
    /// Used when SpeechAnalyzer isn't usable on this device. State carries
    /// `engine == .sfSpeechRecognizer` (and a `#cloud`/`#local` namespaced
    /// sourceHash), so downstream cache/BG-resume paths Just Work.
    private func delegateToSF(input: URL,
                              continuation: AsyncThrowingStream<TranscriptionState, Error>.Continuation) async throws {
        let fallback = TranscriptionService(locale: locale)
        for try await state in await fallback.transcribe(input: input) {
            continuation.yield(state)
        }
    }
}
