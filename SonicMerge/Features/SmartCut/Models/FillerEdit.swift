import Foundation

/// One detected occurrence of a filler word in the audio.
/// Identity = (matchedText, timeRange.start) — uniqueness is needed for
/// SwiftUI ForEach and per-row toggle persistence in EditList.
struct FillerEdit: Hashable, Codable, Identifiable {
    /// Stable id derived from matchedText + start. Recomputed on init.
    let id: String

    /// The exact filler text matched (lowercased), e.g. "um", "you know".
    let matchedText: String

    /// Time range to remove from the source audio.
    let timeRange: ClosedRange<TimeInterval>

    /// The recognizer's confidence for the segment that produced this match (0...1).
    /// Used for ordering / UI hint, not a filter — we trust user curation.
    let confidence: Float

    /// Short context excerpt from the transcript, e.g. "...so um, the thing is...".
    let contextExcerpt: String

    /// User toggle. Default depends on whether matchedText is in the
    /// default-on or default-off set (resolved by FillerLibrary at construction).
    var isEnabled: Bool

    init(matchedText: String,
         timeRange: ClosedRange<TimeInterval>,
         confidence: Float,
         contextExcerpt: String,
         isEnabled: Bool) {
        self.matchedText = matchedText
        self.timeRange = timeRange
        self.confidence = confidence
        self.contextExcerpt = contextExcerpt
        self.isEnabled = isEnabled
        self.id = "\(matchedText)@\(timeRange.lowerBound)"
    }
}
