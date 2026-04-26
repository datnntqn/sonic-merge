import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct PlaybackCoordinatorTests {

    final class FakePlayer: PlaybackParticipant {
        var pauseCalled = false
        func pauseAll() { pauseCalled = true }
    }

    @Test func testRegisteringTwoParticipantsAndPlayingOnePausesOther() {
        let coordinator = PlaybackCoordinator()
        let a = FakePlayer()
        let b = FakePlayer()
        coordinator.register(a)
        coordinator.register(b)
        coordinator.notifyPlaying(participant: a)
        #expect(a.pauseCalled == false)
        #expect(b.pauseCalled == true)
    }

    @Test func testNotifyingThirdParticipantPausesPriorActive() {
        let coordinator = PlaybackCoordinator()
        let a = FakePlayer()
        let b = FakePlayer()
        coordinator.register(a)
        coordinator.register(b)
        coordinator.notifyPlaying(participant: a)
        coordinator.notifyPlaying(participant: b)
        // After the second notify, A should have been paused.
        #expect(a.pauseCalled == true)
    }

    @Test func testUnregisterRemovesFromBroadcast() {
        let coordinator = PlaybackCoordinator()
        let a = FakePlayer()
        let b = FakePlayer()
        coordinator.register(a)
        coordinator.register(b)
        coordinator.unregister(b)
        coordinator.notifyPlaying(participant: a)
        #expect(b.pauseCalled == false)
    }
}
