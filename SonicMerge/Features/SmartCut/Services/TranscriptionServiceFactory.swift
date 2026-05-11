import Foundation

/// Single entry point for choosing between the legacy chunked
/// `TranscriptionService` (SFSpeechRecognizer, iOS 17–25) and the long-form
/// `SpeechAnalyzerTranscriptionService` (iOS 26+). The only `#available(iOS 26, *)`
/// site in the engine-selection path; UI files have their own gates.
enum TranscriptionServiceFactory {
    static func make(localeIdentifier: String) -> any TranscriptionServicing {
        if #available(iOS 26, *) {
            return SpeechAnalyzerTranscriptionService(locale: Locale(identifier: localeIdentifier))
        }
        return TranscriptionService(locale: Locale(identifier: localeIdentifier))
    }
}
