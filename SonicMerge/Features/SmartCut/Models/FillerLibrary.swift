import Foundation

/// Words Smart Cut considers fillers. Two tiers:
/// - `defaultOnWords` — shipped, on by default in EditList (verbal hesitations only).
/// - `defaultOffWords(for:)` — shipped, off by default; per-locale.
/// User additions land in `customWords` (off by default).
/// User can also remove default words; their removal is persisted globally
/// (across locales — see file-header rationale in
/// docs/superpowers/specs/2026-05-09-multi-language-smart-cut-design.md
/// "Per-locale custom word lists" Non-Goal).
struct FillerLibrary: Equatable {
    let defaults: UserDefaults

    /// Empty by default. The on-device SFSpeechRecognizer is unreliable on
    /// short hesitation tokens ("um", "uh", "ah", "er", "oh") — it frequently
    /// drops or mistags them, producing inconsistent Smart Cut results that
    /// erode user trust. Rather than ship false confidence, ship nothing
    /// on by default and let the user opt in via the Edit list sheet
    /// (custom-added words are off-by-default; users explicitly enable them).
    let defaultOnWords: [String] = []

    /// SPEC: standard set, off by default — pulled in when the user opts in.
    /// Lookup by language code only (region-insensitive: "en-GB" → "en").
    /// "como" and "tipo" in Spanish are flagged as high-collision (they have
    /// common non-filler senses); manual QA verifies the false-positive rate.
    private static let defaultsByLanguage: [String: [String]] = [
        "en": ["like", "you know", "sort of", "basically", "actually", "literally"],
        "es": ["este", "eh", "o sea", "pues", "tipo", "como"],
        "pt": ["tipo", "né", "então", "sabe", "meio que"],
        "fr": ["euh", "ben", "genre", "en fait", "du coup", "tu sais"]
    ]

    private let customKey = "SmartCut.FillerLibrary.customWords"
    private let removedKey = "SmartCut.FillerLibrary.removedDefaults"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var customWords: [String] {
        defaults.array(forKey: customKey) as? [String] ?? []
    }

    var removedDefaults: Set<String> {
        Set(defaults.array(forKey: removedKey) as? [String] ?? [])
    }

    /// Default-off list for the given locale. Falls back to `[]` for
    /// uncurated languages (callers should still get pause detection +
    /// custom words elsewhere).
    func defaultOffWords(for locale: Locale) -> [String] {
        let code = locale.language.languageCode?.identifier ?? "en"
        return Self.defaultsByLanguage[code] ?? []
    }

    /// Combined list (per-locale defaults minus removed + global custom),
    /// preserving order. Deduped against the kept-defaults set.
    func allWords(for locale: Locale) -> [String] {
        let removed = removedDefaults
        let kept = (defaultOnWords + defaultOffWords(for: locale)).filter { !removed.contains($0) }
        let keptSet = Set(kept)
        let uniqueCustom = customWords.filter { !keptSet.contains($0) }
        return kept + uniqueCustom
    }

    func isEnabledByDefault(_ word: String) -> Bool {
        defaultOnWords.contains(word)
    }

    mutating func addCustom(_ word: String) {
        let normalized = word.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else { return }
        // Dedupe against ALL curated defaults (across all locales) plus existing
        // custom — adding "tipo" while editing English shouldn't collide with
        // the Spanish/Portuguese curated default.
        let allDefaultWords = Set(Self.defaultsByLanguage.values.flatMap { $0 })
        guard !allDefaultWords.contains(normalized) else { return }
        guard !customWords.contains(normalized) else { return }
        var current = customWords
        current.append(normalized)
        defaults.set(current, forKey: customKey)
    }

    mutating func remove(_ word: String) {
        let normalized = word.lowercased().trimmingCharacters(in: .whitespaces)
        if customWords.contains(normalized) {
            defaults.set(customWords.filter { $0 != normalized }, forKey: customKey)
            return
        }
        // If the word is a curated default (in any locale), persist the
        // removal globally — matches the spec's global-state-for-removals
        // decision. Re-curated defaults across all locales hide it.
        let allDefaultWords = Set(Self.defaultsByLanguage.values.flatMap { $0 })
        if allDefaultWords.contains(normalized) {
            var removed = removedDefaults
            removed.insert(normalized)
            defaults.set(Array(removed), forKey: removedKey)
        }
    }

    /// Phase 12 (existing API): clear the persisted set of removed default
    /// words. Custom words are not affected.
    mutating func restoreAllDefaults() {
        defaults.removeObject(forKey: removedKey)
    }
}
