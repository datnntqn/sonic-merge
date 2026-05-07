import Foundation

/// Persistence layer for review-prompt gating metrics. UserDefaults-backed.
/// `installDate` lazy-initializes on first read so it tracks "first-app-open"
/// rather than "binary install" — better UX semantics for cooldown reasoning.
@MainActor
final class ReviewMetricsStore {

    private enum Key {
        static let installDate = "ReviewMetrics.installDate"
        static let exportCount = "ReviewMetrics.exportCount"
        static let lastPromptDate = "ReviewMetrics.lastPromptDate"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var installDate: Date {
        if let stored = defaults.object(forKey: Key.installDate) as? Date {
            return stored
        }
        let now = Date()
        defaults.set(now, forKey: Key.installDate)
        return now
    }

    var exportCount: Int {
        defaults.integer(forKey: Key.exportCount)
    }

    func incrementExportCount() {
        defaults.set(exportCount + 1, forKey: Key.exportCount)
    }

    var lastPromptDate: Date? {
        get { defaults.object(forKey: Key.lastPromptDate) as? Date }
        set { defaults.set(newValue, forKey: Key.lastPromptDate) }
    }
}
