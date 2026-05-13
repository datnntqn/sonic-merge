import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct FreeCapCaptionTests {

    @Test func proRendersNil() {
        #expect(FreeCapCaption.captionString(for: .smartCut, isPro: true, count: 0) == nil)
        #expect(FreeCapCaption.captionString(for: .denoise, isPro: true, count: 2) == nil)
        #expect(FreeCapCaption.captionString(for: .merge, isPro: true, count: 0) == nil)
    }

    @Test func smartCutShowsCountAndCap() {
        #expect(
            FreeCapCaption.captionString(for: .smartCut, isPro: false, count: 0)
            == "Free: up to 5 min · 0 of 3 today"
        )
        #expect(
            FreeCapCaption.captionString(for: .smartCut, isPro: false, count: 2)
            == "Free: up to 5 min · 2 of 3 today"
        )
    }

    @Test func denoiseShowsCountAndCap() {
        #expect(
            FreeCapCaption.captionString(for: .denoise, isPro: false, count: 1)
            == "Free: up to 3 min · 1 of 3 today"
        )
    }

    @Test func mergeIgnoresCount() {
        #expect(
            FreeCapCaption.captionString(for: .merge, isPro: false, count: 0)
            == "Free: up to 3 clips"
        )
        #expect(
            FreeCapCaption.captionString(for: .merge, isPro: false, count: 99)
            == "Free: up to 3 clips"
        )
    }
}
