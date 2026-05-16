import Foundation
import Network

/// Single entry point for choosing a transcription engine. Defers the actual
/// choice until `transcribe(input:)` is called, so we can consult network
/// availability + the user's cloud-recognition toggle without making the
/// (synchronous) factory closure itself async.
///
/// Routing matrix (after [.timeIndexedProgressiveTranscription] preset on
/// SpeechAnalyzer made on-device per-word work):
///
///   useCloudRecognition toggle == true (default) && network available
///     → TranscriptionService (SFSpeechRecognizer cloud — best quality)
///
///   otherwise (toggle off, or offline)
///     → iOS 26+: SpeechAnalyzerTranscriptionService (on-device, per-word)
///     → iOS 17–25: TranscriptionService (SFSpeechRecognizer on-device —
///       known quality limitations on disfluences + per-word timestamps)
enum TranscriptionServiceFactory {
    static func make(localeIdentifier: String) -> any TranscriptionServicing {
        RoutedTranscriptionService(locale: Locale(identifier: localeIdentifier))
    }
}

/// Wraps the engine-selection decision so callers see one TranscriptionServicing
/// while we defer the network probe + toggle read to invocation time.
actor RoutedTranscriptionService: TranscriptionServicing {
    private let locale: Locale

    init(locale: Locale) {
        self.locale = locale
    }

    nonisolated func transcribe(input: URL) -> AsyncThrowingStream<TranscriptionState, Error> {
        AsyncThrowingStream { continuation in
            Task { [locale] in
                let wantCloud = TranscriptionService.useCloudRecognitionDefault()
                let hasNetwork = wantCloud ? await NetworkAvailability.isReachable() : false
                let engine: any TranscriptionServicing
                if wantCloud && hasNetwork {
                    // TranscriptionService consults useCloudRecognitionDefault()
                    // internally per recognition request, so cloud is what runs.
                    engine = TranscriptionService(locale: locale)
                } else if #available(iOS 26, *) {
                    engine = SpeechAnalyzerTranscriptionService(locale: locale)
                } else {
                    // iOS 17–25 with no cloud path available: fall back to SF
                    // on-device. Caller (SmartCutService) will surface the
                    // known quality limits if the user complains.
                    engine = TranscriptionService(locale: locale)
                }
                do {
                    for try await state in await engine.transcribe(input: input) {
                        continuation.yield(state)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

/// One-shot wrapper over NWPathMonitor. `pathUpdateHandler` always fires at
/// least once after `start(queue:)` with the current path, so we resolve the
/// continuation on the first callback and cancel the monitor.
enum NetworkAvailability {
    static func isReachable() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "NetworkAvailability.probe")
            let didResume = ResumeFlag()
            monitor.pathUpdateHandler = { path in
                guard didResume.set() else { return }
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: queue)
        }
    }

    /// Single-fire latch so NWPathMonitor's `pathUpdateHandler` (which can
    /// fire repeatedly) only resumes the continuation once.
    private final class ResumeFlag: @unchecked Sendable {
        private var fired = false
        private let lock = NSLock()
        func set() -> Bool {
            lock.lock(); defer { lock.unlock() }
            guard !fired else { return false }
            fired = true
            return true
        }
    }
}
