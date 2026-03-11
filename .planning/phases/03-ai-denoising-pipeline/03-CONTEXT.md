# Phase 3: AI Denoising Pipeline - Context

**Gathered:** 2026-03-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Add on-device Core ML noise reduction as an optional post-processing step. The user visits a dedicated Cleaning Lab screen, merges their clips, applies denoising at chosen intensity, A/B compares the result, and exports — entirely offline. Denoising is not part of the Mixing Station editing workflow; it is a separate, explicit step the user opts into.

Scope: CleaningLabView, NoiseReductionService, intensity slider, A/B playback, haptic feedback. No per-clip denoising, no always-on processing, no new export formats.

</domain>

<decisions>
## Implementation Decisions

### Navigation & Screen Entry
- CleaningLabView is a **separate screen** pushed onto the NavigationStack from MixingStationView
- Entry point: a **'Denoise' toolbar button** on the Mixing Station navigation bar (alongside Import and Export)
- CleaningLabView has its **own Export button** — user can export from this screen without returning to Mixing Station; reuses the same `ExportFormatSheet` and `ExportProgressSheet` from Phase 2

### What CleaningLabView Processes
- Operates on the **merged output of the current clip sequence** — CleaningLabView triggers a merge + denoise pipeline when the user taps the Denoise action
- Denoising is **optional**: if the user never visits CleaningLabView, the Mixing Station Export exports raw merged audio with no denoising
- If the user **edits clips after denoising** (add/reorder/delete in Mixing Station), CleaningLabView shows a **"Clips have changed — re-process?" banner** when revisited; the stale denoised result is preserved until the user explicitly re-processes or it is discarded on re-process

### Intensity Slider
- Slider range: **0–100%**; default position: **75%** when CleaningLabView opens
- Denoising runs **once at full (100%) strength** to produce the denoised buffers
- The slider performs a **wet/dry mix** between the original and fully-denoised audio buffers — 0% = fully original, 100% = fully denoised; no re-inference per slider position
- Dragging the slider during A/B playback updates the mix in real-time (blend, not re-run)

### Processing Progress
- Tapping the 'Denoise' button shows a **non-dismissible progress modal** with a progress bar (0–100%) and a Cancel button — consistent with the Phase 2 export modal pattern
- Cancelled denoising: progress modal dismisses, denoised result is discarded, user returns to CleaningLabView pre-processed state

### A/B Comparison & Playback
- After denoising completes, the **denoised audio plays automatically** from the start
- Playback UI: **full-width waveform with a scrub/position indicator** — generated via WaveformService (consistent with Phase 2 clip card waveform thumbnails)
- A/B control: **hold-to-hear-original button** — hold = original plays from current position; release = denoised resumes from the same position. Seamless comparison, no seeking gap
- Releasing the button triggers a **distinct haptic tap** (UIImpactFeedbackGenerator, `.medium` style) — UX-02

### Claude's Discretion
- Core ML model selection, architecture, and bundle integration (research phase will resolve this)
- Exact merge + denoise pipeline orchestration (whether CleaningLabView triggers a new AVMutableComposition merge or reuses a cached merged file)
- Waveform generation timing for the denoised output (after denoising completes, before autoplay)
- Buffer chunk size for Core ML inference streaming
- Error state UX if denoising fails (Core ML model load error, OOM, etc.)
- Visual layout details of CleaningLabView beyond the decisions above

</decisions>

<specifics>
## Specific Ideas

- The wet/dry mix approach makes the slider feel instant and responsive — no waiting after every adjustment
- "Clips have changed — re-process?" banner keeps the user in control without silently discarding work
- Hold-to-hear-original is the most natural A/B mechanic for audio — no mode switching, just muscle memory
- CleaningLabView's waveform uses the same WaveformService already in the codebase — no new visualization infrastructure needed

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `WaveformService` (`Services/WaveformService.swift`): generates 50-peak waveform sidecar files — reuse for denoised audio waveform display in CleaningLabView
- `ExportFormatSheet` + `ExportProgressSheet` (`Features/MixingStation/`): Phase 2 export sheets — reuse directly from CleaningLabView's Export button
- `AudioMergerService` (`Services/AudioMergerService.swift`): CleaningLabView needs a merged file as input — either reuse AudioMergerService to produce a temp merged file, or accept the merged URL as input
- `ActivityViewController` (`Features/MixingStation/`): post-export share sheet — reuse from CleaningLabView

### Established Patterns
- `@Observable @MainActor` ViewModel with `ModelContext` injected — `CleaningLabViewModel` follows this pattern
- Actor-based background services for audio work (actor hop from `@MainActor` ViewModel) — `NoiseReductionService` follows `AudioNormalizationService` / `AudioMergerService` pattern
- Non-dismissible modal sheet with progress bar + Cancel — same sheet pattern as `ExportProgressSheet`
- Store filename-only relative paths in SwiftData, reconstruct URL via `AppConstants.clipsDirectory()` at runtime

### Integration Points
- `MixingStationView` toolbar: add 'Denoise' `ToolbarItem` alongside existing Import and Export buttons
- `MixingStationViewModel`: needs a way to pass current sorted clips + transitions to CleaningLabView (passed as NavigationLink value or environment injection)
- `SonicMergeApp.swift` / navigation: CleaningLabView pushed via NavigationStack — no new root view or tab needed
- `NoiseReductionService` (new actor, `/Features/Denoising/`): Core ML inference pipeline; called from `CleaningLabViewModel`

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 03-ai-denoising-pipeline*
*Context gathered: 2026-03-11*
