# Many-Source Audio Import — Files / Record / Photos

**Date:** 2026-05-08
**Status:** Spec — implementation-ready
**Author:** Claude (autonomous mode, user-approved decisions)
**Source:** User request — "support many source. Currently, only support import from file"

## Summary

Today every Import button in CleanCut routes straight to `.fileImporter`, which means the user only sees iOS's document picker. The user wants the Import button to surface multiple **sources**: the existing Files / iCloud Drive picker, an in-app **microphone recorder**, and the **Photos & Videos** library (with audio-track extraction from videos). All three home tabs — Smart Cut, Denoise, Merge — get the same Source Picker sheet.

Recording is intentionally minimal: a single sheet with a record/stop button, an elapsed-time readout, and a live level meter — no pause/resume, no in-sheet trim. Smart Cut and Denoise already operate on the audio post-import, so trimming inside the recorder would duplicate work.

The work is shaped to mirror the existing `CircularImportButton` pattern: one shared sheet view consumed by all three home views, with a per-tab callback for "audio is ready at this URL — do your thing."

## Goals

1. **Three sources from every tab's Import button**: Files / iCloud Drive (current behavior), Record (new), Photos & Videos (new).
2. **One reusable Source Picker sheet** — three home views call it the same way. No copy-paste of the source list.
3. **Stay surgical**: don't refactor existing import code, don't introduce a generic "AudioImportService" omnibus. Files / iCloud Drive remains exactly as it is today.
4. **Reuse existing free-tier gates** — recordings and extracted-from-video audio go through the same `ImportDecision.gate(...)` length and quota checks the file picker uses today.
5. **Preserve `FAIL=5` baseline** — no new flaky tests, existing 233-test suite stays green.

## Non-Goals

- **No URL paste / podcast-link import.** Considered and dropped — small audience, copyright-fraught.
- **No Voice Memos picker.** iOS doesn't expose Voice Memos as a programmatic source. Users reach voice memos via either the existing Share Extension (Voice Memos → Share → CleanCut) or via Files if iCloud Voice Memo sync is on. We'll add a one-line tip in the empty state but not a dedicated source row.
- **No Apple Music / iTunes Library picker.** DRM-protected tracks can't be exported, the non-DRM subset is small, and `MPMediaPicker` UX is dated.
- **No pause / resume / trim in the recorder.** User selected the Minimal recorder option (option A in the visual companion). Pause/resume is a follow-up if we hear demand.
- **No background recording.** Recorder stops on backgrounding (saves what's captured so far + offers Save).
- **No multi-select PHPicker.** Single video at a time. Multi-clip workflows belong in the Merge tab itself, not the import flow.
- **No share extension changes.** Out of scope for this spec — see future work.

## Architecture

```
                                          ┌─────────────────────────────┐
                                          │  CircularImportButton (tap) │
                                          │   (existing — 6 callsites)  │
                                          └──────────────┬──────────────┘
                                                         │ flips @State showSourceSheet = true
                                                         ▼
                          ┌──────────────────────────────────────────────────────┐
                          │  ImportSourceSheet  (new, shared component)          │
                          │   3 rows: Files · Record · Photos & Videos           │
                          │   Cancel.                                            │
                          │   Each row dispatches the chosen source action:      │
                          └──┬─────────────────────┬─────────────────────────┬───┘
                             │ Files               │ Record                  │ Photos
                             ▼                     ▼                         ▼
              ┌────────────────────┐  ┌────────────────────────┐  ┌────────────────────────┐
              │ .fileImporter       │  │ RecorderSheet           │  │ PHPickerWrapper         │
              │ (existing)          │  │ (new)                   │  │ (new, UIViewController- │
              │ allowed: audio types│  │  · AudioRecorderService │  │  Representable)         │
              │                     │  │  · level meter, timer   │  │  filter: .videos        │
              │                     │  │  · Cancel · Save        │  │  selectionLimit: 1      │
              └─────────┬──────────┘  └────────────┬────────────┘  └────────────┬────────────┘
                        │ URL                       │ URL (m4a temp)             │ PHPickerResult
                        │                           │                            │ → VideoAudioExtractor
                        │                           │                            │   .extract(...) → URL (m4a)
                        ▼                           ▼                            ▼
                                ┌────────────────────────────────────────┐
                                │  Per-tab callback: (URL) -> Void        │
                                │   · SmartCutHomeView → createSession    │
                                │   · DenoiseHomeView  → createSession    │
                                │   · Merge (timeline) → append clip      │
                                └────────────────────────────────────────┘
```

### Key behaviors

**ImportSourceSheet (shared):**
- Modal `.sheet` with detent `[.height(280)]` (fixed-height bottom card).
- Three full-width rows, each with system icon + label + chevron, styled with `studioFrostedCapsule` to match the existing design system.
- Indigo accent (`semantic.accentAction`) for the icons — these are *navigation* (move-data) actions, not AI moments. Matches the established two-color brand discipline (see `feedback_color_discipline.md`).
- The sheet itself doesn't perform the import; it dispatches one of three closures the parent passed in (`onPickFiles`, `onRecord`, `onPickPhotos`).
- Tapping a row dismisses the sheet and triggers the parent state flag for that source's presenter (the file importer / recorder sheet / PHPicker).

**RecorderSheet (Minimal recorder, option A):**
- Modal `.sheet` with detent `[.medium, .large]`.
- Top row: `Cancel` (left) — "New Recording" title — `Save` (right, disabled until duration > 0.3s).
- Center: large numeric timer (e.g. `0:23`) using `.font(.system(size: 44, weight: .ultraLight, design: .rounded))` with `.monospacedDigit()`.
- Below timer: 10-bar level meter, animated from `AVAudioRecorder.averagePower(forChannel:)` polled at 20 Hz.
- Below meter: single circular **Stop** button (88pt) when recording, **Record** button when idle. Tapping Record starts capture; tapping Stop ends it. No pause.
- Save → invokes parent callback with the temp URL → sheet dismisses → tab takes over (same path as Files / Photos).
- Cancel → discards the temp file and dismisses.
- Permission denied path (mic): show inline "Enable microphone in Settings" with a Settings deep-link button, replacing the recorder controls.

**AudioRecorderService (new actor):**
- Wraps `AVAudioRecorder`. Output settings: linear PCM input internally for power readings, but final file is **AAC `.m4a` at 44.1 kHz, mono, 128 kbps** to match the rest of the app's export defaults and stay compatible with `AVAsset` decode.
- Public surface:
  - `start() async throws` — requests `AVAudioSession.sharedInstance().requestRecordPermission`, configures category `.playAndRecord` with options `[.defaultToSpeaker, .allowBluetooth]`, starts the recorder, writes to `FileManager.default.temporaryDirectory.appendingPathComponent("recording-\(UUID()).m4a")`.
  - `stop() async throws -> URL` — stops, returns the file URL.
  - `cancel()` — stops and deletes the temp file.
  - `@Published var elapsedSeconds: TimeInterval` — driven by a `Timer` polling `recorder.currentTime` at 10 Hz.
  - `@Published var levelNormalized: Float` — driven by `recorder.averagePower(forChannel:)` at 20 Hz, mapped from dB to [0, 1] via the same `pow(10, dB/20)` curve `WaveformService` uses.
- Permission flow: if the user previously denied mic access, `requestRecordPermission` returns `false` immediately — the service throws `RecorderError.micPermissionDenied`, the sheet renders the Settings deep-link state.

**VideoAudioExtractor (new):**
- Pure-function struct: `static func extractAudio(from videoURL: URL) async throws -> URL`.
- Loads the video asset, finds the first audio track, exports via `AVAssetExportSession` with preset `AVAssetExportPresetAppleM4A` to `<temp>/extracted-\(UUID()).m4a`.
- Throws `ExtractError.noAudioTrack` if the video has no audio (silent video).
- Throws `ExtractError.exportFailed(Error)` with the underlying error otherwise.

**PHPickerWrapper (new):**
- `UIViewControllerRepresentable` wrapping `PHPickerViewController`.
- Configuration: `filter = .videos`, `selectionLimit = 1`, `preferredAssetRepresentationMode = .current`.
- `Coordinator` implements `PHPickerViewControllerDelegate`. On `picker(_:didFinishPicking:)`:
  - Dismiss picker.
  - `loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier)` to copy the video to a temp file (PHAsset URLs are not directly accessible without `loadFileRepresentation`).
  - Hand off to `VideoAudioExtractor.extractAudio(from:)`.
  - Invoke the parent's `onPickPhotos: (URL) -> Void` closure with the extracted m4a URL.
- No photo-library `NSPhotoLibraryUsageDescription` is required for `PHPickerViewController` (Apple-mediated, runs out-of-process). This is the explicit win over `UIImagePickerController`.

**Per-tab wiring:**
- `SmartCutHomeView` — already has `createSession(from: URL) async`. Source sheet's three callbacks all funnel into the existing `createSession`. Zero changes to downstream session creation.
- `DenoiseHomeView` — same: existing `createSession(from:)` is the funnel.
- `MergeTimelineView` / `MixingStationView` — both currently route file picks into the clips list via the existing add-clip code path. The three callbacks funnel there.

In each tab the change is a thin diff: replace `showFileImporter = true` with `showSourceSheet = true`, add the `ImportSourceSheet` modifier with three closures (one of which is the existing file-import action it had before).

### Data flow

For all three sources, the imported file ultimately becomes:
1. A temp URL in `FileManager.default.temporaryDirectory`.
2. Validated by loading `AVURLAsset(url:).load(.duration)` (existing pattern in `SmartCutHomeView.createSession` line 172).
3. Gated by `ImportDecision.gate(durationSeconds:entitlements:)` (existing — handles 5-min cap and 3-session/day quota for Free tier).
4. Copied to its tab's per-session directory via `AppConstants.smartCutSessionDirectory(for:)` / `AppConstants.denoiseSessionDirectory(for:)` / `AppConstants.clipsDirectory()` (existing helpers).
5. Original temp file removed after the copy.

The `createSession(from:)` flow in each home view doesn't need to know which source the URL came from — it just receives a URL. This is what makes the three-source design cheap.

### Error handling

| Source | Error | UX |
|---|---|---|
| Files | invalid audio file | "This file isn't a valid audio recording." (existing alert) |
| Record | mic permission denied | Inline state in recorder sheet with "Open Settings" button |
| Record | starting recording failed | Toast "Couldn't start recording. \(localizedDescription)" |
| Record | save failed | Toast "Couldn't save recording. \(localizedDescription)" |
| Photos | no audio track | Alert "This video has no audio to import." |
| Photos | extract failed | Alert "Couldn't extract audio. \(localizedDescription)" |
| All | duration exceeds Free cap | Existing paywall sheet (`paywallReason`) |

The existing `importErrorMessage: String?` alert plumbing in each home view is reused for all three new error paths.

### Permissions / Info.plist additions

- **`NSMicrophoneUsageDescription`** (required for record):
  > *"CleanCut records voice using the microphone so you can capture and clean audio without leaving the app. Recordings stay on your device."*
- **`NSPhotoLibraryUsageDescription`** is **NOT required** because `PHPickerViewController` runs out-of-process and doesn't request library access. (Confirmed: WWDC 2020 "Meet the new Photos picker.")
- **`AVAudioSession`** is configured per-recording, not persistent — restored after `stop()` so background playback in other parts of the app isn't affected.

### Free-tier gates

Recording and Photos extraction both produce a finished URL with a known duration (post-stop or post-extract). They flow through the **same** `ImportDecision.gate(durationSeconds:entitlements:)` call the file picker already uses:

- Free user records 6 minutes → gate triggers paywall (5-min cap).
- Free user already used 3 Smart Cut sessions today → gate triggers paywall (quota).
- Free user picks a 30-second video → fine, Smart Cut session created.

`entitlements.recordSmartCutSession()` (existing) is called after a successful recording too — recording counts as a session.

### Testing

**Swift Testing (`@Test`, `#expect`) per project convention.** New test files:

- `ImportSourceSheetTests.swift` — verify each row's tap dispatches the correct callback (use closures + flags). View-level test using SwiftUI's `Inspector` pattern already in the project.
- `AudioRecorderServiceTests.swift` — start → stop → returns valid m4a; cancel → temp file deleted; permission denied path throws `.micPermissionDenied`. Mic permission status mocked via a `RecordPermissionProvider` protocol seam.
- `VideoAudioExtractorTests.swift` — extract from fixture video → returns m4a, duration matches video; extract from fixture silent video → throws `.noAudioTrack`. Use a 2-second test video committed to `SonicMergeTests/Fixtures/`.
- `ImportDecisionGatingTests.swift` — extend existing tests so a mocked recorded URL with duration > 5 min hits the paywall (no new gate logic, just verifying the funnel).

**No regression of `FAIL=5` baseline.** The five known-failing tests on `main` are all unrelated (AudioMerger crossfade, Share Extension entitlement-gated, A/B playback flake) — none touch the import surface.

**Manual QA checklist** will live at `docs/superpowers/qa/2026-05-08-import-sources-manual-qa.md` covering: mic permission first-run prompt, Settings-redirect path, recording while connected to Bluetooth headphones, picking an iCloud-Drive video that needs to download first, picking a video with no audio.

### Risks

1. **`AVAudioSession` state leakage** — wrong category leaves playback broken elsewhere. Mitigation: the recorder service captures the previous category in `start()` and restores it in `stop()` / `cancel()` / on deinit.
2. **PHPickerResult → temp file copy** — `loadFileRepresentation` returns a temp URL whose lifetime ends when the closure returns. Following the same defensive copy-inside-closure pattern the Share Extension uses (`ShareExtensionViewController.swift:79-89`).
3. **PHPicker `iCloud-only` videos** — picking a video that isn't downloaded yet hangs. `loadFileRepresentation` already streams progress; we'll show a progress overlay in the source picker host while the load is in flight (>500ms triggers the overlay).
4. **Recording on iPad** — sheet detents have to render correctly on iPad's regular size class. `presentationDetents([.medium, .large])` works on iPad in iOS 17+. Verified by manual QA, no code-level guard needed.
5. **Free-tier gating order** — gate must run AFTER the URL is finalized (after stop / extract), not before, so we know the actual duration. Already the case in the existing file-import flow.

## Out of Scope (future work)

- URL paste import.
- Voice Memos as a first-class source row (requires either Apple API or Share Extension UX work).
- Apple Music / iTunes Library picker.
- Pause / resume in the recorder.
- In-recorder waveform trim.
- Multi-select PHPicker for batch clip import in Merge.
- Extending the Share Extension to route to Denoise or Merge (currently routes only to Smart Cut).
- `CFBundleDocumentTypes` registration for AirDrop / "Open in CleanCut".

## File-level diff summary

**New files:**
- `SonicMerge/DesignSystem/ImportSourceSheet.swift` (~140 LOC)
- `SonicMerge/Features/Recording/AudioRecorderService.swift` (~200 LOC)
- `SonicMerge/Features/Recording/RecorderSheet.swift` (~180 LOC)
- `SonicMerge/Features/Recording/RecordPermissionProvider.swift` (~30 LOC, protocol seam)
- `SonicMerge/Services/VideoAudioExtractor.swift` (~80 LOC)
- `SonicMerge/Features/Photos/PHPickerWrapper.swift` (~90 LOC)
- `SonicMergeTests/Features/Recording/AudioRecorderServiceTests.swift`
- `SonicMergeTests/Services/VideoAudioExtractorTests.swift`
- `SonicMergeTests/DesignSystem/ImportSourceSheetTests.swift`

**Modified files:**
- `SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift` (replace `showFileImporter` with `showSourceSheet`, add 3-callback wiring; ~30 line diff)
- `SonicMerge/Features/Denoising/Views/Home/DenoiseHomeView.swift` (same shape; ~30 line diff)
- `SonicMerge/Features/MixingStation/MixingStationView.swift` (same shape; ~30 line diff)
- `SonicMerge/Features/MixingStation/MergeTimelineView.swift` (same shape; ~30 line diff)
- `SonicMerge/Info.plist` (add `NSMicrophoneUsageDescription`)

**Total estimated:** ~700 LOC new, ~120 LOC modified, 3 new test files.
