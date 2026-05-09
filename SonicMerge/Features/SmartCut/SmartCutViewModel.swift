import Foundation
import AVFoundation
import Observation
import Speech
import SwiftData
import UIKit
import UserNotifications

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
    private(set) var cachedSegments: [TranscriptionState.RecognizedSegment] = []
    private(set) var cachedDuration: TimeInterval = 0
    private(set) var inputURL: URL?
    private(set) var outputURL: URL?
    private(set) var estimatedAnalysisMinutes: Int = 0
    private var appliedEditListSnapshot: EditList?
    var hasDirtyEditsSinceApply: Bool {
        guard let snapshot = appliedEditListSnapshot else { return false }
        return snapshot != editList
    }
    var pauseThreshold: TimeInterval = 1.5

    /// Resolved locale used for the next analyze. Set from
    /// `session.localeIdentifier` by the session-driven init; mutated by
    /// `setLocale(_:on:)`. Defaults to the device's preferred language
    /// (filtered through SFSpeechRecognizer.supportedLocales()).
    var currentLocale: Locale = TranscriptionService.resolveSupportedLocale(
        Locale(identifier: Locale.preferredLanguages.first ?? "en-US")
    )

    /// True while the post-Apply output file is playing. Drives the studio
    /// applied-state Play/Pause button.
    private(set) var isPlayingOutput: Bool = false

    // MARK: Dependencies
    private let coordinator: PlaybackCoordinator
    private let library: FillerLibrary
    private let service: SmartCutService
    private let cutter: AudioCutter
    private let entitlements: EntitlementService

    // MARK: Output playback (post-Apply preview)
    private var outputPlayer: AVAudioPlayer?

    private var analysisTask: Task<Void, Never>?

    init(coordinator: PlaybackCoordinator,
         library: FillerLibrary,
         entitlements: EntitlementService,
         service: SmartCutService? = nil,
         cutter: AudioCutter = AudioCutter()) {
        self.coordinator = coordinator
        self.library = library
        self.entitlements = entitlements
        self.service = service ?? SmartCutService(library: library)
        self.cutter = cutter
        coordinator.register(self)
    }

    /// Session-driven init used by SmartCutSessionView. Resolves the source URL
    /// from the App Group container (or the sandbox fallback when entitlement is
    /// unavailable — see SonicMergeApp.swift's modelContainer for the same
    /// pattern), registers the source hash with SmartCutSourceLocator so a
    /// background-transcription task can find the file on resume, decodes any
    /// persisted edit list, and lands the VM in the appropriate state.
    ///
    /// State landing rules:
    ///   - source file missing → .error(message: "Source file missing")
    ///   - source present, no editListJSON → .idle
    ///   - source present, valid editListJSON → editList loaded; state stays .idle
    ///     (re-analyze regenerates cachedSegments)
    convenience init(
        session: SmartCutSession,
        library: FillerLibrary,
        coordinator: PlaybackCoordinator,
        entitlements: EntitlementService,
        modelContext: ModelContext
    ) {
        self.init(coordinator: coordinator, library: library, entitlements: entitlements)

        // Resolve source URL. App Group path first; fall back to a deterministic
        // tmp directory if the entitlement is missing. The sandbox path is only
        // useful for unit tests — production always has the entitlement.
        let sourceURL: URL
        if let dir = try? AppConstants.smartCutSessionDirectory(for: session.id) {
            sourceURL = dir.appending(path: session.sourceFilename)
        } else {
            let dir = FileManager.default.temporaryDirectory
                .appending(path: "smart-cut-fallback")
                .appending(path: session.id.uuidString)
            try? FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true
            )
            sourceURL = dir.appending(path: session.sourceFilename)
        }

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            state = .error(message: "Source file missing")
            return
        }

        // Register the persisted source hash → URL synchronously so a
        // background-transcription notification arriving immediately can
        // resolve the source. setInput(url:) below also recomputes the hash
        // asynchronously; the redundant write is harmless.
        SmartCutSourceLocator.register(hash: session.sourceHashHex, url: sourceURL)

        setInput(url: sourceURL)

        if let stored = session.localeIdentifier, !stored.isEmpty {
            currentLocale = TranscriptionService.resolveSupportedLocale(Locale(identifier: stored))
        }

        if let json = session.editListJSON {
            do {
                let decoded = try JSONDecoder().decode(EditList.self, from: json)
                editList = decoded
            } catch {
                session.editListJSON = nil
            }
        }
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
        cachedSegments = []
        cachedDuration = 0
        outputURL = nil
        outputPlayer?.stop()
        outputPlayer = nil
        isPlayingOutput = false
        state = .idle
    }

    func markDenoiseChanged() {
        if case .results = state { state = .stale; return }
        if case .applied = state { state = .stale; return }
    }

    func requestReanalyze() {
        invalidate()
    }

    /// Persists a new locale onto the session and invalidates any cached
    /// transcript / edit list. Caller is responsible for `modelContext.save()`
    /// (matches today's `persist(to:)` shape).
    func setLocale(_ identifier: String, on session: SmartCutSession) {
        session.localeIdentifier = identifier
        currentLocale = TranscriptionService.resolveSupportedLocale(Locale(identifier: identifier))
        invalidate()
    }

    // MARK: Analyze (manual trigger from UI)

    func analyze() {
        guard let inputURL else { return }
        analysisTask?.cancel()
        state = .analyzing(progress: 0)
        analysisTask = Task {
            // Speech-recognition authorization gate. SFSpeechRecognizer.isAvailable returns
            // true even before the user has granted permission; on first use, the recognition
            // task itself fails with kAFAssistantErrorDomain if not authorized. Prompt
            // explicitly so the OS dialog appears, then handle each branch.
            let status = await Self.requestSpeechAuthorization()
            switch status {
            case .authorized:
                break
            case .denied, .restricted:
                state = .error(message: "Smart Cut needs Speech Recognition access. Enable it in Settings → CleanCut.")
                return
            case .notDetermined:
                // User dismissed the dialog without choosing — treat as denied for this run.
                state = .idle
                return
            @unknown default:
                state = .error(message: "Speech Recognition is unavailable.")
                return
            }
            do {
                for try await update in await service.analyze(input: inputURL,
                                                              pauseThreshold: pauseThreshold,
                                                              locale: currentLocale) {
                    if Task.isCancelled { return }
                    switch update {
                    case .progress(let p):
                        state = .analyzing(progress: p)
                    case .completed(let list, let segments, let duration):
                        editList = list
                        cachedSegments = segments
                        cachedDuration = duration
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

    private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }

    func cancelAnalyze() {
        analysisTask?.cancel()
        analysisTask = nil
        state = .idle
    }

    func scheduleBackgroundTranscription() {
        // Free users get a silent skip — the foreground job continues; when the
        // user backgrounds the app it pauses; on re-foreground it resumes.
        // Surfacing a paywall here would feel like punishment for closing the app.
        if case .requiresPro = entitlements.gate(.backgroundProcessing) { return }

        // Request notification authorization the first time the user opts into BG processing,
        // so the completion notification can actually surface. Permission is asked once
        // and cached by the OS — calling repeatedly is cheap and idempotent.
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            try? BackgroundTranscriptionTask.schedule()
        }
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

    /// Phase 12 (Studio): live-recompute the pause set when the user drags the
    /// threshold slider. Clamps to a defensive sanity range, updates the public
    /// pauseThreshold, then re-runs PauseDetector against the cached segments
    /// captured at .completed. Preserves user isEnabled toggles by exact id-string
    /// match (PauseEdit.id is "pause@\(lowerBound)" and PauseDetector is
    /// deterministic for the same cached segments — surviving pauses keep the
    /// identical id). Does NOT fire a haptic itself; haptic responsibility lives
    /// in the caller (PauseControlRow.onChange).
    ///
    /// Clamps to 1.0...3.0 (the slider's range).
    func setPauseThreshold(_ seconds: TimeInterval) {
        // Per spec: full no-op when there are no cached segments yet (i.e., before
        // first .completed). Both threshold AND pauses stay untouched in that case.
        guard !cachedSegments.isEmpty else { return }
        let clamped = min(max(seconds, 1.0), 3.0)
        pauseThreshold = clamped
        let priorIsEnabledById: [String: Bool] = Dictionary(
            uniqueKeysWithValues: editList.pauses.map { ($0.id, $0.isEnabled) }
        )
        let detected = PauseDetector.detect(
            in: cachedSegments,
            totalDuration: cachedDuration,
            threshold: clamped
        )
        editList.pauses = detected.map { p in
            if let prior = priorIsEnabledById[p.id], prior != p.isEnabled {
                return PauseEdit(timeRange: p.timeRange, isEnabled: prior)
            }
            return p
        }
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

    // MARK: - Persistence (Smart Cut tab)

    /// Writes the current edit list (if non-empty) and `lastOpenedAt = .now` back
    /// onto the supplied SwiftData session record. Caller is responsible for
    /// `try modelContext.save()` if it wants the change durable immediately;
    /// SwiftData also auto-saves on context lifecycle. An empty edit list writes
    /// `editListJSON = nil` so a resumed session lands cleanly in `.idle`.
    func persist(to session: SmartCutSession) {
        let isMeaningful = !editList.fillers.isEmpty || !editList.pauses.isEmpty
        session.editListJSON = isMeaningful
            ? (try? JSONEncoder().encode(editList))
            : nil
        session.lastOpenedAt = .now
    }

    // MARK: Output playback (post-Apply preview)

    /// Play / pause the cleaned output file. No-op when no output exists yet.
    func togglePlayOutput() {
        guard let outputURL else { return }
        if isPlayingOutput {
            outputPlayer?.pause()
            isPlayingOutput = false
            return
        }
        coordinator.notifyPlaying(participant: self)
        if outputPlayer == nil {
            outputPlayer = try? AVAudioPlayer(contentsOf: outputURL)
            outputPlayer?.prepareToPlay()
        }
        PlaybackAudioSession.activateIfNeeded()
        if let player = outputPlayer, player.play() {
            isPlayingOutput = true
        }
    }

    /// PlaybackParticipant requirement: pause anything we own when another
    /// participant (e.g. Denoise) starts playing.
    func pauseAll() {
        outputPlayer?.pause()
        isPlayingOutput = false
    }

    // MARK: Test seam — internal but injectable for unit tests

    func _injectResultsForTesting(_ list: EditList) {
        editList = list
        state = .results
    }

    func _injectAppliedSnapshotForTesting(_ list: EditList) {
        appliedEditListSnapshot = list
    }

    func _injectCachedTranscriptionForTesting(
        segments: [TranscriptionState.RecognizedSegment],
        duration: TimeInterval
    ) {
        cachedSegments = segments
        cachedDuration = duration
    }
}
