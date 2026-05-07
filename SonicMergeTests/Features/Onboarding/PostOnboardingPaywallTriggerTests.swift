import Testing
@testable import SonicMerge

@MainActor
struct PostOnboardingPaywallTriggerTests {

    @Test func freshCompletionFiresReason() {
        let reason = RootTabView.PostOnboardingTrigger.reasonOnCompletion(
            previous: false, current: true
        )
        #expect(reason == .endOfOnboarding)
    }

    @Test func staysOnboardedIsNoop() {
        let reason = RootTabView.PostOnboardingTrigger.reasonOnCompletion(
            previous: true, current: true
        )
        #expect(reason == nil)
    }

    @Test func unsetOnboardedIsNoop() {
        let reason = RootTabView.PostOnboardingTrigger.reasonOnCompletion(
            previous: true, current: false
        )
        #expect(reason == nil)
    }

    @Test func uninitializedStateIsNoop() {
        let reason = RootTabView.PostOnboardingTrigger.reasonOnCompletion(
            previous: false, current: false
        )
        #expect(reason == nil)
    }
}
