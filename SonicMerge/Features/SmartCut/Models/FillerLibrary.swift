import Foundation

/// Words Smart Cut considers fillers. Two tiers:
/// - `defaultOnWords` — shipped, on by default in EditList (verbal hesitations only).
/// - `defaultOffWords` — shipped, off by default (ambiguous-as-real-word).
/// User additions land in `customWords` (off by default).
/// User can also remove default words; their removal is persisted.
struct FillerLibrary: Equatable {
    let defaults: UserDefaults

    /// SPEC: tight set, on by default — never false-positives a real word.
    let defaultOnWords: [String] = ["um", "uh", "ah", "er"]

    /// SPEC: standard set, off by default — pulled in when the user opts in.
    let defaultOffWords: [String] = ["like", "you know", "sort of", "basically", "actually", "literally"]

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

    /// Combined list (defaults minus removed + custom), preserving order.
    var allWords: [String] {
        let removed = removedDefaults
        let kept = (defaultOnWords + defaultOffWords).filter { !removed.contains($0) }
        return kept + customWords
    }

    func isEnabledByDefault(_ word: String) -> Bool {
        defaultOnWords.contains(word)
    }

    mutating func addCustom(_ word: String) {
        let normalized = word.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else { return }
        guard !allWords.contains(normalized) else { return }
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
        if (defaultOnWords + defaultOffWords).contains(normalized) {
            var removed = removedDefaults
            removed.insert(normalized)
            defaults.set(Array(removed), forKey: removedKey)
        }
    }
}
