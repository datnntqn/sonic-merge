import Testing
import Foundation
@testable import SonicMerge

struct DailyUsageTrackerTests {

    private func freshTracker() -> (DailyUsageTracker, UserDefaults) {
        let suite = "DailyUsageTrackerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let tracker = DailyUsageTracker(
            defaults: defaults,
            calendar: Calendar(identifier: .gregorian),
            dateProvider: { Date(timeIntervalSince1970: 1714824000) }  // 2024-05-04
        )
        return (tracker, defaults)
    }

    @Test func defaultCountIsZero() {
        let (tracker, _) = freshTracker()
        #expect(tracker.count(for: .smartCut) == 0)
        #expect(tracker.count(for: .denoise) == 0)
    }

    @Test func incrementBumpsCount() {
        let (tracker, _) = freshTracker()
        tracker.increment(.smartCut)
        tracker.increment(.smartCut)
        #expect(tracker.count(for: .smartCut) == 2)
        #expect(tracker.count(for: .denoise) == 0)
    }

    @Test func newDayResetsCount() {
        let suite = "DailyUsageTrackerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let calendar = Calendar(identifier: .gregorian)
        var fakeDate = Date(timeIntervalSince1970: 1714824000)  // 2024-05-04
        let dateProvider: () -> Date = { fakeDate }
        let tracker = DailyUsageTracker(
            defaults: defaults,
            calendar: calendar,
            dateProvider: dateProvider
        )
        tracker.increment(.smartCut)
        tracker.increment(.smartCut)
        #expect(tracker.count(for: .smartCut) == 2)
        // Advance the clock by 24h
        fakeDate = Date(timeIntervalSince1970: 1714910400)  // 2024-05-05
        #expect(tracker.count(for: .smartCut) == 0)
    }
}
