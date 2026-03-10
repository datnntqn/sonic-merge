# Phase 2: Merge Pipeline + Mixing Station UI - Research

**Researched:** 2026-03-10
**Domain:** AVFoundation merge pipeline, SwiftUI MVVM, SwiftData relationships, waveform rendering
**Confidence:** HIGH (core AVFoundation patterns well-established; WAV export path has verified caveat)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Waveform Thumbnail**
- Generate waveform data at import time (during normalization pipeline), not lazily or on demand
- Store as a sidecar file in the App Group container alongside the audio file (e.g. `UUID.waveform`) — avoids SwiftData binary blob concerns, easy to regenerate
- Visual style: filled bar chart, accent blue (#007AFF) — vertical bars, standard audio app look, matches project theme
- Position: left side of the clip card, fixed width ~60pt — waveform thumbnail on left, text (display name + duration) on the right

**Gap & Crossfade Controls**
- Gap control appears as an inline separator row between each pair of clip cards — always visible, no tap needed to reveal
- Gap duration chosen via a segmented control inline in the gap row: `0.5s | 1.0s | 2.0s | Crossfade` — no extra tap required
- Crossfade is a toggle option in the gap row, mutually exclusive with silence gaps — selecting "Crossfade" sets a crossfade instead of silence
- Crossfade duration: fixed at 0.5s — no variable duration in v1

**Export Format & Flow**
- Tap Export → bottom sheet opens with format picker (.m4a / .wav) + Export button
- Export progress: non-dismissible modal sheet with a progress bar (0–100%) and a Cancel button
- After successful export: progress modal dismisses → iOS system share sheet opens immediately with the exported file
- Cancel during export: stops immediately, partial file deleted, user returns to Mixing Station — no confirmation alert

**ViewModel Architecture**
- Create a new MixingStationViewModel (`@Observable`, `@MainActor`); ImportViewModel is retired — its import logic migrates into MixingStationViewModel
- MixingStationView becomes the root view of the app — `SonicMergeApp.swift` routes directly to it; `ContentView.swift` can be deleted; `ImportView.swift` retired
- Gap/crossfade state stored in SwiftData on a `GapTransition` model linked to `AudioClip` — persists across app relaunches
- Merge pipeline implemented as a new `AudioMergerService` actor called from MixingStationViewModel — isolates AVMutableComposition + AVAssetExportSession work on a background actor; reports progress via AsyncStream. Mirrors Phase 1's `AudioNormalizationService` pattern.

### Claude's Discretion
- Exact waveform downsampling algorithm (peak, RMS, etc.) and number of bars at thumbnail scale
- `GapTransition` SwiftData model fields and relationship to `AudioClip` (1-to-1, or ordered by sortOrder)
- `AVAssetExportSession` progress polling interval
- Empty state design for the Mixing Station when no clips are imported
- Drag handle visual (grip icon vs long-press anywhere on card)
- Error handling UX for failed exports

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| IMP-04 | Each imported clip displays a waveform preview thumbnail on its audio card | WaveformService using AVAssetReader + peak downsampling; sidecar file in App Group container; Canvas/Shape bar chart view |
| MRG-01 | User can reorder clips via drag-and-drop in a vertical timeline | SwiftUI List + ForEach + `.onMove`; update `sortOrder` on each AudioClip; SwiftData save on move |
| MRG-02 | User can delete a clip via swipe-left gesture | SwiftUI `.onDelete`; delete AudioClip + GapTransition from modelContext; delete sidecar audio + waveform files |
| MRG-03 | User can insert a silent gap between clips (0.5s, 1.0s, or 2.0s) | GapTransition SwiftData model; `insertEmptyTimeRange` on AVMutableCompositionTrack at correct CMTime offset |
| MRG-04 | User can apply a crossfade transition between adjacent segments | AVMutableAudioMixInputParameters + `setVolumeRamp` fade-out/fade-in over 0.5s overlap; AVAudioMix passed to AVAssetExportSession |
| EXP-01 | User can export merged audio as high-quality .m4a | AVAssetExportSession with `AVAssetExportPresetAppleM4A`; output file type `.m4a` |
| EXP-02 | User can export merged audio as lossless .wav | WAV export requires AVAssetReader+AVAssetWriter pipeline (not AVAssetExportSession) — see critical pitfall below |
| EXP-04 | User can see export progress and cancel an in-progress export | AsyncStream progress loop polling `exportSession.progress`; `exportSession.cancelExport()` on Task cancel |
| UX-01 | App applies "Minimalist Soft Professional" theme throughout | Colors, corner radius, SF font documented in REQUIREMENTS.md; applied consistently in MixingStationView and all sub-views |
</phase_requirements>

---

## Summary

Phase 2 is the largest single phase in the project. It delivers all of the primary user-facing value: the Mixing Station UI that replaces the Phase 1 import list, the AVMutableComposition-based merge pipeline, waveform thumbnails, gap/crossfade controls, and the export-to-share-sheet flow.

The architecture is cleanly factored into three new primary types: `MixingStationViewModel` (orchestration, `@Observable @MainActor`), `AudioMergerService` (actor, heavy AVFoundation work), and `WaveformService` (actor or free function, thumbnail generation). A new `GapTransition` SwiftData model stores per-gap settings linked to `AudioClip`.

The most important pitfall to plan around: `.wav` export cannot use `AVAssetExportSession` alone when the source is AAC (normalized .m4a). The merger must use the `AVAssetReader` + `AVAssetWriter` pipeline for WAV, writing Linear PCM into a `.wav` container. The `.m4a` path uses `AVAssetExportSession` normally. This means `AudioMergerService.export()` must branch on format.

**Primary recommendation:** Implement AudioMergerService as a Swift actor with two export code paths — `AVAssetExportSession` for .m4a and `AVAssetReader/AVAssetWriter` for .wav — both reporting progress via `AsyncStream<Float>`.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AVFoundation | iOS 17+ (system) | AVMutableComposition, AVAssetExportSession, AVAssetReader/Writer | Only Apple-sanctioned API for sample-accurate audio composition |
| SwiftData | iOS 17+ (system) | GapTransition persistence | Already in use for AudioClip; no additional dependency |
| SwiftUI | iOS 17+ (system) | MixingStationView, clip cards, sheets, share | Established pattern from Phase 1 |
| Accelerate / vDSP | iOS 17+ (system) | Peak/RMS downsampling for waveform | Hardware-optimized, zero dependencies |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AVFAudio | iOS 17+ (system) | AVAudioSession retry before first playback | Per Phase 1 decision: retry in Phase 2 before playback |
| UniformTypeIdentifiers | iOS 17+ (system) | UTType for export file types | Already used for import |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| AVAssetReader+Writer for WAV | AVAssetExportSession + Passthrough | Passthrough from AAC-source composition to WAV is unreliable on iOS — do not use |
| DSWaveformImage (3rd-party) | Custom vDSP downsampler | Third-party adds SPM dependency; custom implementation is ~60 lines and avoids dependency management complexity |
| ForEach + onMove | List(editActions: .move) binding | The editActions binding syntax has constraints with @Observable; ForEach + onMove is the battle-tested path |

**Installation:** No new SPM packages required for Phase 2. All APIs are system frameworks.

---

## Architecture Patterns

### Recommended Project Structure

```
SonicMerge/
├── App/
│   ├── AppConstants.swift          (existing — unchanged)
│   └── SonicMergeApp.swift         (modified: root → MixingStationView)
├── Models/
│   ├── AudioClip.swift             (existing — unchanged)
│   └── GapTransition.swift         (new — SwiftData model)
├── Services/
│   ├── AudioNormalizationService.swift  (existing — add waveform gen hook)
│   ├── AudioMergerService.swift         (new — actor)
│   └── WaveformService.swift            (new — actor or static funcs)
├── Features/
│   ├── Import/
│   │   ├── ImportView.swift        (retained as empty stub OR deleted)
│   │   └── ImportViewModel.swift   (retired — logic migrated)
│   └── MixingStation/
│       ├── MixingStationView.swift (new — root view)
│       ├── MixingStationViewModel.swift (new — @Observable @MainActor)
│       ├── ClipCardView.swift      (new — clip row with waveform thumbnail)
│       ├── GapRowView.swift        (new — segmented gap/crossfade picker)
│       ├── ExportFormatSheet.swift (new — bottom sheet format picker)
│       └── ExportProgressSheet.swift   (new — non-dismissible progress)
├── Extensions/
│   └── UTType+Audio.swift          (existing — add export types if needed)
└── ContentView.swift               (retained as EmptyView stub per Phase 1 decision)
```

### Pattern 1: AudioMergerService — Actor with AsyncStream Progress

**What:** Builds an `AVMutableComposition` from sorted `AudioClip` array with `GapTransition` metadata, then exports using `AVAssetExportSession` (.m4a) or `AVAssetReader+AVAssetWriter` (.wav). Reports progress via `AsyncStream<Float>`.

**When to use:** Called from MixingStationViewModel during export. Never called directly from a View.

```swift
// Source: established actor pattern from AudioNormalizationService (Phase 1)
actor AudioMergerService {

    enum ExportFormat { case m4a, wav }

    func export(
        clips: [AudioClip],
        transitions: [GapTransition],
        format: ExportFormat,
        destinationURL: URL
    ) -> AsyncStream<Float> {
        AsyncStream { continuation in
            Task {
                do {
                    let composition = try buildComposition(clips: clips, transitions: transitions)
                    switch format {
                    case .m4a:
                        try await exportM4A(composition: composition, to: destinationURL, progress: continuation)
                    case .wav:
                        try await exportWAV(composition: composition, to: destinationURL, progress: continuation)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }
    }

    // m4a path — AVAssetExportSession
    private func exportM4A(composition: AVMutableComposition, to url: URL, progress: AsyncStream<Float>.Continuation) async throws {
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw MergeError.exportSessionUnavailable
        }
        session.outputFileType = .m4a
        session.outputURL = url
        // Progress polling loop
        let pollingTask = Task {
            while !Task.isCancelled {
                progress.yield(session.progress)
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
        // iOS 17 compatible: exportAsynchronously with withCheckedThrowingContinuation
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                pollingTask.cancel()
                if session.status == .completed {
                    cont.resume()
                } else {
                    cont.resume(throwing: session.error ?? MergeError.exportFailed)
                }
            }
        }
        progress.yield(1.0)
    }

    // WAV path — AVAssetReader + AVAssetWriter (Linear PCM)
    private func exportWAV(composition: AVMutableComposition, to url: URL, progress: AsyncStream<Float>.Continuation) async throws {
        // Read from composition as Linear PCM
        let reader = try AVAssetReader(asset: composition)
        let readerOutput = AVAssetReaderAudioMixOutput(audioTracks: composition.tracks(withMediaType: .audio), audioSettings: [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ])
        reader.add(readerOutput)
        // Write as WAV (kAudioFormatLinearPCM in .wav container)
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .wav)
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ])
        writerInput.expectsMediaDataInRealTime = false
        writer.add(writerInput)
        // Estimate total duration for progress
        let totalSeconds = composition.duration.seconds
        writer.startWriting(); reader.startReading()
        writer.startSession(atSourceTime: .zero)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let queue = DispatchQueue(label: "com.sonicmerge.merge.wav", qos: .userInitiated)
            writerInput.requestMediaDataWhenReady(on: queue) {
                while writerInput.isReadyForMoreMediaData {
                    if let buf = readerOutput.copyNextSampleBuffer() {
                        let pts = CMSampleBufferGetPresentationTimeStamp(buf).seconds
                        progress.yield(Float(min(pts / max(totalSeconds, 1), 0.99)))
                        writerInput.append(buf)
                    } else {
                        writerInput.markAsFinished()
                        Task {
                            await writer.finishWriting()
                            continuation.resume()
                        }
                        return
                    }
                }
            }
        }
        if writer.status == .failed { throw writer.error ?? MergeError.exportFailed }
        progress.yield(1.0)
    }
}
```

### Pattern 2: AVMutableComposition Assembly with Gaps and Crossfades

**What:** Iterate sorted clips and transitions. For each clip: insert its time range. If the following transition is a silence gap: insert empty time range at composition cursor. If crossfade: overlap the next clip by 0.5s (crossfade duration) and add volume ramps via `AVMutableAudioMixInputParameters`.

**When to use:** Inside `AudioMergerService.buildComposition()`.

```swift
// Source: Apple AVFoundation Editing guide + AVMutableAudioMixInputParameters docs
private func buildComposition(clips: [AudioClip], transitions: [GapTransition]) throws -> AVMutableComposition {
    let composition = AVMutableComposition()
    guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
        throw MergeError.trackCreationFailed
    }
    let audioMixParams = AVMutableAudioMixInputParameters(track: track)
    var cursor = CMTime.zero

    for (index, clip) in clips.enumerated() {
        let asset = AVURLAsset(url: try clip.fileURL)
        guard let sourceTrack = try await asset.loadTracks(withMediaType: .audio).first else { continue }
        let clipDuration = try await asset.load(.duration)
        let timeRange = CMTimeRange(start: .zero, duration: clipDuration)

        try track.insertTimeRange(timeRange, of: sourceTrack, at: cursor)

        // Gap/crossfade after this clip (not after the last)
        let transition = transitions.first(where: { $0.leadingClipSortOrder == clip.sortOrder })
        if let t = transition {
            if t.isCrossfade {
                // Overlap next clip by crossfade duration
                let crossDur = CMTimeMakeWithSeconds(0.5, preferredTimescale: 48_000)
                let fadeOutRange = CMTimeRange(start: cursor + clipDuration - crossDur, duration: crossDur)
                audioMixParams.setVolumeRamp(fromStartVolume: 1.0, toEndVolume: 0.0, timeRange: fadeOutRange)
                // Fade-in for next clip set after its insert — use separate params or same track params
                cursor = cursor + clipDuration - crossDur  // overlap
            } else {
                // Silence gap
                let gapDur = CMTimeMakeWithSeconds(t.gapDuration, preferredTimescale: 48_000)
                cursor = cursor + clipDuration
                track.insertEmptyTimeRange(CMTimeRange(start: cursor, duration: gapDur))
                cursor = cursor + gapDur
            }
        } else {
            cursor = cursor + clipDuration
        }
    }
    return composition
    // Note: pass audioMixParams to AVAssetExportSession.audioMix for crossfades
}
```

### Pattern 3: Waveform Generation

**What:** After normalization completes, read the normalized .m4a with `AVAssetReader`, downsample to N peak values using `vDSP_maxv` (or simple loop), write as `[Float32]` binary to `UUID.waveform` sidecar file.

**When to use:** Called at the end of `AudioNormalizationService.normalize()`, or as a separate `WaveformService.generate()` call in `MixingStationViewModel.importFiles()` immediately after normalization.

```swift
// Source: vDSP documentation; peak downsampling pattern from multiple iOS audio tutorials
actor WaveformService {
    static let barCount: Int = 50  // ~60pt width, ~1.2pt per bar at 1x — Claude's discretion

    func generate(audioURL: URL, destinationURL: URL) async throws {
        let asset = AVURLAsset(url: audioURL)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ])
        reader.add(output)
        reader.startReading()

        var allSamples: [Float] = []
        while let buf = output.copyNextSampleBuffer(), let blockBuf = CMSampleBufferGetDataBuffer(buf) {
            var length = 0; var ptr: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(blockBuf, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &ptr)
            if let ptr {
                let count = length / MemoryLayout<Float>.size
                let floats = UnsafeBufferPointer(start: ptr.withMemoryRebound(to: Float.self, capacity: count) { $0 }, count: count)
                allSamples.append(contentsOf: floats)
            }
        }

        guard !allSamples.isEmpty else { return }
        let chunkSize = max(allSamples.count / Self.barCount, 1)
        var peaks: [Float] = (0..<Self.barCount).map { i in
            let start = i * chunkSize
            let end = min(start + chunkSize, allSamples.count)
            guard start < end else { return 0 }
            var peak: Float = 0
            vDSP_maxmgv(Array(allSamples[start..<end]), 1, &peak, vDSP_Length(end - start))
            return peak
        }

        // Normalize peak array to 0...1
        var maxPeak: Float = 0
        vDSP_maxv(peaks, 1, &maxPeak, vDSP_Length(peaks.count))
        if maxPeak > 0 { vDSP_vsdiv(peaks, 1, &maxPeak, &peaks, 1, vDSP_Length(peaks.count)) }

        let data = Data(bytes: peaks, count: peaks.count * MemoryLayout<Float>.size)
        try data.write(to: destinationURL)
    }
}
```

### Pattern 4: SwiftUI Drag-to-Reorder with sortOrder Persistence

**What:** Use `ForEach` + `.onMove` inside a `List`. In the move handler, call `move(fromOffsets:toOffset:)` on the local array, then re-assign `sortOrder` to each clip's new index, and save the `ModelContext`.

**When to use:** MixingStationView List body.

```swift
// Source: Hacking with Swift SwiftUI List onMove; sarunw.com SwiftUI List reordering
List {
    ForEach(viewModel.clips) { clip in
        ClipCardView(clip: clip)
    }
    .onMove { from, to in
        viewModel.moveClip(fromOffsets: from, toOffset: to)
    }
    .onDelete { offsets in
        viewModel.deleteClip(atOffsets: offsets)
    }
}
.environment(\.editMode, .constant(.active))  // Always in edit mode for drag handles
```

```swift
// In MixingStationViewModel
func moveClip(fromOffsets: IndexSet, toOffset: Int) {
    clips.move(fromOffsets: fromOffsets, toOffset: toOffset)
    for (index, clip) in clips.enumerated() {
        clip.sortOrder = index
    }
    try? modelContext.save()
}
```

### Pattern 5: Non-Dismissible Export Progress Sheet

**What:** Use `.sheet(isPresented:)` with `.interactiveDismissDisabled(true)` for the progress modal. Use `.presentationDetents([.medium])` for the format picker bottom sheet.

```swift
// Source: Apple Developer Docs — interactiveDismissDisabled(_:)
.sheet(isPresented: $viewModel.isExporting) {
    ExportProgressSheet(
        progress: viewModel.exportProgress,
        onCancel: { viewModel.cancelExport() }
    )
    .interactiveDismissDisabled(true)
    .presentationDetents([.medium])
}
```

### Pattern 6: Share Sheet — UIActivityViewController via UIViewControllerRepresentable

**What:** Wrap `UIActivityViewController` in a `UIViewControllerRepresentable` for file sharing. Avoid `ShareLink` for internal file URLs on iOS 17+ (known issue with Files app).

```swift
// Source: Juniperphoton substack post on iOS 17 Transferable issue; nemecek.be UIActivityViewController tips
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Usage: present when export completes
.sheet(isPresented: $viewModel.showShareSheet) {
    ActivityViewController(activityItems: [viewModel.exportedFileURL!])
}
```

### Anti-Patterns to Avoid

- **Exporting WAV via AVAssetExportSession from AAC composition:** Passthrough from AAC to WAV is unreliable. Use AVAssetReader+AVAssetWriter for WAV path.
- **Storing waveform data as `Data` blob in SwiftData:** Binary blobs on `@Model` can cause model migration issues. Store as sidecar file (decided).
- **Marking AVMutableComposition or AVAssetExportSession with @MainActor:** Swift 6 isolation violation — these types are non-Sendable and must stay within the actor that creates them. Per samsonjs gist: remove `@MainActor` from the class containing the export session.
- **Using ShareLink for internal file URLs on iOS 17+:** Silent failure when user taps "Save to Files". Use `UIActivityViewController` wrapping instead.
- **Observing `AVAssetExportSession.progress` with KVO:** The `progress` property is not KVO-observable. Poll it on a timer or Task loop.
- **Putting AVFoundation composition assembly on @MainActor:** Composition build is blocking-ish — keep it on the background actor.
- **Deleting a clip without cleaning up sidecar files:** Always delete both the audio `.m4a` and the `.waveform` sidecar from the App Group container when removing an `AudioClip`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Audio composition sequencing | Custom byte concatenation | `AVMutableComposition` + `insertTimeRange` | Handles timing, format negotiation, gapless boundaries correctly |
| Volume ramps / crossfades | Manual PCM buffer manipulation | `AVMutableAudioMixInputParameters.setVolumeRamp` | Time-domain ramps with sample accuracy; hardware-accelerated in export |
| PCM peak analysis | FFT or custom loop | `vDSP_maxmgv` | 10-100x faster than naive Swift loop on large sample buffers |
| Export progress | Custom AVAssetExportSession subclass | Poll `.progress` property at 100ms interval | The property is designed for polling; KVO does not work |
| File sharing | Custom share UI | `UIActivityViewController` | Handles all iOS share targets; ShareLink has iOS 17 file URL bug |

**Key insight:** AVFoundation's composition model is the correct abstraction layer for this problem. Attempting to merge audio at the PCM level manually (outside of AVMutableComposition) introduces sample-rate edge cases, timing drift, and gap positioning errors that the composition model handles automatically.

---

## Common Pitfalls

### Pitfall 1: WAV Export from AAC Source via AVAssetExportSession

**What goes wrong:** Using `AVAssetExportSession` with `AVFileType.wav` and `AVAssetExportPresetPassthrough` on a composition whose tracks contain AAC-encoded audio (the normalized `.m4a` clips) fails silently or produces a corrupt output on iOS 17+. AVAssetExportPresetPassthrough cannot re-contain AAC as WAV, and alternative presets do not support WAV output.

**Why it happens:** AVAssetExportSession's WAV support requires the source to be PCM (Linear PCM passthrough). AAC is a compressed codec; the export session cannot decode AAC and re-encode to PCM in the WAV path.

**How to avoid:** Branch on format in `AudioMergerService`. For `.wav`, use the `AVAssetReader` + `AVAssetWriter` pipeline: read composition as Linear PCM float32, write to `.wav` container with Linear PCM int16 settings.

**Warning signs:** Export session status `.failed` with error "The operation could not be completed" when outputFileType is `.wav`.

### Pitfall 2: AVMutableComposition / AVAssetExportSession in Swift 6 @MainActor Context

**What goes wrong:** Placing the export session or composition inside a `@MainActor` class causes Swift 6 data-race warnings (or errors with strict concurrency) because these AVFoundation types are not `Sendable`.

**Why it happens:** Swift 6 enforces Sendable checking. `AVMutableComposition` is not `Sendable`. Sending it across actor boundaries (from an actor-isolated method to `exportAsynchronously`) triggers warnings.

**How to avoid:** Keep `AVMutableComposition` and `AVAssetExportSession` fully inside the `AudioMergerService` actor. The ViewModel calls `await mergerService.export(...)` and receives only primitive values (URL, Float) back. Do NOT store AVFoundation objects as `@MainActor` properties.

**Warning signs:** Swift compiler warning "Sending value of non-Sendable type across actor boundary."

### Pitfall 3: Crossfade Composition — Overlapping Track Inserts

**What goes wrong:** Inserting the crossfade clip at `cursor - crossfadeDuration` (to overlap) without adding a second audio track causes the overlap region to replace the end of the previous clip instead of mixing.

**Why it happens:** A single `AVMutableCompositionTrack` cannot have two segments at the same time position. Overlapping on one track is a time-range conflict.

**How to avoid:** Use TWO audio tracks in the composition for crossfade transitions. Track A holds the full first clip; Track B holds the second clip starting at the overlap point. Both tracks are rendered mixed by the export session. Apply volume ramps (fade-out on Track A, fade-in on Track B) via `AVMutableAudioMixInputParameters`.

**Warning signs:** Silence or abrupt cut in the crossfade region instead of a smooth blend.

### Pitfall 4: GapTransition Relationship — Both Sides Optional

**What goes wrong:** Making `GapTransition.audioClip` a non-optional relationship in SwiftData causes an insert ordering constraint: you cannot create a `GapTransition` before the `AudioClip` exists, but the relationship makes the compiler require it.

**Why it happens:** SwiftData infers one-to-one relationships. If both sides are non-optional, SwiftData cannot resolve the "which gets created first?" bootstrapping problem.

**How to avoid:** Declare the `@Relationship` inverse on `GapTransition.audioClip` as `AudioClip?` (optional). The `AudioClip` side can hold `var gapTransition: GapTransition?` as optional too. Both sides optional lets SwiftData manage the inverse relationship automatically.

**Warning signs:** SwiftData crash at insert time with "constraint violation" or "object graph inconsistency."

### Pitfall 5: sortOrder Re-assignment After Clip Deletion

**What goes wrong:** After deleting a clip at index N, the remaining clips have `sortOrder` values with a gap (e.g., 0, 1, 3, 4). The `FetchDescriptor` sort still works, but the gap causes `GapTransition.leadingClipSortOrder` lookups to misidentify which gap follows which clip.

**Why it happens:** `GapTransition` is linked to `AudioClip` by relationship, not by sort order integer. But if you query transitions by `sortOrder` integer value in merge logic, gaps create bugs.

**How to avoid:** Always re-assign contiguous `sortOrder` (0, 1, 2, ...) to all clips after any deletion or move operation. Alternatively, use the SwiftData relationship directly: `clip.gapTransition` rather than looking up by sort order integer.

### Pitfall 6: Waveform Sidecar File Orphan on Import Failure

**What goes wrong:** If normalization succeeds but waveform generation fails, the `.m4a` file is persisted but the `.waveform` sidecar is missing. The clip card displays a broken waveform indefinitely.

**Why it happens:** Waveform generation failure is silent (it's non-critical). The view tries to load a missing file.

**How to avoid:** Generate waveform before persisting the `AudioClip`. If waveform generation fails, log the error and use an empty peaks array (render a flat bar). Never crash or block import for a missing waveform.

### Pitfall 7: ShareLink iOS 17 "Save to Files" Silent Failure

**What goes wrong:** Using `ShareLink(item: exportedURL)` works for AirDrop, Messages, etc. but silently fails for "Save to Files" on iOS 17. The Files app launches, shows a blank view, then dismisses without saving.

**Why it happens:** iOS 17 sandbox restrictions prevent the SaveToFiles process from reading internal App Group container files when using `FileRepresentation`. The bug is undocumented by Apple.

**How to avoid:** Use `UIActivityViewController` wrapped in a `UIViewControllerRepresentable`. This API correctly handles App Group file URLs for all share destinations including Files.

### Pitfall 8: AVAssetExportSession.cancelExport() Leaves Partial File

**What goes wrong:** After cancelling an export, the partial output file remains on disk. If the user re-exports to the same destination URL, `AVAssetExportSession` fails with "file already exists."

**Why it happens:** `cancelExport()` stops writing immediately; it does not clean up the output file.

**How to avoid:** After calling `cancelExport()`, delete the output file via `FileManager.default.removeItem(at: destinationURL)`. Do this in the ViewModel's cancel handler before returning to idle state.

---

## Code Examples

### GapTransition SwiftData Model

```swift
// Claude's discretion for field choices; pattern mirrors AudioClip
@Model
final class GapTransition {
    /// sortOrder of the AudioClip that PRECEDES this gap.
    /// Lookup: clips.first(where: { $0.sortOrder == leadingClipSortOrder })
    var leadingClipSortOrder: Int
    /// Silence gap duration in seconds. Ignored when isCrossfade is true.
    var gapDuration: Double  // 0.5, 1.0, or 2.0
    /// When true, apply 0.5s crossfade instead of silence gap.
    var isCrossfade: Bool

    @Relationship(deleteRule: .nullify, inverse: \AudioClip.gapTransition)
    var audioClip: AudioClip?

    init(leadingClipSortOrder: Int, gapDuration: Double = 0.5, isCrossfade: Bool = false) {
        self.leadingClipSortOrder = leadingClipSortOrder
        self.gapDuration = gapDuration
        self.isCrossfade = false
    }
}

// Extension to AudioClip (add in AudioClip.swift):
// @Relationship var gapTransition: GapTransition?
```

### MixingStationViewModel Skeleton

```swift
// Pattern: mirrors ImportViewModel from Phase 1
@Observable
@MainActor
final class MixingStationViewModel {
    private(set) var clips: [AudioClip] = []
    private(set) var transitions: [GapTransition] = []
    private(set) var isImporting = false
    private(set) var isExporting = false
    private(set) var exportProgress: Float = 0
    private(set) var exportedFileURL: URL? = nil
    private(set) var showShareSheet = false
    var importErrors: [String] = []

    private let modelContext: ModelContext
    private let normalizationService = AudioNormalizationService()
    private let waveformService = WaveformService()
    private let mergerService = AudioMergerService()
    private var exportTask: Task<Void, Never>?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchAll()
    }

    func exportMerged(format: AudioMergerService.ExportFormat) {
        exportTask = Task {
            isExporting = true
            exportProgress = 0
            let destURL = /* temp file URL */
            let stream = await mergerService.export(clips: clips, transitions: transitions, format: format, destinationURL: destURL)
            for await progress in stream {
                exportProgress = progress
                if Task.isCancelled { break }
            }
            if !Task.isCancelled {
                exportedFileURL = destURL
                showShareSheet = true
            }
            isExporting = false
        }
    }

    func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        // delete partial file
    }
}
```

### SonicMergeApp.swift — Root Switch

```swift
// Phase 2 change: replace ImportView with MixingStationView
// Also add GapTransition to schema
var body: some Scene {
    WindowGroup {
        MixingStationView()
            .environment(MixingStationViewModel(modelContext: modelContainer.mainContext))
    }
    .modelContainer(modelContainer)
}

// Schema update:
let schema = Schema([AudioClip.self, GapTransition.self])
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `exportAsynchronously(completionHandler:)` | `export(to:as:isolation:)` async | iOS 18 / Xcode 16 | New API is cleaner but iOS 18+ only; must use `exportAsynchronously` with `withCheckedThrowingContinuation` for iOS 17 target |
| `ShareLink` for file sharing | `UIActivityViewController` wrapper | iOS 17 bug (undocumented) | ShareLink fails with Files app on iOS 17; use UIActivityViewController |
| KVO on `AVAssetExportSession.progress` | Timer/Task polling at 100ms | Always been the case | Progress is never KVO-observable; polling is the documented approach |
| Two-track crossfade approach | Single-track with overlap + AVAudioMix | N/A | Two-track is always required for correct crossfade mixing |

**Deprecated/outdated:**
- `AVAssetExportSession.exportAsynchronously()` (callback form): Still works on iOS 17, but superseded by `export(to:as:isolation:)` on iOS 18+. Since deployment target is iOS 17, use the callback form with `withCheckedThrowingContinuation` wrapper.

---

## Open Questions

1. **GapTransition relationship: 1-to-1 vs sortOrder-based lookup**
   - What we know: SwiftData 1-to-1 relationships require both sides optional; sortOrder is already on AudioClip
   - What's unclear: Whether to store `var gapTransition: GapTransition?` on AudioClip or look up by `leadingClipSortOrder` at merge time
   - Recommendation (Claude's discretion): Use the SwiftData relationship (`AudioClip.gapTransition`) for correctness; `leadingClipSortOrder` is a denormalized convenience for debugging only

2. **Waveform bar count at 60pt width**
   - What we know: 60pt at 1x = 60px, 3x = 180px; a bar + gap of ~3px gives ~60 bars at 1x
   - What's unclear: Whether to render at density-aware count or fixed 50 bars
   - Recommendation (Claude's discretion): Fixed 50 bars. Easy to regenerate; visually consistent across devices.

3. **AVAssetExportSession for WAV on iOS 17 — final confirmation**
   - What we know: Multiple sources indicate AAC-to-WAV via AVAssetExportSession is unreliable; AVAssetReader+Writer pattern is confirmed to work
   - What's unclear: Whether Apple fixed this in iOS 17 or 18
   - Recommendation: Implement the AVAssetReader+Writer WAV path regardless. It is the safe, correct, well-documented approach. Do not rely on passthrough.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (import Testing) |
| Config file | None — PBXFileSystemSynchronizedRootGroup auto-includes all files in SonicMergeTests/ |
| Quick run command | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing SonicMergeTests 2>&1 \| xcpretty` |
| Full suite command | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 \| xcpretty` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| IMP-04 | WaveformService generates non-empty peaks for a valid audio URL | unit | `xcodebuild test ... -only-testing SonicMergeTests/WaveformServiceTests` | ❌ Wave 0 |
| IMP-04 | Sidecar .waveform file written at expected path in temp directory | unit | `xcodebuild test ... -only-testing SonicMergeTests/WaveformServiceTests` | ❌ Wave 0 |
| MRG-01 | moveClip(fromOffsets:toOffset:) reassigns contiguous sortOrder | unit | `xcodebuild test ... -only-testing SonicMergeTests/MixingStationViewModelTests` | ❌ Wave 0 |
| MRG-02 | deleteClip removes AudioClip and its GapTransition from context | unit | `xcodebuild test ... -only-testing SonicMergeTests/MixingStationViewModelTests` | ❌ Wave 0 |
| MRG-03 | AudioMergerService builds composition with correct total duration given 2 clips + 1.0s gap | unit | `xcodebuild test ... -only-testing SonicMergeTests/AudioMergerServiceTests` | ❌ Wave 0 |
| MRG-04 | AudioMergerService applies volume ramps for crossfade (audioMix non-nil with inputParameters) | unit | `xcodebuild test ... -only-testing SonicMergeTests/AudioMergerServiceTests` | ❌ Wave 0 |
| EXP-01 | AudioMergerService exports valid .m4a file (non-zero byte size, valid AVAsset) | integration | `xcodebuild test ... -only-testing SonicMergeTests/AudioMergerServiceTests` | ❌ Wave 0 |
| EXP-02 | AudioMergerService exports valid .wav file (non-zero bytes, AVAsset loads with audio track) | integration | `xcodebuild test ... -only-testing SonicMergeTests/AudioMergerServiceTests` | ❌ Wave 0 |
| EXP-04 | Export can be cancelled mid-flight; partial file deleted after cancel | unit | `xcodebuild test ... -only-testing SonicMergeTests/MixingStationViewModelTests` | ❌ Wave 0 |
| UX-01 | Theme constants (colors, cornerRadius) match spec values | unit | `xcodebuild test ... -only-testing SonicMergeTests/ThemeTests` | ❌ Wave 0 (optional/low value) |

**Manual-only:** Drag-to-reorder visual behavior, share sheet presentation after export, non-dismissible modal sheet interaction — these are UI gestures that cannot be asserted in headless XCTest/Swift Testing.

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing SonicMergeTests/<RelevantTestClass> 2>&1 | xcpretty`
- **Per wave merge:** Full suite: `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | xcpretty`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `SonicMergeTests/WaveformServiceTests.swift` — covers IMP-04
- [ ] `SonicMergeTests/AudioMergerServiceTests.swift` — covers MRG-03, MRG-04, EXP-01, EXP-02
- [ ] `SonicMergeTests/MixingStationViewModelTests.swift` — covers MRG-01, MRG-02, EXP-04
- [ ] Audio fixtures: `stereo_48000.m4a` already exists from Phase 1; confirm fixture bundle membership for test target

---

## Sources

### Primary (HIGH confidence)
- Apple AVFoundation Editing documentation — AVMutableComposition, insertTimeRange, insertEmptyTimeRange, AVMutableAudioMixInputParameters.setVolumeRamp
- Apple Developer Docs — AVAssetExportSession.progress (not KVO-observable, polling documented)
- Apple Developer Docs — interactiveDismissDisabled(_:) modifier
- Swift 6 + AVAssetExportSession gist (samsonjs): https://gist.github.com/samsonjs/2f006c5f62f53c9aef820bc050e37809 — avoidance of @MainActor on export classes
- Hacking with Swift — SwiftUI List onMove: https://www.hackingwithswift.com/quick-start/swiftui/how-to-let-users-move-rows-in-a-list
- Hacking with Swift — SwiftData one-to-one relationships: https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-one-to-one-relationships

### Secondary (MEDIUM confidence)
- Juniperphoton substack — iOS 17 Transferable/ShareLink file URL bug + UIActivityViewController workaround: https://juniperphoton.substack.com/p/addressing-and-solving-transferable (verified against Apple Developer Forums reports)
- sarunw.com — SwiftUI Bottom Sheet with presentationDetents + interactiveDismissDisabled: https://sarunw.com/posts/swiftui-interactive-dismiss-disabled/
- Medium (gmcerveny) — concatenating audio in Swift with AVMutableComposition: https://gmcerveny.medium.com/a-quick-ish-way-to-concatenate-audio-in-swift-e589ee957a5a

### Tertiary (LOW confidence, flagged for validation)
- appsloveworld — AVAssetExportSession WAV from AAC failure pattern (multiple iOS versions reported, not all confirmed on iOS 17): https://www.appsloveworld.com/coding/ios/212/avmutablecompositiontrack-using-insertemptytimerange-to-insert-silence-between
- General community: AVAssetExportSession WAV passthrough from AAC is unreliable — use AVAssetReader+Writer. Not formally documented by Apple but consistent across multiple forum posts.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all system frameworks, no third-party SPM dependencies
- Architecture patterns: HIGH — mirrors proven Phase 1 actor/ViewModel pattern; composition API is stable
- WAV export path: MEDIUM — AVAssetReader+Writer for WAV is the documented workaround; AVAssetExportSession WAV limitation is community-verified but not formally documented by Apple
- Pitfalls: HIGH for items backed by official docs; MEDIUM for WAV export and ShareLink iOS 17 bugs (community-verified)
- Crossfade two-track requirement: HIGH — directly follows from AVMutableCompositionTrack time-range exclusivity

**Research date:** 2026-03-10
**Valid until:** 2026-06-10 (AVFoundation APIs are stable; SwiftData relationship behavior may change with new Xcode versions)
