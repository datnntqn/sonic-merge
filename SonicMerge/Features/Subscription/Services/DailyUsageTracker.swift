import Foundation

/// Tracks daily usage counters per AI feature. UserDefaults-backed. The
/// "today" key changes at midnight (local calendar), so counts reset
/// implicitly without us writing reset logic. Date and calendar are
/// injectable so tests can fake "tomorrow."
final class DailyUsageTracker {

    enum Feature: String, Sendable {
        case smartCut = "smartCut"
        case denoise = "denoise"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let dateProvider: () -> Date

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.dateProvider = dateProvider
    }

    func count(for feature: Feature) -> Int {
        defaults.integer(forKey: key(for: feature))
    }

    func increment(_ feature: Feature) {
        let k = key(for: feature)
        defaults.set(defaults.integer(forKey: k) + 1, forKey: k)
    }

    private func key(for feature: Feature) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: dateProvider())
        let dateKey = "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        return "DailyUsage.\(feature.rawValue).\(dateKey)"
    }
}
