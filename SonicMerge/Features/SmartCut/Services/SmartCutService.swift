import Foundation

actor SmartCutService {

    /// Streamed updates from `analyze`.
    enum Update: Sendable {
        case progress(Double)        // 0...1
        case completed(EditList)
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
                    let fillers = FillerDetector.detect(
                        in: state.recognizedSegments,
                        words: library.allWords,
                        enabledByDefault: { library.isEnabledByDefault($0) }
                    )
                    let pauses = PauseDetector.detect(
                        in: state.recognizedSegments,
                        totalDuration: state.sourceDuration,
                        threshold: pauseThreshold
                    )
                    let editList = EditList(fillers: fillers, pauses: pauses)
                    continuation.yield(.completed(editList))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
