import Testing
import Foundation
import Speech
@testable import SonicMerge

struct TranscriptionServiceLocaleTests {

    /// Pure-data test: the helper that resolves an unsupported locale to en-US.
    /// We test the fallback rule, not the recognizer (avoids the FAIL=5
    /// flake-class).
    @Test func unsupportedLocaleFallsBackToEnUS() {
        let unsupported = Locale(identifier: "xx-YY")  // not a real BCP-47 locale
        let resolved = TranscriptionService.resolveSupportedLocale(unsupported)
        #expect(resolved.identifier == "en-US")
    }

    @Test func supportedLocalePassesThrough() {
        // en-US is always in supportedLocales() on iOS.
        let supported = Locale(identifier: "en-US")
        let resolved = TranscriptionService.resolveSupportedLocale(supported)
        #expect(resolved.identifier == "en-US")
    }

    @Test func spanishPassesThrough() {
        // es-ES is in supportedLocales() — Apple ships Spanish on iOS 17+.
        let supported = Locale(identifier: "es-ES")
        let resolved = TranscriptionService.resolveSupportedLocale(supported)
        #expect(resolved.language.languageCode?.identifier == "es")
    }
}
