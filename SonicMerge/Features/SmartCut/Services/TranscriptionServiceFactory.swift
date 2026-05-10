import Foundation

/// Single entry point for choosing between the legacy chunked
/// `TranscriptionService` (SFSpeechRecognizer, iOS 17–25) and the long-form
/// `SpeechAnalyzerTranscriptionService` (iOS 26+). The only `#available(iOS 26, *)`
/// site in the engine-selection path; UI files have their own gates.
///
/// `localeIdentifier == "auto"` is a sentinel meaning "let SpeechAnalyzer
/// auto-detect bilingual audio." On iOS 17–25 it falls back to en-US SF
/// defensively (LocalePicker only emits "auto" on iOS 26).
enum TranscriptionServiceFactory {
    static func make(localeIdentifier: String) -> any TranscriptionServicing {
        if localeIdentifier == "auto" {
            // Chunk 3 wires SpeechAnalyzerTranscriptionService here. Until then,
            // both branches return SF. The defensive en-US fallback for iOS 17–25
            // stays as the permanent behavior for that branch.
            return TranscriptionService(locale: Locale(identifier: "en-US"))
        }
        return TranscriptionService(locale: Locale(identifier: localeIdentifier))
    }
}
