import Foundation

actor SmartCutService {

    /// Streamed updates from `analyze`.
    enum Update: Sendable {
        case progress(Double)        // 0...1
        case completed(EditList, segments: [TranscriptionState.RecognizedSegment], duration: TimeInterval)
    }

    private let library: FillerLibrary
    private let pauseThreshold: TimeInterval
    private let transcriptionService: TranscriptionService

    init(library: FillerLibrary,
         pauseThreshold: TimeInterval = 1.5,
         transcriptionService: TranscriptionService = TranscriptionService()) {
        self.library = library
        self.pauseThreshold = pauseThreshold
        self.transcriptionService = transcriptionService
    }

    func analyze(input: URL) -> AsyncThrowingStream<Update, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var lastState: TranscriptionState?
                    for try await state in await transcriptionService.transcribe(input: input) {
                        continuation.yield(.progress(state.progressFraction))
                        lastState = state
                    }
                    guard let state = lastState else {
                        continuation.finish(throwing: NSError(domain: "SmartCutService", code: -1))
                        return
                    }
                    let lexicalFillers = FillerDetector.detect(
                        in: state.recognizedSegments,
                        words: library.allWords,
                        enabledByDefault: { library.isEnabledByDefault($0) }
                    )
                    // Audio-based disfluency detection: catches um/uh/ah/oh
                    // that SFSpeechRecognizer's on-device model drops. Runs
                    // on the audio waveform in the gaps between recognized
                    // segments, so it doesn't double-count anything the
                    // lexical FillerDetector already found.
                    let disfluencies = (try? DisfluencyDetector.detect(
                        audioURL: input,
                        recognizedSegments: state.recognizedSegments,
                        totalDuration: state.sourceDuration
                    )) ?? []
                    let fillers = (lexicalFillers + disfluencies)
                        .sorted { $0.timeRange.lowerBound < $1.timeRange.lowerBound }
                    let pauses = PauseDetector.detect(
                        in: state.recognizedSegments,
                        totalDuration: state.sourceDuration,
                        threshold: pauseThreshold
                    )
                    let editList = EditList(fillers: fillers, pauses: pauses)
                    continuation.yield(.completed(editList, segments: state.recognizedSegments, duration: state.sourceDuration))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
