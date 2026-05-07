import Testing
@testable import SonicMerge

struct PaywallViewBodyTests {

    /// Sanity that all `PaywallReason` cases produce a non-empty headline —
    /// guards against someone adding a new case and forgetting to update the
    /// switch in `PaywallView.headlineCopy(for:)`.
    @Test func everyReasonHasHeadline() {
        let cases: [PaywallReason] = [
            .endOfOnboarding, .hitDailyCap, .hitLengthCap,
            .watermarkExport, .settingsUpgrade, .trialExpired
        ]
        for reason in cases {
            let headline = PaywallView.headlineCopy(for: reason)
            #expect(!headline.isEmpty, "Reason \(reason) is missing a headline")
        }
    }

    @Test func endOfOnboardingHeadlineIsNotRestrictiveCopy() {
        let headline = PaywallView.headlineCopy(for: .endOfOnboarding).lowercased()
        #expect(!headline.contains("limit reached"))
        #expect(!headline.contains("cap"))
    }
}
