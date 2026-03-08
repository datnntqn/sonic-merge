# Architecture Research

**Domain:** iOS Audio Processing App (Audio Merger + On-Device AI Denoiser)
**Researched:** 2026-03-08
**Confidence:** HIGH (Stack decisions confirmed by Apple docs and WWDC sessions; patterns confirmed by multiple sources)

---

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                                │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────┐   │
│  │  MixingStation   │  │   CleaningLab    │  │   ExportProgress     │   │
│  │  View            │  │   View           │  │   Sheet              │   │
│  └────────┬─────────┘  └────────┬─────────┘  └──────────┬───────────┘   │
│           │                     │                        │               │
│  ┌────────▼─────────┐  ┌────────▼─────────┐  ┌──────────▼───────────┐   │
│  │  MixingStation   │  │   CleaningLab    │  │   ExportProgress     │   │
│  │  ViewModel       │  │   ViewModel      │  │   ViewModel          │   │
│  └────────┬─────────┘  └────────┬─────────┘  └──────────┬───────────┘   │
├───────────┼─────────────────────┼────────────────────────┼───────────────┤
│                        SERVICE LAYER                                      │
├───────────┼─────────────────────┼────────────────────────┼───────────────┤
│  ┌────────▼──────────────────────▼────────┐  ┌───────────▼───────────┐   │
│  │         AudioMergerService             │  │  NoiseReductionService│   │
│  │  (AVMutableComposition +               │  │  (AVAudioEngine +     │   │
│  │   AVAssetExportSession)                │  │   Voice Processing)   │   │
│  └─────────────────────┬──────────────────┘  └───────────┬───────────┘   │
│                        │                                  │               │
│  ┌─────────────────────▼──────────────────────────────────▼───────────┐   │
│  │                    AudioSessionManager                              │   │
│  │              (AVAudioSession configuration)                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────────┤
│                        DATA / MODEL LAYER                                │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                   │
│  │ AudioSegment │  │ MergeConfig  │  │ TempFileStore│                   │
│  │ (struct)     │  │ (struct)     │  │ (FileManager)│                   │
│  └──────────────┘  └──────────────┘  └──────────────┘                   │
├─────────────────────────────────────────────────────────────────────────┤
│                        EXTENSION LAYER (separate target)                 │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  ShareExtension (ShareViewController)                            │   │
│  │    NSItemProvider → copy to App Group container → open main app  │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|---------------|------------------------|
| `MixingStationView` | Drag-reorder clip list, add gaps, swipe-delete, Before/After toggle | SwiftUI List with `.onMove`, gesture recognizers |
| `CleaningLabView` | Noise intensity slider, A/B comparison playback, progress display | SwiftUI Slider, AVAudioPlayer for preview |
| `MixingStationViewModel` | Clip list state, reorder logic, gap insertion, export trigger | `@Observable` class, `@MainActor` |
| `CleaningLabViewModel` | Denoising state, intensity value, playback state | `@Observable` class, `@MainActor` |
| `AudioMergerService` | Compose AVMutableComposition, apply crossfades, export to file | Pure Swift `actor` or `struct` with `async` methods |
| `NoiseReductionService` | Build AVAudioEngine graph, enable voice processing, write PCM buffers to output file | Pure Swift `actor` with `async throws` |
| `AudioSessionManager` | Configure AVAudioSession category/mode, handle interruptions | Singleton `@MainActor` class |
| `AudioSegment` | Immutable value: URL, duration, CMTimeRange, display name | `struct` conforming to `Identifiable`, `Equatable` |
| `TempFileStore` | Create/track/delete temp files in `NSTemporaryDirectory()` | Utility `class` or `actor` |
| `ShareViewController` | Accept NSItemProvider audio attachments, copy to App Group container, dismiss | `UIViewController` subclass (can use SwiftUI host) |

---

## Recommended Project Structure

```
SonicMerge/
├── App/
│   └── SonicMergeApp.swift          # @main entry, AudioSessionManager.configure()
│
├── Features/
│   ├── Merging/
│   │   ├── MixingStationView.swift   # UI: clip list, drag-reorder, gaps
│   │   ├── MixingStationViewModel.swift
│   │   ├── AudioCardView.swift       # Individual clip card component
│   │   └── WaveformView.swift        # Waveform mini-preview component
│   │
│   └── Denoising/
│       ├── CleaningLabView.swift     # UI: intensity slider, A/B compare
│       └── CleaningLabViewModel.swift
│
├── Services/
│   ├── AudioMergerService.swift      # Composition + export
│   ├── NoiseReductionService.swift   # AVAudioEngine voice processing
│   └── AudioSessionManager.swift    # AVAudioSession setup
│
├── Models/
│   ├── AudioSegment.swift            # Value type for a clip
│   ├── MergeConfig.swift             # Gap durations, crossfade params
│   └── ProcessingState.swift         # Enum: idle/processing/done/failed
│
├── Storage/
│   └── TempFileStore.swift           # Temp file lifecycle management
│
├── Extensions/
│   ├── CMTime+Extensions.swift
│   ├── AVAsset+Extensions.swift
│   └── Color+Theme.swift
│
├── Resources/
│   └── Assets.xcassets
│
└── ShareExtension/                   # Separate Xcode target
    ├── ShareViewController.swift
    └── Info.plist
```

### Structure Rationale

- **`Features/`:** Features are self-contained vertical slices (View + ViewModel). Each feature folder owns its UI without reaching into other features.
- **`Services/`:** Pure business logic, no SwiftUI imports. Services are injectable and independently testable.
- **`Models/`:** Shared value types; no business logic. Both Features and Services import these — they form the shared vocabulary.
- **`Storage/`:** Isolated file-system concern. Swappable without touching Services.
- **`ShareExtension/`:** Separate target with minimal code. Only handles ingestion; all processing stays in the main app.

---

## Architectural Patterns

### Pattern 1: MVVM with @Observable (iOS 17+)

**What:** Views own an `@Observable` ViewModel annotated with `@MainActor`. Services are plain `actor` types injected into ViewModels. Data flows from Service -> ViewModel (via `async/await`) -> View (via observed state).

**When to use:** The standard pattern for SwiftUI on iOS 17+. Required for SonicMerge since the minimum deployment is iOS 17.

**Trade-offs:** Simpler than Combine pipelines; all UI state lives on main actor; async processing escapes to background naturally via Swift Concurrency `Task {}` blocks inside ViewModels.

**Example:**

```swift
// Model
struct AudioSegment: Identifiable, Equatable {
    let id: UUID
    let sourceURL: URL
    let displayName: String
    let duration: CMTime
    var gapAfter: CMTime = .zero
}

// ViewModel — all UI state, all UI mutations on @MainActor
@Observable
@MainActor
final class MixingStationViewModel {
    var segments: [AudioSegment] = []
    var processingState: ProcessingState = .idle
    var exportProgress: Double = 0

    private let mergerService: AudioMergerService
    private let denoiseService: NoiseReductionService

    func startExport(config: MergeConfig) {
        Task {
            processingState = .processing
            do {
                let merged = try await mergerService.merge(segments, config: config)
                let denoised = try await denoiseService.process(merged, intensity: config.noiseIntensity)
                processingState = .done(url: denoised)
            } catch {
                processingState = .failed(error)
            }
        }
    }
}
```

### Pattern 2: Service as Actor (Background Audio Processing)

**What:** Audio processing services are Swift `actor` types. Calling them from `@MainActor` ViewModels automatically hops to the actor's executor, keeping audio I/O off the main thread.

**When to use:** Any long-running audio operation: composition, export, noise reduction buffer writing. Prevents UI jank.

**Trade-offs:** Actors serialize access, so two simultaneous exports cannot run in parallel on the same service instance. For SonicMerge's sequential pipeline this is correct behavior. Progress reporting requires explicit `await MainActor.run {}` calls.

**Example:**

```swift
actor AudioMergerService {
    func merge(_ segments: [AudioSegment], config: MergeConfig) async throws -> URL {
        let composition = AVMutableComposition()
        let track = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        var cursor = CMTime.zero
        for segment in segments {
            let asset = AVURLAsset(url: segment.sourceURL)
            let assetTrack = try await asset.loadTracks(withMediaType: .audio).first!
            let timeRange = try await asset.load(.duration)
            try track?.insertTimeRange(
                CMTimeRangeMake(start: .zero, duration: timeRange),
                of: assetTrack,
                at: cursor
            )
            cursor = CMTimeAdd(cursor, timeRange)
            cursor = CMTimeAdd(cursor, segment.gapAfter)
        }
        return try await export(composition: composition, config: config)
    }
}
```

### Pattern 3: Progress Reporting via AsyncStream

**What:** Wrap `AVAssetExportSession.exportAsynchronously` with an `AsyncStream` that polls the `progress` property on a timer and yields values. The ViewModel subscribes via `for await progress in stream`.

**When to use:** Export progress display. The native `AVAssetExportSession.progress` property is KVO-observable but not async-sequence native until iOS 18. For iOS 17 targets, polling is the pragmatic approach.

**Trade-offs:** Polling interval (e.g., 100ms) adds minor overhead. The `export(to:as:isolation:)` async method is iOS 18+ only — do not use it if targeting iOS 17.

**Example:**

```swift
// Inside AudioMergerService
private func exportWithProgress(
    session: AVAssetExportSession,
    outputURL: URL
) async throws -> AsyncStream<Double> {
    return AsyncStream { continuation in
        session.exportAsynchronously {
            continuation.finish()
        }
        Task {
            while session.status == .exporting || session.status == .waiting {
                continuation.yield(Double(session.progress))
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
    }
}
```

### Pattern 4: Share Extension → Main App via App Group Container

**What:** Share Extension accepts NSItemProvider audio attachments, copies the file to a shared App Group file container, writes metadata (filename, UTI) to shared `UserDefaults(suiteName:)`, then dismisses. The main app reads the container on next launch or via openURL.

**When to use:** This is the only viable pattern for iOS Share Extensions. Extensions cannot call `UIApplication.shared.open()` directly; they must use a responder-chain workaround to open the URL scheme.

**Trade-offs:** The user must switch to the main app manually after sharing — there is no automatic app-switch in modern iOS without a URL scheme call. URL scheme dispatch from Share Extension requires the responder-chain hack (walking up `UIResponder` chain to find `UIApplication`).

**Example:**

```swift
// ShareViewController.swift
class ShareViewController: UIViewController {
    private let appGroupID = "group.com.yourcompany.sonicmerge"

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else { return }

        let audioTypes: [UTType] = [.audio, .mpeg4Audio, .wav, .aiff]
        for type in audioTypes {
            if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { [weak self] url, error in
                    guard let url, error == nil else { return }
                    self?.copyToSharedContainer(url)
                }
                break
            }
        }
    }

    private func copyToSharedContainer(_ url: URL) {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return }
        let dest = container.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.copyItem(at: url, to: dest)

        // Write pending import metadata
        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(dest.lastPathComponent, forKey: "pendingImportFilename")

        extensionContext?.completeRequest(returningItems: nil)
    }
}
```

---

## Data Flow

### Primary Flow: Import → Merge → Denoise → Export

```
[Share Extension]
    ↓ NSItemProvider loadFileRepresentation
[App Group Container] ← copyItem (audio file written here)
    ↓ UserDefaults(suiteName:) "pendingImportFilename"
[Main App Launch / onOpenURL]
    ↓ reads pending import filename
[MixingStationViewModel.importFromSharedContainer()]
    ↓ creates AudioSegment (struct, value type)
[MixingStationView] ← @Observable re-renders segment list
    ↓ user reorders / sets gaps / triggers export
[MixingStationViewModel.startExport()]
    ↓ Task { } — escapes to background via actor hop
[AudioMergerService.merge()] ← actor, background thread
    ↓ AVMutableComposition built in memory
    ↓ AVAssetExportSession → temp file (NSTemporaryDirectory)
[NoiseReductionService.process()] ← actor, background thread
    ↓ AVAudioEngine + VoiceProcessing reads temp file
    ↓ AVAudioSinkNode captures processed PCM buffers
    ↓ AVAudioFile writes processed output → new temp file
    ↓ await MainActor.run { } — progress updates to ViewModel
[MixingStationViewModel] ← processingState = .done(url:)
    ↓ @Observable triggers View re-render
[ExportProgressSheet] ← shows completion, share sheet
    ↓ UIActivityViewController / ShareLink
[User's Files / AirDrop / etc.]
```

### State Management

```
ProcessingState enum (idle → processing → done/failed)
    ↓ owned by ViewModel (@Observable, @MainActor)
    ↓ read by View (SwiftUI binding)
    ↓ mutated only by ViewModel (no direct Service → View writes)

AudioSegment array (source of truth for clip list)
    ↓ owned by MixingStationViewModel
    ↓ passed by value to Services (no shared mutable state)
    ↓ modified via .move(), .remove(), .insert() on ViewModel
```

### Key Data Flows

1. **Clip import from Share Extension:** App Group container file → `AudioSegment` struct (URL + metadata only, no data loading) → ViewModel array → View list.
2. **Merge execution:** ViewModel passes `[AudioSegment]` + `MergeConfig` value types to `AudioMergerService`. Service owns all mutable AVFoundation objects internally. Result is a `URL` returned to ViewModel.
3. **Noise reduction:** `NoiseReductionService` reads from the merger output URL. Writes processed PCM to a new temp file. Progress ticks are pushed to ViewModel via `await MainActor.run {}`.
4. **Temp file lifecycle:** `TempFileStore` vends unique temp URLs, tracks them in a `Set<URL>`. Called at app termination / export completion to `FileManager.removeItem(at:)`.

---

## Suggested Build Order

The component dependency graph drives this order. Build from the bottom up: Models first (no dependencies), then Services (depend on Models), then ViewModels (depend on Services), then Views (depend on ViewModels).

| Phase | Components to Build | Why This Order |
|-------|---------------------|----------------|
| 1 | `AudioSegment`, `MergeConfig`, `ProcessingState`, `TempFileStore` | No dependencies; shared vocabulary for everything above |
| 2 | `AudioSessionManager` | Required by both services; must configure AVAudioSession before any audio API call |
| 3 | `AudioMergerService` | Core feature, no UI dependency; testable in isolation |
| 4 | `MixingStationViewModel` + `MixingStationView` | First working UI; merge pipeline end-to-end |
| 5 | `NoiseReductionService` | Depends on a merged file from Phase 3 to test |
| 6 | `CleaningLabViewModel` + `CleaningLabView` | Depends on NoiseReductionService |
| 7 | `ShareViewController` (Share Extension target) | Last because it depends on App Group container being set up in main target; integration test requires both targets |

---

## Anti-Patterns

### Anti-Pattern 1: Performing Audio I/O on the Main Actor

**What people do:** Call `AVAssetExportSession.exportAsynchronously` or `AVAudioEngine` buffer writes directly inside a `@MainActor` function without an explicit `Task {}` escape.

**Why it's wrong:** Blocks the main thread. UI freezes. Even if the callback is asynchronous, setting up and starting the engine does real work synchronously.

**Do this instead:** Always call audio services from a `Task {}` inside the ViewModel. Services are `actor` types — the call automatically hops off the main thread.

### Anti-Pattern 2: Using AVAudioEngine's Voice Processing in Stopped-State Incorrectly

**What people do:** Call `setVoiceProcessingEnabled(true)` after the engine is already running, or fail to restart the engine after `AVAudioEngineConfigurationChange` notification.

**Why it's wrong:** Voice processing cannot be toggled on a running engine. The engine silently fails or crashes. Additionally, after configuration changes (e.g., Bluetooth headset connected), the engine auto-stops and must be manually restarted.

**Do this instead:** Always call `setVoiceProcessingEnabled(true)` on the input node before calling `engine.start()`. Subscribe to `AVAudioEngineConfigurationChange` via `NotificationCenter` and restart the engine in the handler.

### Anti-Pattern 3: Storing Audio File Data in Memory

**What people do:** Load the full `AVAudioPCMBuffer` for each clip into a ViewModel property array to "have it ready."

**Why it's wrong:** A 10-minute stereo WAV at 44.1kHz is ~200MB. Three clips = 600MB. App is terminated by the OS.

**Do this instead:** Store only `URL` references in `AudioSegment`. Let `AVURLAsset` and `AVAudioFile` manage I/O lazily. The framework handles buffering internally.

### Anti-Pattern 4: Sharing AVMutableComposition Across Tasks

**What people do:** Create one `AVMutableComposition` and mutate it from concurrent tasks (e.g., re-import while export is running).

**Why it's wrong:** `AVMutableComposition` is not thread-safe. Concurrent mutations cause crashes.

**Do this instead:** The `AudioMergerService` `actor` ensures serialized access. Never expose the composition object outside the service.

### Anti-Pattern 5: Writing Processed Audio Directly to Documents Directory Without Cleanup

**What people do:** Write every intermediate file (pre-denoise, post-denoise, final export) to `Documents/` and never delete them.

**Why it's wrong:** Audio files are large. After a few sessions the user's storage fills up with invisible junk files.

**Do this instead:** All intermediate files go to `NSTemporaryDirectory()`. Only the final user-exported file goes to the location the user chooses (via `UIDocumentPickerViewController` or `ShareLink`). `TempFileStore.cleanup()` is called at app termination and before each new session.

---

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| View ↔ ViewModel | SwiftUI `@Observable` observation (pull-based) | No Combine needed; `@Observable` + `@MainActor` is sufficient for iOS 17+ |
| ViewModel ↔ Service | `async throws` method calls | ViewModel calls service inside `Task {}`; service `actor` handles thread hopping |
| Service ↔ Service | Direct `async` call (ViewModel orchestrates) | ViewModel calls merge, then denoise sequentially; services do not call each other |
| Main App ↔ Share Extension | App Group: `FileManager.containerURL` + `UserDefaults(suiteName:)` | Both targets must have same App Group entitlement in provisioning profile |
| AudioSessionManager ↔ Services | Singleton call at app launch, then interruption handling | Services assume session is configured; `AVAudioSessionInterruptionNotification` observed in Manager |

### External Framework Integration

| Framework | Integration Pattern | Notes |
|-----------|---------------------|-------|
| `AVFoundation` (`AVMutableComposition`, `AVAssetExportSession`) | Used exclusively inside `AudioMergerService` | Never leak AVFoundation composition objects to ViewModels |
| `AVFAudio` (`AVAudioEngine`, `AVAudioSinkNode`) | Used exclusively inside `NoiseReductionService` | Engine must be stopped before `setVoiceProcessingEnabled` |
| `UniformTypeIdentifiers` | Used in `ShareViewController` for type checking (`UTType.audio`, `.mpeg4Audio`, `.wav`) | Prefer `UTType` over string-based UTIs; iOS 14+ |
| `CoreML` (optional) | Would live in a `CoreMLDenoiseService` conforming to same protocol as `NoiseReductionService` | Swap via DI if Voice Processing proves insufficient; keep behind a protocol |

---

## Scaling Considerations

This is a single-user, fully on-device iOS utility app. Traditional server scaling does not apply. The relevant "scaling" axes are device performance and file size.

| Concern | iPhone 15 (A16) | Older iPhone (A13/A14) |
|---------|-----------------|------------------------|
| Merge of 5x 5min clips | < 10 seconds | 15–30 seconds |
| Noise reduction on 10min audio | 30–60 seconds | 1–3 minutes |
| Memory during processing | ~50–100MB peak | Same (file-based, not in-memory) |

### Scaling Priorities

1. **First bottleneck: Noise reduction speed.** AVAudioEngine voice processing runs in real-time (1x) by default — a 5-minute clip takes ~5 minutes to process. Mitigation: show accurate progress, consider running at accelerated playback rate if API allows, or use Core ML model for offline batch inference.
2. **Second bottleneck: Large file temp storage.** Users with many long clips generate GB of temp data. Mitigation: `TempFileStore` auto-cleanup; only keep the active session's intermediate files.

---

## Sources

- Apple Developer Documentation — AVAudioEngine Voice Processing: https://developer.apple.com/documentation/avfaudio/audio_engine/audio_units/using_voice_processing
- WWDC23 "What's new in voice processing": https://developer.apple.com/videos/play/wwdc2023/10235/
- WWDC19 "What's New in AVAudioEngine": https://developer.apple.com/videos/play/wwdc2019/510/
- Kodeco AVAudioEngine Tutorial: https://www.kodeco.com/21672160-avaudioengine-tutorial-for-ios-getting-started (MEDIUM confidence — tutorial site, verified against Apple docs)
- snakamura.github.io AVAudioEngine tips (2024): https://snakamura.github.io/log/2024/11/audio_engine.html — voice processing, format mismatch, engine restart pattern
- NSHipster Temporary Files: https://nshipster.com/temporary-files/ — temp file lifecycle patterns
- Apple Developer Docs — Configuring App Groups: https://developer.apple.com/documentation/Xcode/configuring-app-groups
- iOS App Extensions Data Sharing (dmtopolog): https://dmtopolog.com/ios-app-extensions-data-sharing/ — seven sharing mechanisms, shared container pattern
- HackingWithSwift — Don't use actor for SwiftUI data models: https://www.hackingwithswift.com/quick-start/concurrency/important-do-not-use-an-actor-for-your-swiftui-data-models (HIGH confidence — directly relevant to @Observable + @MainActor pattern)
- AVAssetExportSession async/await gist (Swift 6 safety): https://gist.github.com/samsonjs/2f006c5f62f53c9aef820bc050e37809
- Apple Developer Forums — AVAssetExportSession exportAsynchronously: https://developer.apple.com/forums/thread/649671

---

*Architecture research for: iOS Audio Merger + On-Device AI Denoiser (SonicMerge)*
*Researched: 2026-03-08*
