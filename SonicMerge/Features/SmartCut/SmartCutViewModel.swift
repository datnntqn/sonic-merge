import Foundation
import AVFoundation
import Observation
import UIKit

@Observable
@MainActor
final class SmartCutViewModel: PlaybackParticipant {

    enum State: Equatable {
        case idle
        case analyzing(progress: Double)
        case results
        case applied(savedDuration: TimeInterval)
        case stale
        case error(message: String)
    }

    // MARK: Public observable state
    private(set) var state: State = .idle
    private(set) var editList = EditList()
    private(set) var inputURL: URL?
    private(set) var outputURL: URL?
    private(set) var estimatedAnalysisMinutes: Int = 0
    private var appliedEditListSnapshot: EditList?
    var hasDirtyEditsSinceApply: Bool {
        guard let snapshot = appliedEditListSnapshot else { return false }
        return snapshot != editList
    }
    var pauseThreshold: TimeInterval = 1.5
    var isPlayingCleaned: Bool = false

    // MARK: Dependencies
    private let coordinator: PlaybackCoordinator
    private let library: FillerLibrary
    private let service: SmartCutService
    private let cutter: AudioCutter

    // MARK: Players
    private var inputPlayer: AVAudioPlayer?
    private var outputPlayer: AVAudioPlayer?
    private var previewEngine: AVAudioEngine?

    private var analysisTask: Task<Void, Never>?

    init(coordinator: PlaybackCoordinator,
         library: FillerLibrary,
         service: SmartCutService? = nil,
         cutter: AudioCutter = AudioCutter()) {
        self.coordinator = coordinator
        self.library = library
        self.service = service ?? SmartCutService(library: library)
        self.cutter = cutter
        coordinator.register(self)
    }

    // Note: deinit cancel of `analysisTask` was omitted because under
    // Swift 6 strict concurrency a `MainActor`-isolated property cannot be
    // touched from a `nonisolated deinit`. `invalidate()` and
    // `cancelAnalyze()` are the lifecycle hooks for tearing down work.

    // MARK: Lifecycle hooks called by the view

    func setInput(url: URL) {
        inputURL = url
        Task {
            if let hash = try? await SourceHasher.sha256Hex(of: url) {
                SmartCutSourceLocator.register(hash: hash, url: url)
            }
            let asset = AVURLAsset(url: url)
            if let duration = try? await asset.load(.duration).seconds {
                estimatedAnalysisMinutes = max(1, Int((duration / 2.5 / 60).rounded(.up)))
            }
        }
    }

    func invalidate() {
        analysisTask?.cancel()
        analysisTask = nil
        editList = EditList()
        outputURL = nil
        inputPlayer = nil
        outputPlayer = nil
        state = .idle
    }

    func markDenoiseChanged() {
        if case .results = state { state = .stale; return }
        if case .applied = state { state = .stale; return }
    }

    func requestReanalyze() {
        invalidate()
    }

    // MARK: Analyze (manual trigger from UI)

    func analyze() {
        guard let inputURL else { return }
        analysisTask?.cancel()
        state = .analyzing(progress: 0)
        analysisTask = Task {
            do {
                for try await update in await service.analyze(input: inputURL) {
                    if Task.isCancelled { return }
                    switch update {
                    case .progress(let p):
                        state = .analyzing(progress: p)
                    case .completed(let list):
                        editList = list
                        state = .results
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                state = .error(message: "Smart Cut couldn't analyze the audio. \(error.localizedDescription)")
            }
        }
    }

    func cancelAnalyze() {
        analysisTask?.cancel()
        analysisTask = nil
        state = .idle
    }

    func scheduleBackgroundTranscription() {
        try? BackgroundTranscriptionTask.schedule()
    }

    // MARK: User curation

    func setCategory(_ category: String, enabled: Bool) {
        editList.setCategory(category, enabled: enabled)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func setEdit(id: String, enabled: Bool) {
        editList.setEdit(id: id, enabled: enabled)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: Apply

    func apply() async {
        guard let inputURL else { return }
        do {
            let url = try await cutter.apply(input: inputURL, editList: editList)
            outputURL = url
            appliedEditListSnapshot = editList
            state = .applied(savedDuration: editList.enabledSavings)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        } catch {
            state = .error(message: "Couldn't apply cuts. \(error.localizedDescription)")
        }
    }

    // MARK: Playback (A/B) — STUB; actual audio plumbing deferred to manual integration in sc-t19/sc-t20

    func toggleCleaned() {
        isPlayingCleaned.toggle()
        coordinator.notifyPlaying(participant: self)
    }

    func pauseAll() {
        inputPlayer?.pause()
        outputPlayer?.pause()
        previewEngine?.pause()
    }

    // MARK: Test seam — internal but injectable for unit tests

    func _injectResultsForTesting(_ list: EditList) {
        editList = list
        state = .results
    }

    func _injectAppliedSnapshotForTesting(_ list: EditList) {
        appliedEditListSnapshot = list
    }
}
