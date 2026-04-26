# Smart Cut — Design Spec

**Status:** Approved (brainstorming phase complete)
**Date:** 2026-04-26
**Owner:** DATNNT
**Implements:** Filler-word removal + long-pause trimming inside the existing Cleaning Lab.

---

## 1. Overview

Smart Cut is a second AI tool inside the existing Cleaning Lab screen, sitting below the existing Denoise tool. It uses Apple's on-device `SFSpeechRecognizer` to transcribe the merged podcast audio, identifies filler words ("um", "uh", "like", and a configurable list of others) and silences longer than a user-set threshold, then lets the user curate exactly which cuts to apply before exporting a tighter version through the existing export pipeline.

Smart Cut is **free to use, runs entirely on-device** (nothing leaves the phone), and ships as the second pillar of Cleaning Lab — turning Cleaning Lab from "the place to clean noise" into "the place to clean noise *and* tighten the cut."

The feature is intentionally scoped to be the AI/cleanup hero of the app's free tier, with future Pro-tier upgrades (cloud-quality transcription, full transcript editor, export to text) designed *around* this v1 rather than *instead of* it.

## 2. Goals and non-goals

**Goals (v1):**
- Detect filler words from a configurable library against the merged audio.
- Detect silences longer than a configurable threshold.
- Let the user toggle individual fillers, whole categories, and the long-pause group on/off.
- Render an audibly clean cut WAV with no clicky seams (using crossfade at cut boundaries).
- Run all processing on-device, never sending audio to a server.
- Continue transcription processing while the app is backgrounded, with a local notification on completion.

**Non-goals (v1, explicitly deferred):**
- Full transcript-editor UI (Descript-style word-by-word deletion). This is a Pro-tier upgrade.
- Per-speaker labelling / diarization.
- Cloud transcription (Whisper, AssemblyAI, etc.).
- Multilingual filler libraries — defaults are English-only; users can add custom words but no localized presets.
- Music/sound-FX preservation (long pauses inside music *will* get cut if they cross threshold; documented limitation).
- Ramping/fades on cut audio beyond the implicit micro-crossfade.
- Detection accuracy tuning per device / per user — we ship one model behavior.

## 3. User journey

1. User assembles clips in Mixing Station (unchanged) and taps Merge.
2. Cleaning Lab opens with the merged audio. Two stacked tool cards are visible: **Denoise** (existing, top) and **Smart Cut** (new, below). Each card is independently usable; neither is required for export.
3. Optionally the user runs Denoise (existing flow, unchanged).
4. The user scrolls to the Smart Cut card and taps **Analyze**. A progress ring spins on the card; the orb adopts its active gradient state. Subtitle updates to `"Transcribing 4:23 / 30:00"`.
5. If the user backgrounds the app mid-analysis, they may tap **Run in Background** during analysis to schedule a `BGProcessingTask` and (if not yet granted) be prompted for notification permission. iOS will run the task at its discretion (typically when the device is on charger and idle); a local notification fires on completion.
6. When analysis completes, the card transitions to **Results** state showing:
    - Macro stats: *"Found 47 fillers + 12 long pauses · saves ~1m 23s"*
    - **A/B toggle pill** at the top (mirrors Denoise's existing pill): swap between the input audio and a synthesized "would-be-cut" preview.
    - **Filler-list panel**: per-category rows with checkbox + count + expand chevron. Default-on rows (`um`, `uh`, `ah`, `er`) are listed first; default-off rows (`like`, `you know`, `basically`, `actually`, `literally`, `sort of`) listed below. Expanding a row reveals individual occurrences with `▶` preview buttons (plays a 4-second window centered on the cut), short context excerpt, timestamp, and per-occurrence checkbox.
    - **Long-pause row** (visually separated): `☑ Trim 12 long pauses (>1.5s) · saves 0:43`. A gear icon opens an inline threshold stepper (1.0s / 1.5s / 2.0s / custom).
    - **+ Edit filler list** opens `EditFillerListSheet` to add/remove custom words.
    - **Apply Cuts** primary CTA (lime-green `.ai`-tinted PillButton).
7. The user curates: toggles whole categories off, expands a row, taps `▶` to verify a specific seam, unchecks individual occurrences they want to keep.
8. The user taps **Apply Cuts**. The `AudioCutter` actor renders a new temp WAV; the card transitions to **Applied** state. The A/B pill now compares the *input* (pre-cut) against the *Smart Cut output* (post-cut). If the user toggles further rows, an inline **Re-apply** affordance appears.
9. The user taps Export (existing toolbar button). The existing `ExportFormatSheet` flow runs unchanged. `CleaningLabViewModel` resolves the export source via the fallback chain `smartCutOutputURL ?? denoisedOutputURL ?? mergedFileURL`.

## 4. Architecture

Three-layer separation, mirroring the existing Denoise tool's pattern.

### 4.1 Module map

All new files live under `/SonicMerge/Features/SmartCut/`, following the project's `/Features/<FeatureName>/` convention:

```
/Features/SmartCut/
├── SmartCutCardView.swift              # Card UI inside CleaningLabView
├── SmartCutViewModel.swift             # @Observable @MainActor; owns state + A/B playback
├── Services/
│   ├── SmartCutService.swift           # actor — orchestrates analyze pipeline
│   ├── TranscriptionService.swift      # actor — wraps SFSpeechRecognizer; chunked
│   ├── FillerDetector.swift            # pure logic — segments + library → [FillerEdit]
│   ├── PauseDetector.swift             # pure logic — segments + threshold → [PauseEdit]
│   ├── AudioCutter.swift               # actor — applies EditList to WAV via AVAssetReader/Writer
│   └── BackgroundTranscriptionTask.swift  # BGProcessingTask coordinator
├── Models/
│   ├── EditList.swift                  # curated cut decisions; per-row enable flags
│   ├── FillerEdit.swift                # {timeRange, type, confidence, isEnabled}
│   ├── PauseEdit.swift                 # {timeRange, duration, isEnabled}
│   ├── FillerLibrary.swift             # default + user words; persisted (UserDefaults JSON)
│   └── TranscriptionState.swift        # codable; persisted to disk for resume
└── Views/
    ├── FillerListPanel.swift           # categorized rows + per-occurrence preview
    └── EditFillerListSheet.swift       # modal for custom words
```

### 4.2 Layer responsibilities

- **View layer** (pure rendering): `SmartCutCardView`, `FillerListPanel`, `EditFillerListSheet`. No state logic, no async work.
- **ViewModel layer** (`@Observable @MainActor final class`): `SmartCutViewModel` owns playback (dual `AVAudioPlayer` for A/B), the curated `EditList`, the current state enum (idle/analyzing/results/applied/stale), and fires haptic feedback. Mirrors `CleaningLabViewModel`'s shape.
- **Service layer** (`actor` types, off-main): orchestrates transcription, runs detectors, applies cuts. Pure logic types (detectors) are non-actor `struct`s with static functions; only types with mutable state or I/O are actors.

### 4.3 Coordination with existing code

- **`CleaningLabViewModel`** receives one new property: `let smartCutVM: SmartCutViewModel`. It observes both `denoisedOutputURL` and `smartCutVM.outputURL`, and exposes a computed `exportSource: URL` resolved by the fallback chain `smartCutOutputURL ?? denoisedOutputURL ?? mergedFileURL`. The existing export sheet logic reads `exportSource` instead of `denoisedTempURL`.
- **`CleaningLabView`** adds one new card render call below the existing Denoise card: `SmartCutCardView(vm: viewModel.smartCutVM)`. No structural changes to the rest of the screen.
- **No refactor of the Denoise tool, no refactor of `CleaningLabViewModel`'s existing methods.** The existing A/B player pair stays. Smart Cut introduces its own A/B player pair (two more `AVAudioPlayer` instances). When the user toggles A/B on one card, the other card's playback pauses (handled via a shared playback coordinator delegate).

### 4.4 Composition order (the Q9 = B fallout)

The two tools are presented as independent (each has its own Analyze/A/B/Apply), but the audio engine applies them in a fixed pipeline order: **Denoise → Smart Cut**.

- Smart Cut's input source = `denoisedOutputURL ?? mergedFileURL` (resolved by `CleaningLabViewModel` and passed into `SmartCutViewModel.setInput(url:)`).
- This is shown to the user as a small subtitle on the Smart Cut card: *"Reads from: denoised audio"* (or *"Reads from: original audio"* if Denoise is off). Makes the pipeline-order decision visible without forcing a UI for it.
- **Staleness rule**: if the user re-blends Denoise after Smart Cut analysis, `SmartCutViewModel` enters the **Stale** state — analysis results dimmed, Apply disabled, banner prompts re-analyze. Triggered by `CleaningLabViewModel` calling `smartCutVM.invalidate()` whenever `denoisedOutputURL` changes after analysis has run.

## 5. Data flow

End-to-end, single Smart Cut run:

```
Mixing Station merges clips
        │
        ▼
mergedFileURL  ──────►  CleaningLab opens
        │                       │
        ▼                       ▼
DenoiseVM                  SmartCutVM (input = denoisedURL ?? mergedURL)
   (existing,                    │
    unchanged)                   │  user taps Analyze
        │                        ▼
        │              SmartCutService.analyze(inputURL)
        │                        │
        │                        ▼
        │              TranscriptionService chunks audio →
        │                  SFSpeechRecognizer → [SFTranscriptionSegment]
        │                        │
        │                        ▼
        │              FillerDetector + PauseDetector →
        │                  EditList (per-row .isEnabled = default-on/off)
        │                        │
        │                        ▼
        │              UI populates filler-list panel
        │                        │
        │                        │  user toggles edits
        │                        ▼
        │              tap Apply → AudioCutter(inputURL, EditList) → smartCutOutputURL
        │                        │
        ▼                        ▼
CleaningLabVM observes both → resolves exportSource via fallback chain
                                 │
                                 ▼
                        existing ExportFormatSheet (unchanged)
```

**Internal edit-decision representation (the first EDL pattern in the codebase):**
- `EditList` is a value-type bundle: `struct EditList { var fillers: [FillerEdit]; var pauses: [PauseEdit] }`.
- Each `FillerEdit` and `PauseEdit` carries an `isEnabled: Bool`. Toggling a category flips all children; toggling a child flips only itself.
- `EditList` is the source of truth for the *intent* of cuts. The output WAV is rendered by `AudioCutter` only when the user taps Apply (or Re-apply). Toggling rows in the panel does *not* re-render the WAV — it only updates UI counters (`saves ~Xs` recomputes from the enabled subset's durations).
- Per-occurrence `▶` preview plays a 4-second window from the *original* `inputURL`, not from a rendered cut WAV — fast, no re-render.

**Cut-seam rendering:**
- `AudioCutter` applies a 25 ms equal-power crossfade at every cut boundary to eliminate click artifacts. Not user-configurable in v1.
- For pause cuts, the same crossfade applies between the audio that ended before the pause and the audio that resumes after.

## 6. UI composition

The Smart Cut card is a `SquircleCard` (existing primitive, `glassEnabled: false, glowEnabled: false`) inside `CleaningLabView`'s scroll view, directly below the existing Denoise card. It has five visual states.

### 6.1 State 1 — Idle

```
┌─────────────────────────────────────────────┐
│  ✦ Smart Cut                                │
│  Remove fillers and trim long silences      │
│                                             │
│           ╭─────────╮                       │
│           │ AIOrbView│  (small, breathing)  │
│           ╰─────────╯                       │
│                                             │
│      ┌──────────────────────────┐           │
│      │  ✦ Analyze ~12 min       │   .ai     │
│      └──────────────────────────┘  filled   │
│                                             │
│  Reads from: denoised audio                 │
└─────────────────────────────────────────────┘
```

- `AIOrbView` reused at smaller scale (~80pt vs Denoise's hero size). Same breathing pulse from the Phase 11 polish (commit `86ce855`) so both cards feel related.
- Primary CTA = `PillButton(.filled, tint: .ai)`. ETA computed as `audio.duration / 2.5` (Apple's typical on-device throughput on modern A-series silicon).
- "Reads from: …" subtext makes the pipeline source visible.

### 6.2 State 2 — Analyzing

```
┌─────────────────────────────────────────────┐
│  ✦ Smart Cut          Analyzing…            │
│                                             │
│           ╭─────────╮                       │
│           │ AIOrbView│  (active gradient)   │
│           ╰─────────╯                       │
│                                             │
│      Transcribing 4:23 / 30:00              │
│      ━━━━━━━━━━━━░░░░░░░░░░░░  42%          │
│                                             │
│  ┌─────────────────────┐  ┌──────────────┐ │
│  │   Cancel            │  │  Run in BG   │ │
│  └─────────────────────┘  └──────────────┘ │
│   .outline                  .ai outline     │
└─────────────────────────────────────────────┘
```

- Orb adopts the same active gradient state Denoise uses during inference (visual continuity).
- Progress = `currentChunkEndTime / totalDuration`, updated as each chunk completes.
- **Run in BG** schedules the `BGProcessingTask` (see § 7) and (if not yet granted) prompts for notification permission.
- **Cancel** kills any in-flight task and returns to State 1; partially saved `TranscriptionState` is discarded.

### 6.3 State 3 — Results (analyzed, not yet applied)

```
┌─────────────────────────────────────────────┐
│  ✦ Smart Cut                          Reset │
│  Found 47 fillers + 12 long pauses          │
│  Saves ~1m 23s                              │
│                                             │
│       ╭─────────╮  ╭─────────╮              │
│       │ Original │  │ Cleaned │  ← A/B pill │
│       ╰─────────╯  ╰─────────╯              │
│                                             │
│  ☑ um         (23)              ▾          │
│    ▶ "...so um, the thing is..."  0:34 ☑   │
│    ▶ "...yeah um. anyway..."      1:12 ☑   │
│    …                                        │
│  ☑ uh         (15)              ▸          │
│  ☐ like       (9)               ▸          │
│  ☐ basically  (4)               ▸          │
│                                             │
│  ───────────────────────────────────────    │
│                                             │
│  ☑ Trim 12 long pauses (>1.5s)              │
│       saves 0:43       Threshold: 1.5s ⚙    │
│                                             │
│  + Edit filler list                         │
│                                             │
│      ┌──────────────────────────┐           │
│      │  ✦ Apply Cuts            │   .ai     │
│      └──────────────────────────┘  filled   │
└─────────────────────────────────────────────┘
```

- **Stats line** is the macro hook — the visceral "this saves time" beat.
- **A/B pill**: identical chassis to Denoise's existing pill (same `PillButtonStyle`). Pre-apply, "Cleaned" plays a synthesized preview using the EditList against the input — no rendered WAV yet. (Implementation note: synthesized preview can use `AVAudioPlayerNode` scheduling segments dynamically, or fall back to realtime-rendered chunks; § 9.3 covers approach.)
- **Filler list panel**:
    - One row per filler type, with checkbox + count badge + expand chevron.
    - Checkbox toggles the whole category (light haptic).
    - Expanding reveals individual occurrences: `▶` preview button, short context excerpt, timestamp, per-occurrence checkbox.
    - Default-on rows at the top, default-off below.
- **Pause row** is visually separated by a thin divider; uses the same toggle pattern. Gear icon opens inline stepper for threshold (1.0s / 1.5s / 2.0s / custom).
- **+ Edit filler list** opens `EditFillerListSheet` (modal): word list, swipe to delete, "+" to add. Persisted in `FillerLibrary` (UserDefaults JSON for v1).
- **Apply Cuts** = primary CTA (`.ai`-tinted PillButton).
- **Reset** in the top-right clears EditList + cached transcript and returns to State 1.

### 6.4 State 4 — Applied

Same layout as State 3, with three changes:
- A/B pill now compares `inputURL` (pre-cut) vs the rendered `smartCutOutputURL` (post-cut).
- "Apply Cuts" button morphs into "Re-apply" — visible only if user has toggled rows since last apply (otherwise hidden). When nothing has changed, no button is shown.
- A small `✓ Applied · 1m 18s saved` badge appears beneath the stats line.

### 6.5 State 5 — Stale (after Denoise re-blend)

```
┌─────────────────────────────────────────────┐
│  ✦ Smart Cut                          Reset │
│                                             │
│  ⚠ Denoise was re-applied                   │
│    Smart Cut analysis is stale.             │
│    [ Re-analyze ]                           │
│                                             │
│  (filler list dimmed below)                 │
└─────────────────────────────────────────────┘
```

- Banner replaces the A/B pill area.
- Apply button disabled. Filler list dimmed but visible (so user can see what was found before).
- **Re-analyze** runs the full pipeline against the new denoised input.

### 6.6 Reuse summary

Every visual primitive used by Smart Cut already exists in `/SonicMerge/DesignSystem/`:
- `SquircleCard`, `AIOrbView`, `PillButtonStyle` (`.ai` filled + `.outline`), `PremiumBackground` (already wraps Cleaning Lab — Smart Cut card inherits the mesh gradient context).
- `UIImpactFeedbackGenerator` patterns from junction Menu (commit `6f7b53d`):
    - `.light` for individual checkbox toggle
    - `.medium` for category-level toggle and Apply tap
    - `.heavy` for "Cuts applied" success moment

No new design primitives.

## 7. Background processing

User requirement (Q12 = 2): true background continuation via `BGProcessingTask` + local notification.

### 7.1 Chunked transcription

`TranscriptionService` processes the input in 30-second chunks. After each chunk completes, the partial `[SFTranscriptionSegment]` array is appended to `TranscriptionState`, which is persisted to disk (`Library/Caches/SmartCut/<sourceHash>.transcription-state.json`).

This serves two purposes:
1. Foreground processing can be cancelled and resumed without losing progress.
2. Background processing can complete one or more chunks per BG task invocation, persist, then the next BG task picks up where it left off.

### 7.2 Foreground → background transition

Two paths:

**(a) User explicitly taps "Run in BG" during analysis:**
1. `SmartCutViewModel.scheduleBackgroundTask()` is called.
2. If notification permission not yet granted, prompt (via `UNUserNotificationCenter.requestAuthorization`).
3. Submit a `BGProcessingTaskRequest` with identifier `com.sonicmerge.smartcut.transcribe`, `requiresNetworkConnectivity: false`, `requiresExternalPower: false` (set to `true` would make iOS more willing but adds a battery dependency the user may not want).
4. Foreground processing pauses after the current chunk completes. The card stays in State 2 with a "Running in background…" subtitle.

**(b) User backgrounds the app while analysis is running (without explicit "Run in BG" tap):**
1. App delegate's `applicationDidEnterBackground` calls `SmartCutViewModel.handleBackgrounding()`.
2. `beginBackgroundTask` requests extra foreground time (~30 sec, may be extended).
3. Current chunk completes; state persisted.
4. If transcription not yet done, schedule `BGProcessingTaskRequest` (same as path a, but no notification prompt — only prompts on explicit user action).
5. End background task.

### 7.3 BG task handler

Registered in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`:

```swift
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.sonicmerge.smartcut.transcribe",
    using: nil
) { task in
    BackgroundTranscriptionTask.handle(task as! BGProcessingTask)
}
```

`BackgroundTranscriptionTask.handle`:
1. Loads `TranscriptionState` from disk.
2. Resumes processing from the next chunk.
3. Sets `task.expirationHandler` to persist state and reschedule if iOS calls expiration before completion.
4. On completion: writes final state, posts local notification (`"Smart Cut finished — 47 fillers found in your episode"`), marks `task.setTaskCompleted(success: true)`.
5. Schedules itself again if more chunks remain.

### 7.4 Reopening the app

`SmartCutViewModel.onAppear` checks for an existing `TranscriptionState` matching the current input source's hash. If found:
- If complete: load EditList, jump to State 3.
- If partial: load progress, show State 2 with "Resumed at 4:23 — continuing in foreground" message and resume processing.
- If notification was the trigger for app open: jump straight to State 3.

### 7.5 Acknowledged limitations

- iOS gives no SLA on `BGProcessingTask` execution — it may run minutes, hours, or days later (or never, if the device is rarely on charger). The notification UX is honest about this: no claim of when it will complete.
- If the user re-merges in Mixing Station while a BG task is pending, the input source hash changes and the pending state is discarded on next foreground (see § 8 stale-state handling).
- BG processing cannot be tested deterministically — see § 9.3.

## 8. Error handling

| Failure | When | Handling |
|---|---|---|
| Speech recognition permission denied | First Analyze tap | Inline alert: "Smart Cut needs Speech Recognition access — [Open Settings]". Card stays in State 1. |
| Notification permission denied | First "Run in BG" tap | BG task still scheduled (works without notification). Show non-blocking note: "Tip: enable notifications to be alerted when done." |
| `BGProcessingTask` never fires | After 30+ min | If user re-foregrounds and task hasn't run, resume in foreground from saved state. No silent failure. |
| Audio file unreadable / corrupted | TranscriptionService load | Card flips to error state: "Could not read audio. Try re-merging." Reset button visible. |
| Zero segments returned (silent file) | Detector pass | State 3 with "Found 0 fillers · nothing to cut" message. Apply button disabled. |
| Audio shorter than 30 seconds | Analyze tap | Inline note: "Smart Cut works best on audio over 30s." Allow but show low-confidence warning. |
| `SFSpeechRecognizer.isAvailable == false` | App launch / Analyze tap | Card shows: "Smart Cut requires iOS Speech Recognition. Currently unavailable." Most common cause: device offline + on-device model not yet downloaded. |
| AudioCutter write fails (disk full) | Apply tap | Toast: "Couldn't write output — free up some space." EditList preserved. |
| User backgrounds during Apply (not Analyze) | AVAssetWriter mid-write | Use `beginBackgroundTask` for the ~10-30s cut operation. Cuts always complete. |
| App killed mid-background-transcription | BG task running | `TranscriptionState` persisted after each chunk. On next launch, card loads in State 2 with progress restored, prompts user to resume. |
| Input source hash changes while BG task pending | User re-merges in Mixing Station | Pending state discarded on next foreground. Card resets to State 1. |

## 9. Testing approach

### 9.1 Unit tests

Located in `/SonicMergeTests/Features/SmartCut/`. XCTest, no snapshot harness.

- **`FillerDetectorTests`** — fixture transcripts → expected `[FillerEdit]`. Coverage:
    - case insensitivity (`UM` matches as `um`)
    - punctuation handling (`um,` and `um.` both match)
    - multi-word phrases (`you know`, `sort of`)
    - default-on vs default-off classification at construction time
    - "like" and other ambiguous-as-real-word fillers — documented gap: no verb/noun discrimination in v1; default-off mitigates user impact
- **`PauseDetectorTests`** — fixture segment timings → expected `[PauseEdit]`. Coverage:
    - threshold boundaries (1.499s vs 1.5s vs 1.501s)
    - leading/trailing silence (handled the same as inter-word silence)
    - multiple thresholds (1.0s / 1.5s / 2.0s / custom)
    - documented limitation: music gaps are detected and cut the same as silence — no music-vs-silence discrimination in v1
- **`EditListTests`**:
    - category toggle propagates to all children
    - individual child toggle does not change category state (category checkbox shows mixed/intermediate visual)
    - codable round-trip
    - duration math: `enabledSavings == sum(enabled.duration)`
- **`FillerLibraryTests`**:
    - default words present
    - custom-add persists across launches (via test sandbox UserDefaults)
    - dedup (adding existing word is no-op)
    - removing a default word is allowed and persisted
- **`AudioCutterTests`**:
    - fixture WAV (5s) + EditList with single 200ms cut → output duration `≈ 4.8s ± 50ms`
    - empty EditList → output is a copy of input (durations equal within 1 frame)
    - all-disabled EditList → same as empty
    - byte equality NOT asserted (encoder nondeterminism)
- **`BackgroundTranscriptionTaskTests`**:
    - `TranscriptionState` save/load round-trip
    - resume picks up at correct chunk index
    - state hash invalidation when source URL changes

### 9.2 Integration test (slow, fixture-driven)

One end-to-end test using a bundled 60-second sample WAV with known content:
> *"um hello uh world like this"* + 2 seconds silence + *"yeah basically that's it"*

Expected behavior:
- `SmartCutService.analyze()` returns an EditList containing:
    - 2 `FillerEdit`s for `um` and `uh`
    - 1 `FillerEdit` for `like` (default-off, `isEnabled = false`)
    - 1 `FillerEdit` for `basically` (default-off, `isEnabled = false`)
    - 1 `PauseEdit` for the 2-second silence at the boundary
- Timestamps within ±100ms tolerance for recognizer drift.
- `AudioCutter.apply()` with default-enabled subset produces output ≈ `originalDuration - umDuration - uhDuration - pauseDuration`.

### 9.3 Not testable in v1 (acknowledged gaps)

- **`SFSpeechRecognizer` accuracy** — Apple framework, can't mock its outputs meaningfully. The integration test gives a smoke signal, not exhaustive coverage. Detection quality is a manual-QA concern.
- **BG task scheduling** — iOS's scheduler is opaque. We can test the *coordinator's* state transitions (resume from saved state, expiration handling) but not whether iOS actually fires the task on a real device.
- **A/B "Cleaned" preview before Apply** — synthesized via dynamic segment scheduling. Validation is by ear, not assertion.
- **Audio quality of cut seams** — subjective.

### 9.4 Manual QA protocol

Documented and executed before merging the feature:

5 sample episodes covering (interview, monologue, casual chat, music-heavy, multi-speaker). For each:
1. Run Smart Cut to completion.
2. Listen to 3 random seams selected from the EditList (one filler cut, one pause cut, one boundary near a speaker change if multi-speaker).
3. Listen to 30 seconds end-to-end of the cleaned output.
4. **Pass criterion**: no audible click/pop on >80% of seams sampled across the 5 episodes; no unintended word truncation observed; pause cuts feel natural (not abruptly compressed).

Track results in a checklist appended to the implementation PR.

## 10. Open questions / future work (not in v1)

These are intentionally deferred. Capturing here so the writing-plans phase doesn't accidentally re-litigate them.

- **Cloud transcription as Pro-tier upgrade** (Whisper / AssemblyAI). Extends `TranscriptionService` with a strategy interface; UI gains a settings switch. Saved for after monetization is in place.
- **Full transcript editor** (Descript-style). Pro-tier. Requires word-level UI rendering, scrubbing, and edit-by-text engine. Reuses the `EditList` model.
- **Music-aware pause detection**. Detect spectral content vs. true silence to avoid cutting musical rests. Needs a small classifier.
- **Multilingual filler libraries**. Localized presets for Spanish, French, etc. Library is already user-extensible; localized defaults are additive.
- **Per-speaker filler stats** (diarization-dependent). Requires speaker-segmentation model; may piggyback on a Pro tier.
- **Crossfade duration as user setting**. Default 25 ms is a fine baseline; advanced users may want control. Not worth the surface area in v1.

## 11. Appendix — Design decisions and rationale

The design above is the result of 12 sequential decisions made during brainstorming. Recording them here for context — useful when re-evaluating any of these in future:

| ID | Question | Decision | Reason |
|---|---|---|---|
| Q4 | Where does Smart Cut live? | A — Extend Cleaning Lab | Reuses existing AI/cleanup mental model; keeps app to 2 navigation pillars. |
| Q5 | How deep is the editing UI? | 2 — Filler-list panel with per-type checkboxes | Sweet spot between "black box" (depth 1) and full transcript editor (depth 3). |
| Q6 | What counts as a filler? | c — User-configurable, with set b as defaults | Set b ("um/uh/ah/er + like/you know/sort of/basically/actually/literally") covers common podcast cleanup; user-add covers gaps. |
| Q7 | Auto-trim long pauses too? | ii — Bundled with filler removal | Both are time-savers from the same hero feature; one feature, one entry point. |
| Q8 | Detection backend? | A — On-device Apple Speech only | Free forever, private, no API plumbing, Apple's recognizer is good enough for filler-token detection. |
| Q9 | Denoise + Smart Cut coexistence? | B — Independent tools, user picks order | Maximum flexibility; pipeline order is fixed under the hood (denoise → smart-cut) but presented as independent. |
| Q10 | A/B verification UX? | C — Toggle (macro) + per-filler preview (micro) | Two distinct trust-building modes ("does it flow?" + "is THIS cut OK?"). |
| Q11 | Trigger / lifecycle? | B — Manual Analyze button | Independent tools deserve independent intent; transcription is expensive enough to require consent. |
| Q12 | Background processing? | 2 — True BG via BGProcessingTask + notification | User explicitly chose the heavy interpretation; cost accepted. |

---

*End of spec.*
