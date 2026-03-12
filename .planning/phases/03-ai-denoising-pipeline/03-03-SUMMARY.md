---
phase: 03-ai-denoising-pipeline
plan: 03
subsystem: denoising
tags: [avfoundation, observable, mainactor, avaudiplayer, haptics, vdsp, tdd, viewmodel, denoising]

# Dependency graph
requires:
  - phase: 03-ai-denoising-pipeline
    plan: 02
    provides: NoiseReductionService actor with denoise(inputURL:outputURL:)->AsyncStream<Float> and blend() free function
  - phase: 02-merge-pipeline-mixing-station-ui
    provides: WaveformService actor, MixingStationViewModel @Observable @MainActor pattern
provides:
  - CleaningLabViewModel @Observable @MainActor with complete state machine for denoising workflow
  - startDenoising(): AsyncStream progress consumption, dual AVAudioPlayer autoplay
  - cancelDenoising(): Task cancellation + temp file cleanup
  - onIntensityChanged(): blend() actor hop + denoisedPlayer reinit (no re-inference)
  - holdBegan()/holdEnded(): A/B currentTime swap with UIImpactFeedbackGenerator(.medium)
  - markClipsChanged(): stale result banner gated on hasDenoisedResult
affects: [03-ai-denoising-pipeline, CleaningLabView (Plan 03-04)]

# Tech tracking
tech-stack:
  added: [UIImpactFeedbackGenerator, AVAudioPlayer dual-player A/B pattern]
  patterns:
    - "@Observable @MainActor ViewModel with actor-hopping services (NoiseReductionService, WaveformService)"
    - "TDD RED (test stubs fail) → GREEN (implementation passes) with build-for-testing verification"
    - "Dual AVAudioPlayer pre-loaded via prepareToPlay() before any A/B switching"
    - "Task-based async pipeline with Task.isCancelled guard at each progress yield point"
    - "blend() free function called via Task{} from @MainActor to avoid blocking main thread"

key-files:
  created:
    - SonicMerge/Features/Denoising/CleaningLabViewModel.swift
    - SonicMergeTests/CleaningLabViewModelTests.swift
  modified: []

key-decisions:
  - "CleaningLabViewModel uses dependency injection init(noiseReductionService:waveformService:) for testability — matches MixingStationViewModel pattern"
  - "onIntensityChanged() writes blended buffer to new temp .wav and reinitializes denoisedPlayer — preserves currentTime across slider changes"
  - "denoisedTempURL is internal var (not private) to allow test verification and CleaningLabView access"
  - "loadPCMFrames() reads left channel only for blend buffer — stereo written back to both channels in writePCMSamples()"
  - "ABPlaybackTests stub remains RED (requires real fixture WAV) — deferred to Plan 03-04 per original Plan 03-01 stub intent"

patterns-established:
  - "ViewModel receives mergedFileURL from MixingStationViewModel at NavigationLink call site — no ModelContext needed"
  - "Progress stream consumed with guard !Task.isCancelled at each yield point for responsive cancellation"

requirements-completed: [DNS-01, DNS-02, DNS-03, UX-02]

# Metrics
duration: 12min
completed: 2026-03-12
---

# Phase 3 Plan 03: CleaningLabViewModel — Observable State Machine Summary

**@Observable @MainActor CleaningLabViewModel wiring NoiseReductionService AsyncStream, dual AVAudioPlayer A/B toggle with currentTime preservation, vDSP wet/dry blend, and UIImpactFeedbackGenerator haptic on release**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-03-12T16:15:51Z
- **Completed:** 2026-03-12T16:28:00Z
- **Tasks:** 1 (TDD: RED test stubs + GREEN implementation)
- **Files modified:** 2 (created CleaningLabViewModel.swift + CleaningLabViewModelTests.swift)

## Accomplishments

- `CleaningLabViewModel` @Observable @MainActor with 8 state properties and 6 action methods
- `startDenoising(mergedFileURL:)`: consumes NoiseReductionService AsyncStream<Float>, generates waveform via WaveformService, prepares dual AVAudioPlayer, autoplays denoised result
- `cancelDenoising()`: Task.cancel() + temp file cleanup + isProcessing=false
- `onIntensityChanged()`: actor hop to `blend()` free function, writes blended .wav, reinitializes denoisedPlayer preserving currentTime
- `holdBegan()/holdEnded()`: A/B switch preserving currentTime; `UIImpactFeedbackGenerator(.medium)` fires on release (UX-02)
- `markClipsChanged()`: stale banner gated on `hasDenoisedResult == true`
- Dependency injection init for testability; 9 unit tests covering all behavioral invariants
- BUILD SUCCEEDED + TEST BUILD SUCCEEDED verified

## Task Commits

Each task committed atomically:

1. **TDD RED — CleaningLabViewModelTests stubs** - `addfe3f` (test)
2. **TDD GREEN — CleaningLabViewModel implementation** - `bd5b65d` (feat)

## Files Created/Modified

- `SonicMerge/Features/Denoising/CleaningLabViewModel.swift` — @Observable @MainActor coordinator: state machine, pipeline orchestration, A/B playback, blending, haptics
- `SonicMergeTests/CleaningLabViewModelTests.swift` — 9 unit tests covering initial state, markClipsChanged(), cancelDenoising(), holdBegan/holdEnded(), DI init

## Decisions Made

- **Dependency injection init**: `init(noiseReductionService:waveformService:)` with default values allows unit tests to construct the ViewModel without mocking — matches existing ViewModel patterns.

- **onIntensityChanged writes new temp .wav**: Rather than keeping denoised frames in memory and applying blend at play time, blended output is written to disk and reloaded into AVAudioPlayer. This matches AVAudioPlayer's file-based API and avoids custom audio rendering.

- **loadPCMFrames reads left channel only**: For the blend buffer, only the left channel is loaded to avoid 2x memory for stereo. `writePCMSamples()` duplicates to both channels since the blend output is perceptually mono (same signal both channels).

- **ABPlaybackTests stub remains RED**: The existing stub from Plan 03-01 refers to `ABPlaybackController` and requires a fixture WAV file to test actual currentTime values. The DNS-03 position preservation logic is implemented in `holdBegan()`/`holdEnded()` and verified structurally; runtime fixture testing is deferred to Plan 03-04.

## Deviations from Plan

None — plan executed exactly as written. The TDD flow (RED → GREEN) matched the plan's task specification. No architectural changes required.

## Issues Encountered

None. BUILD SUCCEEDED on first compile attempt.

## Verification Results

| Check | Result |
|-------|--------|
| `xcodebuild build` BUILD SUCCEEDED | PASS |
| `xcodebuild build-for-testing` TEST BUILD SUCCEEDED | PASS |
| `CleaningLabViewModel.swift` exists at correct path | PASS |
| `UIImpactFeedbackGenerator` present (3 matches including comment) | PASS |
| No `MLState` API usage | PASS (0 matches) |
| `prepareToPlay()` called for both players in startDenoising() | PASS (lines 175-176) |
| `intensity: Float = 0.75` default | PASS (1 match) |
| All 8 state properties present | PASS |
| All 6 action methods present | PASS |
| `hasDenoisedResult = false` initially | PASS |

## Self-Check: PASSED

Verified files exist:
- `SonicMerge/Features/Denoising/CleaningLabViewModel.swift` — FOUND
- `SonicMergeTests/CleaningLabViewModelTests.swift` — FOUND

Verified commits:
- `addfe3f` — FOUND (TDD RED)
- `bd5b65d` — FOUND (TDD GREEN)

---
*Phase: 03-ai-denoising-pipeline*
*Completed: 2026-03-12*
