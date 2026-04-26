import Foundation

enum FillerDetector {

    /// Walk the recognized segments and emit a FillerEdit for every match.
    /// Multi-word phrases (e.g. "you know") match across consecutive segments.
    static func detect(in segments: [TranscriptionState.RecognizedSegment],
                       words: [String],
                       enabledByDefault: (String) -> Bool) -> [FillerEdit] {
        guard !segments.isEmpty, !words.isEmpty else { return [] }

        let normalizedWords = words.map { $0.lowercased() }
        // Single vs. multi-word lookup: single = O(1) set check; multi = brute scan.
        let singleWords = Set(normalizedWords.filter { !$0.contains(" ") })
        let multiWords = normalizedWords.filter { $0.contains(" ") }

        var edits: [FillerEdit] = []

        for (index, segment) in segments.enumerated() {
            let cleaned = normalize(segment.text)
            if singleWords.contains(cleaned) {
                edits.append(FillerEdit(
                    matchedText: cleaned,
                    timeRange: segment.startTime...segment.endTime,
                    confidence: segment.confidence,
                    contextExcerpt: contextExcerpt(around: index, in: segments),
                    isEnabled: enabledByDefault(cleaned)
                ))
            }
        }

        // Multi-word: slide a window over consecutive segments.
        for phrase in multiWords {
            let parts = phrase.split(separator: " ").map(String.init)
            guard !parts.isEmpty, segments.count >= parts.count else { continue }
            for start in 0...(segments.count - parts.count) {
                let slice = segments[start..<(start + parts.count)]
                let words = slice.map { normalize($0.text) }
                if words == parts {
                    edits.append(FillerEdit(
                        matchedText: phrase,
                        timeRange: slice.first!.startTime...slice.last!.endTime,
                        confidence: slice.map(\.confidence).reduce(0, +) / Float(parts.count),
                        contextExcerpt: contextExcerpt(around: start, in: segments),
                        isEnabled: enabledByDefault(phrase)
                    ))
                }
            }
        }

        return edits.sorted { $0.timeRange.lowerBound < $1.timeRange.lowerBound }
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
    }

    /// Builds "...so um, the thing is..." excerpt with up to 3 words on each side.
    private static func contextExcerpt(around index: Int,
                                       in segments: [TranscriptionState.RecognizedSegment]) -> String {
        let lower = max(0, index - 3)
        let upper = min(segments.count - 1, index + 3)
        let words = segments[lower...upper].map(\.text)
        return "...\(words.joined(separator: " "))..."
    }
}
