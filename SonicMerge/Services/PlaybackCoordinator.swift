import Foundation

/// A view model that owns audio playback registers itself with the coordinator
/// so other registered VMs can be paused when this one starts playing.
@MainActor
protocol PlaybackParticipant: AnyObject {
    func pauseAll()
}

/// Cross-card playback exclusivity. Used by Cleaning Lab so toggling A/B on
/// the Smart Cut card pauses the Denoise card's player and vice versa.
@MainActor
final class PlaybackCoordinator {
    private var participants: [WeakBox] = []

    func register(_ participant: PlaybackParticipant) {
        participants.append(WeakBox(participant))
    }

    func unregister(_ participant: PlaybackParticipant) {
        participants.removeAll { $0.value === participant || $0.value == nil }
    }

    func notifyPlaying(participant active: PlaybackParticipant) {
        participants.removeAll { $0.value == nil }
        for box in participants {
            if let p = box.value, p !== active {
                p.pauseAll()
            }
        }
    }

    private struct WeakBox {
        weak var value: PlaybackParticipant?
        init(_ value: PlaybackParticipant) { self.value = value }
    }
}
