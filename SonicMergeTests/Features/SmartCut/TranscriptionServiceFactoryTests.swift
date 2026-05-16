import Testing
import Foundation
@testable import SonicMerge

struct TranscriptionServiceFactoryTests {

    @Test func makeReturnsServiceConformingToTranscriptionServicing_explicitLocale() {
        let service: any TranscriptionServicing =
            TranscriptionServiceFactory.make(localeIdentifier: "en-US")
        #expect(isAcceptedEngine(service))
    }

    @Test func makeReturnsServiceConformingToTranscriptionServicing_autoSentinel() {
        let service: any TranscriptionServicing =
            TranscriptionServiceFactory.make(localeIdentifier: "auto")
        #expect(isAcceptedEngine(service))
    }

    @Test func makeReturnsServiceConformingToTranscriptionServicing_unknownLocale() {
        // Unknown locale strings are still accepted by the factory; the underlying
        // service may throw at transcribe time. Factory itself should not throw.
        let service: any TranscriptionServicing =
            TranscriptionServiceFactory.make(localeIdentifier: "xx-ZZ")
        #expect(isAcceptedEngine(service))
    }

    /// Factory now returns a RoutedTranscriptionService wrapper that defers the
    /// engine choice (cloud vs SpeechAnalyzer vs SF on-device) until transcribe
    /// time so it can consult network availability + the user's cloud toggle.
    /// Direct TranscriptionService or SpeechAnalyzerTranscriptionService returns
    /// remain valid for any future paths that bypass the router.
    private func isAcceptedEngine(_ service: any TranscriptionServicing) -> Bool {
        if service is RoutedTranscriptionService { return true }
        if service is TranscriptionService { return true }
        if #available(iOS 26, *), service is SpeechAnalyzerTranscriptionService { return true }
        return false
    }
}
