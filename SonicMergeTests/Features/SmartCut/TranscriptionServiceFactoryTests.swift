import Testing
import Foundation
@testable import SonicMerge

struct TranscriptionServiceFactoryTests {

    @Test func makeReturnsServiceConformingToTranscriptionServicing_explicitLocale() {
        let service: any TranscriptionServicing =
            TranscriptionServiceFactory.make(localeIdentifier: "en-US")
        #expect(service is TranscriptionService || isSpeechAnalyzerService(service))
    }

    @Test func makeReturnsServiceConformingToTranscriptionServicing_autoSentinel() {
        let service: any TranscriptionServicing =
            TranscriptionServiceFactory.make(localeIdentifier: "auto")
        // On iOS 17–25 this falls through to TranscriptionService (SF) per the
        // defensive branch in the factory. On iOS 26+ it returns SpeechAnalyzer.
        #expect(service is TranscriptionService || isSpeechAnalyzerService(service))
    }

    @Test func makeReturnsServiceConformingToTranscriptionServicing_unknownLocale() {
        // Unknown locale strings are still accepted by the factory; the underlying
        // service may throw at transcribe time. Factory itself should not throw.
        let service: any TranscriptionServicing =
            TranscriptionServiceFactory.make(localeIdentifier: "xx-ZZ")
        #expect(service is TranscriptionService || isSpeechAnalyzerService(service))
    }

    /// Type-erased check that survives whether SpeechAnalyzerTranscriptionService
    /// exists yet. Returns false in Chunk 2 where the type isn't compiled.
    /// Chunk 3 restores the iOS-26 check once the type exists.
    private func isSpeechAnalyzerService(_ service: any TranscriptionServicing) -> Bool {
        return false
    }
}
