import Testing
@testable import SonicMerge

struct ProFeatureTests {

    @Test func allCasesEnumerated() {
        let _: ProFeature = .smartCutSession
        let _: ProFeature = .smartCutLength(seconds: 600)
        let _: ProFeature = .denoiseSession
        let _: ProFeature = .denoiseLength(seconds: 600)
        let _: ProFeature = .mergeClipCount(count: 5)
        let _: ProFeature = .exportFormat(format: .m4a)
        let _: ProFeature = .removeWatermark
        let _: ProFeature = .customFillerLibrary
        let _: ProFeature = .backgroundProcessing
        #expect(true)
    }

    @Test func equatableMatchesByCase() {
        #expect(ProFeature.smartCutSession == ProFeature.smartCutSession)
        #expect(ProFeature.smartCutLength(seconds: 600) == ProFeature.smartCutLength(seconds: 600))
        #expect(ProFeature.smartCutLength(seconds: 600) != ProFeature.smartCutLength(seconds: 300))
    }
}
