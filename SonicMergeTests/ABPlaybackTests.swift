//
//  ABPlaybackTests.swift
//  SonicMergeTests
//
//  Failing stubs for DNS-03: A/B playback position preservation.
//  RED state: ABPlaybackController does not exist until Wave 3 (Plan 03-04).
//
//  Note: AVAudioPlayer requires a real audio file — this test will use a fixture WAV
//  from SonicMergeTests/Fixtures/ once Wave 3 creates ABPlaybackController.
//

import Testing
import Foundation
@testable import SonicMerge

struct ABPlaybackTests {

    // MARK: - DNS-03: Playback position preserved on A/B switch

    @Test func testPositionPreservedOnSwitch() {
        // Stub: after switchToOriginal(), originalPlayer.currentTime must match
        // the previous denoisedPlayer.currentTime (position continuity on A/B toggle).
        // Wave 3 must verify currentTime is preserved within ±0.05s tolerance.
        Issue.record("not implemented — DNS-03: after switchToOriginal(), originalPlayer.currentTime must match previous denoisedPlayer.currentTime")
    }
}
