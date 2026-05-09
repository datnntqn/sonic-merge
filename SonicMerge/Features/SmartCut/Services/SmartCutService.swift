import Foundation

actor SmartCutService {

    /// Streamed updates from `analyze`.
    enum Update: Sendable {
        case progress(Double)        // 0...1
        case completed(EditList, segments: [TranscriptionState.RecognizedSegment], duration: TimeInterval)
    }

    private let library: FillerLibrary
    private let transcriptionServiceFactory: (Locale) -> any TranscriptionServicing

    init(library: FillerLibrary,
         transcriptionServiceFactory: @escaping (Locale) -> any TranscriptionServicing
            = { locale in TranscriptionService(locale: locale) }) {
        self.library = library
        self.transcriptionServiceFactory = transcriptionServiceFactory
    }

    func analyze(input: URL,
                 pauseThreshold: TimeInterval,
                 locale: Locale) -> AsyncThrowingStream<Update, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let transcriptionService = transcriptionServiceFactory(locale)
                    var lastState: TranscriptionState?
                    for try await state in await transcriptionService.transcribe(input: input) {
                        continuation.yield(.progress(state.progressFraction))
                        lastState = state
                    }
                    guard let state = lastState else {
                        continuation.finish(throwing: NSError(domain: "SmartCutService", code: -1))
                        return
                    }
                    let fillers = FillerDetector.detect(
                        in: state.recognizedSegments,
                        words: library.allWords(for: locale),
                        enabledByDefault: { library.isEnabledByDefault($0) }
                    )
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
