// SonicMerge/Features/Recording/AudioRecorderService.swift
//
// In-app voice recorder. @MainActor + ObservableObject because AVAudioRecorder
// is single-threaded and the SwiftUI sheet observes @Published state. DI seam
// for mic permission via RecordPermissionProvider.
//
// Output: AAC .m4a, 44.1 kHz, mono, 128 kbps — matches the rest of the app's
// export defaults so the recorded file decodes via AVAsset everywhere else
// without re-encoding.
//

import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioRecorderService: ObservableObject {

    enum RecorderError: Error, Equatable {
        case micPermissionDenied
        case sessionConfigurationFailed
        case recorderInitFailed
        case startFailed
    }

    // MARK: Published state (single 20 Hz timer drives both elapsed time
    // and level — the spec's "10 Hz / 20 Hz" was conservative; one timer
    // is simpler and the user can't perceive the difference at 50ms ticks).
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var levelNormalized: Float = 0  // [0, 1]

    // MARK: Identity
    private(set) var currentFileURL: URL?

    // MARK: Internals
    private let permissions: any RecordPermissionProvider
    private var recorder: AVAudioRecorder?
    private var pollTask: Task<Void, Never>?
    private var previousSessionCategory: AVAudioSession.Category?
    private var previousSessionOptions: AVAudioSession.CategoryOptions = []

    init(permissions: any RecordPermissionProvider = SystemRecordPermissionProvider()) {
        self.permissions = permissions
    }

    // No deinit cleanup needed: pollTask captures [weak self] and naturally
    // exits when self deallocates OR isRecording becomes false. Explicit
    // cleanup happens via stop() / cancel() while the sheet is on screen.

    func start() async throws {
        guard !isRecording else { return }

        let granted = await permissions.request()
        guard granted else { throw RecorderError.micPermissionDenied }

        let session = AVAudioSession.sharedInstance()
        previousSessionCategory = session.category
        previousSessionOptions = session.categoryOptions
        do {
            try session.setCategory(.playAndRecord,
                                    options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            throw RecorderError.sessionConfigurationFailed
        }

        let url = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("recording-\(UUID().uuidString).m4a")
        currentFileURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128_000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let r: AVAudioRecorder
        do {
            r = try AVAudioRecorder(url: url, settings: settings)
        } catch {
            throw RecorderError.recorderInitFailed
        }
        r.isMeteringEnabled = true
        // No delegate — we drive lifecycle explicitly via stop()/cancel(),
        // and assigning a @MainActor self to AVAudioRecorder.delegate
        // (a non-isolated weak ref) tickles Swift 6 strict-concurrency.

        guard r.prepareToRecord(), r.record() else {
            throw RecorderError.startFailed
        }
        recorder = r
        isRecording = true
        startPolling()
    }

    /// Stops recording and returns the final URL. The file is left in /tmp;
    /// caller is responsible for moving/copying it out before the temp dir
    /// is reaped.
    func stop() -> URL? {
        guard isRecording, let recorder, let url = currentFileURL else { return nil }
        recorder.stop()
        finishSession()
        return url
    }

    /// Stops recording and deletes the temp file.
    func cancel() {
        guard let recorder, let url = currentFileURL else {
            finishSession()
            return
        }
        recorder.stop()
        try? FileManager.default.removeItem(at: url)
        currentFileURL = nil
        finishSession()
    }

    private func finishSession() {
        pollTask?.cancel()
        pollTask = nil
        recorder = nil
        isRecording = false
        elapsedSeconds = 0
        levelNormalized = 0
        if let prev = previousSessionCategory {
            try? AVAudioSession.sharedInstance().setCategory(prev, options: previousSessionOptions)
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        previousSessionCategory = nil
        previousSessionOptions = []
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled, self.isRecording, let r = self.recorder {
                r.updateMeters()
                let dB = r.averagePower(forChannel: 0)
                // dB ∈ [-160, 0]. Map to [0, 1] via 10^(dB/20). Floor at -50 dB
                // for a more useful visual range (anything quieter renders as 0).
                let clamped = max(dB, -50)
                self.levelNormalized = pow(10, clamped / 20)
                self.elapsedSeconds = r.currentTime
                try? await Task.sleep(for: .milliseconds(50))  // 20 Hz
            }
        }
    }
}
