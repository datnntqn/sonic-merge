import Foundation

/// One detected silence longer than the user's threshold.
struct PauseEdit: Hashable, Codable, Identifiable {
    let id: String
    let timeRange: ClosedRange<TimeInterval>
    /// Convenience: timeRange.upperBound - timeRange.lowerBound
    var duration: TimeInterval { timeRange.upperBound - timeRange.lowerBound }
    var isEnabled: Bool

    init(timeRange: ClosedRange<TimeInterval>, isEnabled: Bool) {
        self.timeRange = timeRange
        self.isEnabled = isEnabled
        self.id = "pause@\(timeRange.lowerBound)"
    }
}
