# SpeechAnalyzer (iOS 26) — Parallel-Path Migration

**Date:** 2026-05-09
**Status:** Spec — implementation-ready
**Author:** Claude (brainstorming session, user-approved decisions)
**Source:** User request — "use SpeechAnalyzer for iOS 26" (per the `SFSpeechRecognizer` vs `SpeechAnalyzer` comparison: long-form support, near-real-time streaming, automatic bilingual detection, AsyncSequence API)

## Summary

Today the Smart Cut transcription pipeline runs on `SFSpeechRecognizer` against 30-second WAV chunks (see `Features/SmartCut/Services/TranscriptionService.swift`). On iOS 26 that engine is superseded by `SpeechAnalyzer` + `SpeechTranscriber`, which support long-form streaming with near-real-time output and on-device multilingual auto-detection. This spec adds `SpeechAnalyzer` as a parallel engine on iOS 26+ behind the existing `TranscriptionServicing` protocol; iOS 17–25 keeps the chunked `SFSpeechRecognizer` path unchanged.

A new `Services/SpeechAnalyzerTranscriptionService.swift` actor implements the iOS 26 path and is selected by a new `Services/TranscriptionServiceFactory.swift` based on `#available(iOS 26, *)` and a new `"auto"` locale sentinel. `TranscriptionState` gains an `engine` discriminator and a `completedRecognizedDuration` field so `BackgroundTranscriptionTask` can resume on the correct engine; `progressFraction` becomes engine-aware so the existing "Transcribing X%" UI keeps working on iOS 26. `SmartCutService.transcriptionServiceFactory` flips from `(Locale) -> any TranscriptionServicing` to `(String) -> any TranscriptionServicing` so the `"auto"` sentinel can flow through unmodified. Three small UI changes accompany the engine: a pinned **Auto-detect (multilingual)** row at the top of `LocalePicker` on iOS 26, the existing "Better filler detection (cloud)" toggle hidden in `EditFillerListStudioSheet` on iOS 26, and an expandable **Live transcript** disclosure pane in `SmartCutStudioContainer.analyzingScaffold(progress:)` on iOS 26.

## Goals

1. **iOS 26 users get long-form, no-chunk transcription** — drop the 30s chunk loop on iOS 26; SpeechAnalyzer streams the whole asset and snapshots state every ~30s of recognized audio.
2. **Multilingual auto-detect on iOS 26** — a session whose `localeIdentifier == "auto"` runs SpeechAnalyzer in bilingual auto-detect mode.
3. **Better disfluency + per-word timestamps on-device** — eliminating the need for the cloud-recognition toggle on iOS 26 (the toggle's only purpose was compensating for SF on-device weaknesses).
4. **Live transcript visible during analysis** — the user sees recognized words stream in below the progress bar (collapsed disclosure by default).
5. **Zero behavioral change on iOS 17–25** — `TranscriptionService`, `BackgroundTranscriptionTask`, the cloud toggle, and the existing `LocalePicker` body are byte-for-byte unchanged when `#unavailable(iOS 26, *)`.
6. **No new flaky tests; FAIL=5 baseline preserved.** New iOS-26-gated tests are skipped (not failed) on iOS 17–25 destinations.

## Non-Goals

- **Raising the deployment floor.** `IPHONEOS_DEPLOYMENT_TARGET` stays at 17.0 across all targets. SpeechAnalyzer is opt-in by iOS version, not by user choice.
- **Removing `TranscriptionService` (the SF chunked engine).** It remains the iOS 17–25 path. A future spec can delete it once the floor rises to iOS 26.
- **Streaming transcription during recording.** The new live-transcript UX runs only on the existing analyze flow against an already-imported asset. Real-time mic transcription is out of scope.
- **Per-locale custom-word lists.** Out of scope; covered by the multi-language Smart Cut spec (2026-05-09).
- **A "use SF on iOS 26" power-user toggle.** Engine selection is automatic. Users on iOS 26 cannot opt back into SF.
- **Migrating in-flight states across engines.** A `TranscriptionState` written by SF stays on SF on resume even if the user has since upgraded to iOS 26 (the persisted `engine` discriminator pins it).

## Architecture

```
                                            SmartCutSession (SwiftData @Model)
                                            ├─ localeIdentifier: String?    "en-US" | "es-ES" | … | "auto" (NEW iOS 26)
                                            └─ …

                                                              │
                                                              ▼
                                            SmartCutViewModel.analyze()
                                            └─ TranscriptionServiceFactory.make(localeIdentifier:)
                                                              │
                              ┌───────────────────────────────┼───────────────────────────────┐
                              │                               │                               │
                              ▼                               ▼                               ▼
                  iOS 17–25 + any locale          iOS 26+ + explicit locale          iOS 26+ + "auto"
                              │                               │                               │
                              ▼                               ▼                               ▼
              TranscriptionService                    SpeechAnalyzer-                SpeechAnalyzer-
              (chunked SF)                            TranscriptionService           TranscriptionService
              [unchanged]                             (locale fixed)                 (auto-detect)
                              │                               │                               │
                              └───────────────┬───────────────┴───────────────┬───────────────┘
                                              │                               │
                                              ▼                               ▼
                                    AsyncThrowingStream<TranscriptionState, Error>
                                              │
                                              ▼
                                    [FillerDetector, PauseDetector, AudioCutter — UNCHANGED]
```

**Hinge invariants:**

- `TranscriptionServicing.transcribe(input:)` and `TranscriptionState.RecognizedSegment(text, startTime, endTime, confidence)` are the contract. Downstream consumers (`FillerDetector`, `PauseDetector`, `AudioCutter`, `SmartCutService`) do not change.
- The factory in `TranscriptionServiceFactory.swift` is the **only** site where `#available(iOS 26, *)` decides which engine runs. UI files have their own `#available` gates for iOS 26-only affordances, but those are scoped to view code.
- Engine routing on resume is encoded in the persisted `TranscriptionState.engine` field — never inferred from `localeIdentifier` (would be wrong for `"auto"` if the user downgrades).

## Components

### 1. `Services/SpeechAnalyzerTranscriptionService.swift` *(new, ~250 LOC, `@available(iOS 26, *)`)*

Actor conforming to `TranscriptionServicing`. Owns the iOS 26 path.

```swift
@available(iOS 26, *)
actor SpeechAnalyzerTranscriptionService: TranscriptionServicing {
    private let stateStore: TranscriptionStateStore
    private let locale: Locale?            // nil = auto-detect
    private let snapshotInterval: TimeInterval  // default 30s of recognized audio

    init(locale: Locale?,
         stateStore: TranscriptionStateStore = .default,
         snapshotInterval: TimeInterval = 30)

    func transcribe(input: URL) -> AsyncThrowingStream<TranscriptionState, Error>
}
```

Internal flow inside `transcribe(input:)`:

1. Compute `sourceHash = "\(rawSourceHashHex)#analyzer"` — namespaced like the SF service's `"#cloud"` / `"#local"` keys (`TranscriptionService.swift:130`) so cached SF and SpeechAnalyzer states never collide. Load or create initial `TranscriptionState`. The **create** branch sets `engine = .speechAnalyzer` and writes `localeIdentifier` as the **literal sentinel** `"auto"` when `locale == nil` (not a resolved identifier — the factory's resume path keys on this exact string), otherwise `locale!.identifier`. The **load** branch leaves both fields untouched; the namespaced cache key guarantees a loaded state already has `engine == .speechAnalyzer`.
2. Build a `SpeechAnalyzer` with a `SpeechTranscriber` module configured for the requested locale (or auto-detect when `locale == nil`).
3. Feed audio into the analyzer's input stream by reading the source asset as `AVAudioPCMBuffer`s via `AVAssetReader`, **starting at `state.completedRecognizedDuration`** (resume from snapshot). No chunked WAV export, no temp files.
4. Subscribe to the transcriber's results `AsyncSequence`. For each finalized segment:
   - Translate to `TranscriptionState.RecognizedSegment(text, startTime, endTime, confidence)`.
   - Append to `state.recognizedSegments`.
   - Append `text` to `state.liveTranscriptText` (joined with single spaces; the first append uses no leading space so the live pane reads cleanly from segment 1).
   - Update `state.completedRecognizedDuration = max(currentValue, segment.endTime)`.
   - Yield the cumulative state.
5. When `(now - lastSnapshotAt) >= snapshotInterval`, persist `state` via `stateStore.save(state)` and update `lastSnapshotAt`.
6. On stream completion, set `state.isComplete = true`, persist, yield, finish.

### 2. `Services/TranscriptionServiceFactory.swift` *(new, ~30 LOC)*

```swift
enum TranscriptionServiceFactory {
    static func make(localeIdentifier: String) -> any TranscriptionServicing {
        if localeIdentifier == "auto" {
            if #available(iOS 26, *) {
                return SpeechAnalyzerTranscriptionService(locale: nil)
            }
            // Defensive: "auto" should never reach this path because LocalePicker
            // only emits it on iOS 26. Fall back to en-US SF for safety.
            return TranscriptionService(locale: Locale(identifier: "en-US"))
        }
        if #available(iOS 26, *) {
            return SpeechAnalyzerTranscriptionService(locale: Locale(identifier: localeIdentifier))
        }
        return TranscriptionService(locale: Locale(identifier: localeIdentifier))
    }
}
```

Single entry point used by `SmartCutService` (via the injected factory closure — see Component 5) and `BackgroundTranscriptionTask`. The only `#available` site for engine selection.

### 3. `Models/TranscriptionState.swift` *(small change)*

Add three fields, one nested enum, and update `progressFraction` to be engine-aware. The new fields are defaulted in the memberwise init so existing call sites (e.g. `TranscriptionService.swift:135`) compile without modification.

```swift
struct TranscriptionState: Hashable, Codable {
    enum Engine: String, Codable { case sfSpeechRecognizer, speechAnalyzer }

    // …existing fields…
    let engine: Engine                              // NEW. defaulted in init; defaults again at decode time
    var completedRecognizedDuration: TimeInterval   // NEW. used by SpeechAnalyzer engine for resume; SF engine leaves at 0
    var liveTranscriptText: String                  // NEW. populated only by SpeechAnalyzer engine

    init(sourceHash: String,
         sourceDuration: TimeInterval,
         chunkDurationSeconds: TimeInterval,
         completedChunkCount: Int,
         recognizedSegments: [RecognizedSegment],
         isComplete: Bool,
         localeIdentifier: String? = nil,
         engine: Engine = .sfSpeechRecognizer,                 // NEW
         completedRecognizedDuration: TimeInterval = 0,        // NEW
         liveTranscriptText: String = "")                      // NEW
}
```

Manual `init(from decoder:)` provides defaults so pre-migration JSON (no `engine`, no `completedRecognizedDuration`, no `liveTranscriptText`) still decodes:

```swift
init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    // …existing decodes…
    self.engine = (try? c.decode(Engine.self, forKey: .engine)) ?? .sfSpeechRecognizer
    self.completedRecognizedDuration = (try? c.decode(TimeInterval.self, forKey: .completedRecognizedDuration)) ?? 0
    self.liveTranscriptText = (try? c.decode(String.self, forKey: .liveTranscriptText)) ?? ""
}
```

`progressFraction` becomes engine-aware so the existing `SmartCutService.analyze` → `.progress(state.progressFraction)` → `analyzingScaffold` "Transcribing X%" pipeline keeps working unchanged on iOS 26:

```swift
var progressFraction: Double {
    guard sourceDuration > 0 else { return 0 }
    switch engine {
    case .sfSpeechRecognizer:
        return min(1.0, Double(completedChunkCount) * chunkDurationSeconds / sourceDuration)
    case .speechAnalyzer:
        return min(1.0, completedRecognizedDuration / sourceDuration)
    }
}
```

### 4. `Services/TranscriptionService.swift` *(unchanged behavior; default-driven field add)*

The `engine` field on `TranscriptionState` defaults to `.sfSpeechRecognizer` in the new init signature, so the existing state-construction call site (`TranscriptionService.swift:135`) compiles unchanged. Everything else — chunking, cloud toggle read, `.dictation` task hint, `resolveSupportedLocale`, the `"\(rawSourceHash)#\(useCloud ? "cloud" : "local")"` cache-key namespacing — is byte-for-byte identical.

### 5. `Services/SmartCutService.swift` *(small change)*

Today's signature `transcriptionServiceFactory: (Locale) -> any TranscriptionServicing` cannot represent the `"auto"` sentinel because `Locale(identifier: "auto")` is meaningless. The factory closure and `analyze` parameter both flip from `Locale` to `String`:

```swift
actor SmartCutService {
    private let transcriptionServiceFactory: (String) -> any TranscriptionServicing  // CHANGED

    init(library: FillerLibrary,
         transcriptionServiceFactory: @escaping (String) -> any TranscriptionServicing
            = { TranscriptionServiceFactory.make(localeIdentifier: $0) }) { … }      // CHANGED default

    func analyze(input: URL,
                 pauseThreshold: TimeInterval,
                 localeIdentifier: String) -> AsyncThrowingStream<Update, Error>      // RENAMED from `locale: Locale`
}
```

Inside `analyze`, the existing `library.allWords(for: locale)` call needs a `Locale` to look up filler defaults. Two cases:

- `localeIdentifier != "auto"`: `library.allWords(for: Locale(identifier: localeIdentifier))` — same behavior as today.
- `localeIdentifier == "auto"` (iOS 26 only): use a new `library.allWordsAcrossCuratedLocales()` (see Component 6) which returns the union of every curated locale's filler list. Rationale: a bilingual session legitimately contains fillers from multiple languages; users on `"auto"` should get filler detection for all of them. False positives from cross-language collisions are rare and overridable through the existing custom-word UI.

`SmartCutViewModel.analyze()` (line 216) updates its call site from `service.analyze(..., locale: currentLocale)` to `service.analyze(..., localeIdentifier: currentLocaleIdentifier)`, where `currentLocaleIdentifier: String` is a new VM property holding the raw picked identifier. The existing `currentLocale: Locale` cannot be used for engine selection because `TranscriptionService.resolveSupportedLocale` collapses `"auto"` → `Locale(identifier: "en-US")` (since "auto" isn't in `SFSpeechRecognizer.supportedLocales()`), which silently loses the sentinel. `currentLocaleIdentifier` is seeded from `session.localeIdentifier` at init and updated by `setLocale(_:on:)` alongside `currentLocale`. `currentLocale` stays for the rest of its uses (`LanguagePill` display, `library.allWords(for:)` previews); only the analyze call site reads the new field.

### 6. `Models/FillerLibrary.swift` *(small change)*

Add one method:

```swift
/// Union of curated default-off words across all locales the library curates.
/// Used when SpeechAnalyzer runs in auto-detect ("auto") mode and we cannot
/// pre-pick a single language.
func allWordsAcrossCuratedLocales() -> [String]
```

Iterates the existing internal locale → words map, deduplicates (case-insensitive), and returns the union. Pure read-only; no side effects.

### 7. `Services/BackgroundTranscriptionTask.swift` *(small change)*

Replace the existing `TranscriptionService(locale: resumedLocale)` call with `TranscriptionServiceFactory.make(localeIdentifier: state.localeIdentifier ?? "en-US")`. Routing is by `#available(iOS 26, *)` + the `"auto"` sentinel — see §Engine routing safety for the invariant that makes this safe without consulting `state.engine`. Everything else (notification, source-locator lookup, expiration handling) unchanged. **Source-locator note:** `SmartCutSourceLocator` is keyed by the raw SHA-256, but `state.sourceHash` carries an engine-namespace suffix (`#cloud` / `#local` / `#analyzer`). `BackgroundTranscriptionTask.handle(_:)` strips the suffix via a new `rawHash(from:)` helper before calling `lookupURL(forHash:)`.

### 8. `Views/Studio/LocalePicker.swift` *(small change)*

On iOS 26, prepend a pinned "Auto-detect (multilingual)" row above the "Suggested" section. Selecting it calls `onPick("auto")`. Existing locale rows render unchanged; the `currentIdentifier == "auto"` case shows the checkmark on the pinned row.

```swift
var body: some View {
    NavigationStack {
        List {
            if #available(iOS 26, *) {
                Section { autoDetectRow }
            }
            // …existing Suggested + All languages sections, unchanged…
        }
        // …toolbar, search, navigationTitle, unchanged…
    }
}
```

### 9. `Views/Studio/EditFillerListStudioSheet.swift` *(small change)*

Wrap the existing "Better filler detection (cloud)" toggle row in `if #unavailable(iOS 26, *) { … toggle … }`. iOS 26 users don't see the row. The underlying `TranscriptionService.useCloudRecognitionDefaultsKey` is left in place — SpeechAnalyzer simply ignores it.

### 10. `Views/Studio/SmartCutStudioContainer.swift` + new `Views/Studio/LiveTranscriptPane.swift` *(small change + ~80 LOC)*

`analyzingScaffold(progress:)` gets a new child below the existing `ProgressView`, gated `if #available(iOS 26, *)`:

```swift
if #available(iOS 26, *) {
    LiveTranscriptPane(text: vm.liveTranscriptText)
}
```

`LiveTranscriptPane` is a SwiftUI `DisclosureGroup` titled "Live transcript". Body is a `ScrollViewReader`-wrapped `Text` that auto-scrolls to the bottom on each text update. Default collapsed. Renders `EmptyView` when `text.isEmpty`. Reads `\.sonicMergeSemantic` for colors per the project's two-color discipline (chrome → indigo, AI moments → lime — the live transcript is "AI is doing something now," so the disclosure header uses `accentAI`).

`SmartCutViewModel` is `@Observable` (Swift 6 macro), so a plain stored `var liveTranscriptText: String = ""` is automatically observed by SwiftUI — no `@Published` needed. The VM populates it from each yielded `TranscriptionState.liveTranscriptText` during `analyze()`.

### Out of scope (no code change)

`AudioRecorderService`, `OnboardingFlow` (subject to the auth verification below — see Assumptions), `FillerDetector`, `PauseDetector`, `AudioCutter`, `TranscriptionStateStore`, `SmartCutSourceLocator`. They consume the unchanged protocol/data shape only.

## Data flow

### Foreground analyze (iOS 26 path)

```
User taps Analyze in SmartCutSessionView
  → SmartCutViewModel.analyze()
  → reads session.localeIdentifier ("en-US" or "auto") and passes the raw String
  → SmartCutService.analyze(input:, pauseThreshold:, localeIdentifier:)
      → transcriptionServiceFactory(localeIdentifier)
          → TranscriptionServiceFactory.make(localeIdentifier:)
              → SpeechAnalyzerTranscriptionService(locale:)
  → for try await state in service.transcribe(input: sourceURL):
      ├─ AVAssetReader streams PCM buffers → analyzer.input
      ├─ analyzer.results AsyncSequence emits finalized segments
      ├─ each segment → state.recognizedSegments.append + state.liveTranscriptText += " \(text)"
      │                  → SmartCutService yields .progress(state.progressFraction) [progressFraction is now engine-aware]
      │                  → SmartCutViewModel mirrors state.liveTranscriptText to vm.liveTranscriptText (live transcript pane)
      ├─ every ~30s recognized → stateStore.save(state)
      └─ yield state
  → final state.isComplete=true → SmartCutService runs FillerDetector + PauseDetector
      ├─ filler word source: localeIdentifier == "auto" ? library.allWordsAcrossCuratedLocales()
      │                                                 : library.allWords(for: Locale(identifier: localeIdentifier))
      └─ continuation.yield(.completed(editList, segments, duration))
  → vm transitions to .results [UNCHANGED]
```

### Snapshot + BG resume

```
App backgrounds mid-stream
  → SmartCutViewModel.analyze() Task is suspended
  → SpeechAnalyzer's stream task is cancelled when the analyze Task is cancelled
  → most recent snapshot on disk: <hash>.transcription-state.json
        engine = .speechAnalyzer, localeIdentifier = "auto" or "en-US",
        completedRecognizedDuration = 73.2

iOS later fires BGProcessingTask "com.dtech.cleancut.smartcut.transcribe"
  → BackgroundTranscriptionTask.handle(_:) loads newest state JSON
  → factory.make(localeIdentifier: state.localeIdentifier ?? "en-US")
        → routes by #available(iOS 26, *) + the "auto" sentinel (NOT by state.engine).
          Safe because the engine that *wrote* a given (locale-identifier, iOS-version)
          combination is the same engine the factory returns when given that combination:
          SF only writes on iOS 17–25; SpeechAnalyzer only writes on iOS 26+ and writes
          either a real identifier or the literal "auto". The state.engine field exists
          for forensic / future use; the factory does not currently consume it.
  → service.transcribe(input: SmartCutSourceLocator.lookupURL(forHash: rawSourceHash))
      → SpeechAnalyzer service starts AVAssetReader at state.completedRecognizedDuration
      → resumes streaming from there, snapshotting + yielding as before
  → final state → postCompletionNotification(...) [UNCHANGED]
```

> **Note:** `SmartCutSourceLocator` is keyed by the **raw** SHA-256 hash, but `state.sourceHash` is namespaced (`<raw>#analyzer` / `<raw>#cloud` / `<raw>#local`). `BackgroundTranscriptionTask.handle(_:)` must strip the suffix before calling `SmartCutSourceLocator.lookupURL(forHash:)`. This is a pre-existing concern (today's SF cloud/local namespacing has the same issue if BG resume ever hits a non-`#local`-default state); the implementation plan addresses both engines together.

### Live-transcript channel

The live transcript is **not** a separate channel — it rides on the existing `TranscriptionState` stream. The service maintains `state.liveTranscriptText` as a single space-joined `String` and yields it as part of every state update. `SmartCutViewModel` mirrors it to a stored `var` (auto-observed via `@Observable`); `LiveTranscriptPane` re-renders. No new actors, no new streams, no new `Combine` plumbing.

### Engine routing safety

**Routing is by `#available(iOS 26, *)` + the `"auto"` sentinel, not by `state.engine`.** The two coordinates uniquely determine the engine for any given (locale-identifier, iOS-version) pair, because SF only ever runs on iOS 17–25 and SpeechAnalyzer only ever runs on iOS 26+. The one mid-flight edge case — user upgrades from iOS 17–25 to iOS 26 between snapshots on a non-`"auto"` session — is intentionally accepted: the SpeechAnalyzer service will not find a matching `<hash>#analyzer` cache (because SF wrote `<hash>#cloud` or `<hash>#local`) and will start fresh from t=0. Acceptable for a rare upgrade-during-analysis case. The `state.engine` discriminator is preserved for forensic use (logs, future migrations) but not consumed by the factory today.

## Error handling

SpeechAnalyzer's error space is mapped onto the existing `TranscriptionService.TranscriptionError` so `SmartCutViewModel`'s existing `case .error(let message)` capture path is unchanged. Three new cases:

- `.assetReaderFailed(Error)` — `AVAssetReader` couldn't decode the source. Surfaced as "Couldn't read this audio file. Try re-importing." Distinguishes a pre-recognition failure from `.recognitionFailed`.
- `.modelDownloadRequired` — SpeechAnalyzer reports the on-device model isn't installed for the requested locale. Surfaced as "Language model is downloading. Please try again in a moment." We do *not* trigger the system download UI ourselves.
- `.localeNotSupported(String)` — the requested locale isn't supported by SpeechAnalyzer (different supported set than SFSpeechRecognizer). Falls back to `Locale(identifier: "en-US")` for English variants; otherwise throws and surfaces.

**Cancellation.** When the user taps Cancel during an iOS 26 analyze, `SmartCutViewModel.analyze()` cancels the consuming Task. The stream's `for try await` drops out, the `SpeechAnalyzer` instance deinits, and partial state on disk is preserved (matching today's chunked SF behavior — Cancel preserves; only "Restart" wipes).

**Auto-detect downgrade.** If a session has `localeIdentifier == "auto"` but the user is on iOS 17–25 (downgrade, restored backup), the factory falls through to the SF engine with `Locale(identifier: "en-US")` and writes the runtime locale into `state.localeIdentifier`. The session's stored `"auto"` value is left untouched in SwiftData; an upgrade back to iOS 26 reactivates auto-detect.

**Permission.** `SFSpeechRecognizer.requestAuthorization` (used in `SmartCutViewModel` and `OnboardingFlow`) covers SpeechAnalyzer too on iOS 26 — the underlying privacy entitlement is the same Speech framework permission. No code change needed in those files.

## Testing

Match the project convention — Swift Testing for new files, no database mocking, `xcodebuild ... test` against iPhone 17 (iOS 26). Baseline `FAIL=5` preserved (the names listed in CLAUDE.md). New iOS-26-gated tests are **skipped** (not failed) on iOS 17–25 destinations via `@available(iOS 26, *)` on the suite.

### `TranscriptionServiceFactoryTests` *(new, ~6 cases)*

Pure unit tests against `TranscriptionServiceFactory.make(localeIdentifier:)`. No audio.

- iOS 17–25 + any locale → returns `TranscriptionService`.
- iOS 26+ + `"en-US"` → returns `SpeechAnalyzerTranscriptionService`.
- iOS 26+ + `"auto"` → returns `SpeechAnalyzerTranscriptionService` with `nil` locale.
- iOS 17–25 + `"auto"` → returns `TranscriptionService` with `en-US` fallback (defensive path).
- Returned value conforms to `TranscriptionServicing` (compile-time type check).
- No side effects (no file writes, no `SFSpeechRecognizer` allocation).

### `TranscriptionStateMigrationTests` *(new, ~3 cases)*

Decoding-only.

- Pre-migration JSON (no `engine`, no `completedRecognizedDuration`, no `liveTranscriptText`) decodes successfully with `engine == .sfSpeechRecognizer`, `completedRecognizedDuration == 0`, `liveTranscriptText == ""`.
- Round-trip encode/decode preserves all three new fields.
- A state with `engine == .speechAnalyzer` and populated `completedRecognizedDuration`/`liveTranscriptText` round-trips identically.

### `SpeechAnalyzerTranscriptionServiceTests` *(new, ~4 cases, `@available(iOS 26, *)`)*

Real audio. Reuses `smart_cut_60s.wav` (the same fixture loaded by `SmartCutServiceIntegrationTests` via `Bundle(for: BundleMarker.self).url(forResource:withExtension:)`).

- Streaming yields at least one `TranscriptionState` update before completion.
- Final `state.recognizedSegments` is non-empty for the known-good fixture.
- `state.engine == .speechAnalyzer` and `state.completedRecognizedDuration > 0` on completion.
- A snapshot is persisted at least once mid-stream (verified by checking `TranscriptionStateStore.default`'s directory after first yield).

### `BackgroundTranscriptionTaskTests` *(extend, ~2 new cases, `@available(iOS 26, *)`)*

Seed a `TranscriptionState` JSON with `engine == .speechAnalyzer` and verify the factory routes resume to `SpeechAnalyzerTranscriptionService`. Mirror the existing test pattern.

### `LocalePickerTests` *(extend or new, ~2 cases)*

- On iOS 26, the auto-detect row appears at the top of the list.
- On iOS 17–25, no auto-detect row is rendered.

### Manual QA — `docs/superpowers/qa/2026-05-09-speechanalyzer-ios26-manual-qa.md`

- Foreground analyze on iOS 26 with English file → completes, transcript visible, fillers detected.
- Foreground analyze with bilingual fixture (English + Spanish) using "Auto-detect" → both languages appear in transcript.
- Mid-analyze background → BGProcessingTask resumes from snapshot → completion notification fires.
- iOS 17 simulator: existing SF path still works, cloud toggle still visible, no auto-detect row, no live transcript pane.
- Live transcript pane: starts collapsed; expanding shows growing text; auto-scrolls to bottom.
- Cancel mid-stream preserves partial state; tapping Analyze again resumes (does not restart).

## Assumptions to verify before implementation

Per the Karpathy "surface assumptions" rule, two assumptions to confirm in the very first implementation step (literally: read the iOS 26 `Speech` framework headers / Apple docs before writing any new Swift). Both have a defined fallback in this spec, so neither blocks the design — but both are load-bearing for the iOS 26 path and must be settled before the rest of the plan is executed.

1. **SpeechAnalyzer is on-device-only with no network/cloud variant.**
   - **Confirmed 2026-05-10:** `SpeechAnalyzer` (iOS 26+) runs fully on-device by design; the legacy `requiresOnDeviceRecognition` flag is specific to `SFSpeechRecognitionRequest` and has no analogue on `SpeechAnalyzer` / `SpeechTranscriber`. Apple's WWDC25 session 277 ("Bring advanced speech-to-text to your app with SpeechAnalyzer") and the developer documentation confirm there is no cloud/server variant for the new framework. Component 9 (hide the cloud toggle on iOS 26) proceeds as written. Cite: `https://developer.apple.com/videos/play/wwdc2025/277/`, `https://developer.apple.com/documentation/speech/speechanalyzer`.

2. **`SFSpeechRecognizer.requestAuthorization` covers SpeechAnalyzer.**
   - **Confirmed 2026-05-10:** SpeechAnalyzer-using apps still call `SFSpeechRecognizer.requestAuthorization`; the user prompt, the Settings entry, and the App Store privacy nutrition label all use the same `Speech` authorization mechanism for both APIs. `SmartCutViewModel.requestSpeechAuthorization` and `OnboardingFlow`'s permission seed remain unchanged — no parallel iOS-26 auth call needed. Cite: `https://developer.apple.com/documentation/speech/sfspeechrecognizer`, `https://developer.apple.com/videos/play/wwdc2025/277/`.

## Migration / rollback

- **No SwiftData schema migration.** `SmartCutSession.localeIdentifier` is already `String?`. The new `"auto"` value is just another string; existing rows are unaffected.
- **TranscriptionState JSON migration is decode-side only.** The new optional fields default at decode time. No in-place file rewrites.
- **Rollback** is removing `SpeechAnalyzerTranscriptionService.swift`, `TranscriptionServiceFactory.swift`, and the iOS-26-gated UI blocks; reverting `BackgroundTranscriptionTask` to call `TranscriptionService(locale:)` directly; reverting `SmartCutService.transcriptionServiceFactory` back to `(Locale) -> any TranscriptionServicing`. No data on disk is incompatible with the rollback — `engine == .speechAnalyzer` states would resume on SF after rollback, which is a different engine but the SF resume path tolerates a non-zero `completedChunkCount` that's still 0 in those states (it'd start over from t=0).
- **Optional rollback cleanup:** to avoid user-visible weirdness from "this session was 47% transcribed yesterday and is now 0%," the rollback PR can include a one-shot migration that deletes any `<hash>#analyzer.transcription-state.json` files at app launch. Cheap; recommended.

## Open questions

None blocking. The two assumptions above are verifiable during implementation, not during review.

## Implementation amendment (2026-05-10)

During Chunk 3 SDK reconciliation, two material divergences from the iOS 26
Speech.framework as shipped (Xcode 26.3 / iOS 26.2 SDK) required scope
reduction:

1. **Auto-detect dropped.** `SpeechTranscriber.init` requires a non-optional
   `Locale` and exposes no nil-locale or multi-locale auto-detect path. The
   spec's bilingual auto-detect promise (Components 6, 8, 11; LocalePicker
   "Auto-detect" row; FillerLibrary auto-locale union) is not implementable
   on this SDK and was dropped per user decision. iOS 26 still gets the
   long-form streaming engine, live transcript pane, and on-device
   disfluence preservation; users explicitly pick a locale via the existing
   per-locale picker rows.

2. **Result shape differs.** `SpeechTranscriber.Result` has no `tokens` /
   `isFinal` / per-token confidence — instead it exposes `range: CMTimeRange`
   and `text: AttributedString` (with optional `audioTimeRange` /
   `transcriptionConfidence` attributes via the SpeechAttributes scope).
   The implementation uses `Preset.progressiveTranscription` (finalized-only
   stream, no volatile results) and treats each result's `range` as the
   segment boundary. Per-segment confidence is set to 1.0 since
   `FillerDetector` propagates but doesn't gate on it.

3. **Audio input via `init(inputAudioFile:modules:finishAfterFile:)`** — the
   SDK accepts an `AVAudioFile` directly, bypassing the manual
   `AVAssetReader` + feeder-task loop in the original plan. Resume cursor
   is implemented via `audioFile.framePosition`.

The protocol contract, factory routing, BG resume routing, and namespaced
cache key strategy (`<rawHash>#analyzer`) all remain as written.
