import Foundation

/// User-curated bundle of FillerEdits and PauseEdits.
/// Toggles propagate from category → children; individual toggles do not affect category.
/// The category UI checkbox shows .on / .off / .mixed based on the children's states.
struct EditList: Hashable, Codable {
    var fillers: [FillerEdit]
    var pauses: [PauseEdit]

    enum CategoryState: Hashable, Codable { case on, off, mixed }

    init(fillers: [FillerEdit] = [], pauses: [PauseEdit] = []) {
        self.fillers = fillers
        self.pauses = pauses
    }

    /// Categories in insertion order of first occurrence (used for stable UI rendering).
    var categories: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for f in fillers where seen.insert(f.matchedText).inserted {
            ordered.append(f.matchedText)
        }
        return ordered
    }

    /// Sum of enabled edits' durations, in seconds.
    var enabledSavings: TimeInterval {
        let fillerSum = fillers.filter(\.isEnabled).reduce(0.0) { acc, e in
            acc + (e.timeRange.upperBound - e.timeRange.lowerBound)
        }
        let pauseSum = pauses.filter(\.isEnabled).reduce(0.0) { acc, p in
            acc + p.duration
        }
        return fillerSum + pauseSum
    }

    func categoryState(for category: String) -> CategoryState {
        let group = fillers.filter { $0.matchedText == category }
        let onCount = group.filter(\.isEnabled).count
        if onCount == 0 { return .off }
        if onCount == group.count { return .on }
        return .mixed
    }

    /// Flip every filler in the given category to `enabled`.
    mutating func setCategory(_ category: String, enabled: Bool) {
        for i in fillers.indices where fillers[i].matchedText == category {
            fillers[i].isEnabled = enabled
        }
    }

    /// Flip a single filler or pause by id.
    mutating func setEdit(id: String, enabled: Bool) {
        if let i = fillers.firstIndex(where: { $0.id == id }) {
            fillers[i].isEnabled = enabled
            return
        }
        if let i = pauses.firstIndex(where: { $0.id == id }) {
            pauses[i].isEnabled = enabled
        }
    }

    /// All enabled time-ranges, sorted by start. Used by AudioCutter.
    var enabledCutRanges: [ClosedRange<TimeInterval>] {
        let f = fillers.filter(\.isEnabled).map(\.timeRange)
        let p = pauses.filter(\.isEnabled).map(\.timeRange)
        return (f + p).sorted { $0.lowerBound < $1.lowerBound }
    }
}
