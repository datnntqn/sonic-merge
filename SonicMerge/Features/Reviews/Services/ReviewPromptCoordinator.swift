import Foundation

/// Decides when to present the post-export mood-check sheet. Profile B
/// gating: install ≥ 3 days, exports ≥ 3, 90-day cooldown since last prompt,
/// no paywall shown this session (mutex with `PaywallTriggerCoordinator`).
@MainActor
@Observable
final class ReviewPromptCoordinator {

    enum Threshold {
        static let minInstallDays = 3
        static let minExportCount = 3
        static let cooldownDays = 90
    }

    private let metrics: ReviewMetricsStore
    private let paywallCoordinator: PaywallTriggerCoordinator

    init(metrics: ReviewMetricsStore, paywallCoordinator: PaywallTriggerCoordinator) {
        self.metrics = metrics
        self.paywallCoordinator = paywallCoordinator
    }

    func recordExport() {
        metrics.incrementExportCount()
    }

    func markPrompted() {
        metrics.lastPromptDate = Date()
    }

    func shouldPromptNow(now: Date = .init()) -> Bool {
        if paywallCoordinator.hasShownPaywallThisSession { return false }

        if metrics.exportCount < Threshold.minExportCount { return false }

        let installAge = now.timeIntervalSince(metrics.installDate)
        let minInstallSeconds = Double(Threshold.minInstallDays) * 86400
        if installAge < minInstallSeconds { return false }

        if let last = metrics.lastPromptDate {
            let elapsed = now.timeIntervalSince(last)
            if elapsed < 0 { return false }
            let cooldownSeconds = Double(Threshold.cooldownDays) * 86400
            if elapsed < cooldownSeconds { return false }
        }

        return true
    }
}
