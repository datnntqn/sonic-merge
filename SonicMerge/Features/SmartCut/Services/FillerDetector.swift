import Foundation

enum FillerDetector {

    /// Symmetric pad applied to each filler timeRange (in seconds).
    /// SFSpeechRecognizer's per-word timestamps cover the audible "core" of
    /// a word, often missing the leading consonant or trailing vowel. Cutting
    /// only the recognized window leaves audible residue of the spoken filler.
    /// The pad widens each timeRange so the cut fully removes the word; it is
    /// clamped to neighboring segments' boundaries so it never encroaches on
    /// adjacent (non-filler) speech.
    private static let timeRangePaddingSeconds: TimeInterval = 0.1

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
                    timeRange: paddedRange(spanStart: index, spanEnd: index, in: segments),
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
                        timeRange: paddedRange(spanStart: start,
                                               spanEnd: start + parts.count - 1,
                                               in: segments),
                        confidence: slice.map(\.confidence).reduce(0, +) / Float(parts.count),
                        contextExcerpt: contextExcerpt(around: start, in: segments),
                        isEnabled: enabledByDefault(phrase)
                    ))
                }
            }
        }

        return edits.sorted { $0.timeRange.lowerBound < $1.timeRange.lowerBound }
    }

    /// Build a timeRange covering segments[spanStart...spanEnd], padded by
    /// `timeRangePaddingSeconds` on each side. The pad is clamped to the
    /// previous segment's endTime (or 0 if first) and the next segment's
    /// startTime (or unbounded if last) so it never overlaps adjacent words.
    private static func paddedRange(spanStart: Int,
                                    spanEnd: Int,
                                    in segments: [TranscriptionState.RecognizedSegment]) -> ClosedRange<TimeInterval> {
        let originalStart = segments[spanStart].startTime
        let originalEnd = segments[spanEnd].endTime
        let leftBound: TimeInterval = spanStart > 0 ? segments[spanStart - 1].endTime : 0
        let rightBound: TimeInterval = spanEnd < segments.count - 1
            ? segments[spanEnd + 1].startTime
            : .infinity
        let paddedStart = max(leftBound, originalStart - timeRangePaddingSeconds)
        let paddedEnd = min(rightBound, originalEnd + timeRangePaddingSeconds)
        return paddedStart...paddedEnd
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
