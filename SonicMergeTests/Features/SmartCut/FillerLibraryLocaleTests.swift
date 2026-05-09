import Testing
import Foundation
@testable import SonicMerge

struct FillerLibraryLocaleTests {

    private func freshLibrary() -> FillerLibrary {
        let suite = "FillerLibraryLocaleTests-\(UUID().uuidString)"
        return FillerLibrary(defaults: UserDefaults(suiteName: suite)!)
    }

    @Test func englishDefaultsForEnUS() {
        let lib = freshLibrary()
        let words = lib.defaultOffWords(for: Locale(identifier: "en-US"))
        #expect(words.contains("you know"))
        #expect(words.contains("like"))
    }

    @Test func englishDefaultsForEnGB() {
        // Any en-* region falls back to en defaults.
        let lib = freshLibrary()
        let words = lib.defaultOffWords(for: Locale(identifier: "en-GB"))
        #expect(words.contains("you know"))
    }

    @Test func spanishDefaultsForEsES() {
        let lib = freshLibrary()
        let words = lib.defaultOffWords(for: Locale(identifier: "es-ES"))
        #expect(words.contains("este"))
        #expect(words.contains("o sea"))
    }

    @Test func spanishDefaultsForEsMX() {
        // Any es-* region falls back to es defaults.
        let lib = freshLibrary()
        let words = lib.defaultOffWords(for: Locale(identifier: "es-MX"))
        #expect(words.contains("este"))
    }

    @Test func portugueseDefaultsForPtBR() {
        let lib = freshLibrary()
        let words = lib.defaultOffWords(for: Locale(identifier: "pt-BR"))
        #expect(words.contains("tipo"))
        #expect(words.contains("né"))
    }

    @Test func frenchDefaultsForFrFR() {
        let lib = freshLibrary()
        let words = lib.defaultOffWords(for: Locale(identifier: "fr-FR"))
        #expect(words.contains("euh"))
        #expect(words.contains("du coup"))
    }

    @Test func emptyDefaultsForKorean() {
        let lib = freshLibrary()
        let words = lib.defaultOffWords(for: Locale(identifier: "ko-KR"))
        #expect(words.isEmpty)
    }

    @Test func customWordsAppearAcrossAllLocales() {
        var lib = freshLibrary()
        lib.addCustom("anyway")
        let en = lib.allWords(for: Locale(identifier: "en-US"))
        let es = lib.allWords(for: Locale(identifier: "es-ES"))
        let ko = lib.allWords(for: Locale(identifier: "ko-KR"))
        #expect(en.contains("anyway"))
        #expect(es.contains("anyway"))
        #expect(ko.contains("anyway"))
    }

    @Test func removingDefaultPersistsAcrossLocales() {
        // Spec: customWords + removedDefaults are global. Removing "tipo" while
        // pt-BR removes it everywhere — including es-ES (which also has "tipo").
        var lib = freshLibrary()
        lib.remove("tipo")
        let pt = lib.allWords(for: Locale(identifier: "pt-BR"))
        let es = lib.allWords(for: Locale(identifier: "es-ES"))
        #expect(!pt.contains("tipo"))
        #expect(!es.contains("tipo"))
    }
}
