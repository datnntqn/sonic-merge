---
phase: 03-ai-denoising-pipeline
plan: 04
subsystem: ui
tags: [swiftui, avfoundation, canvas, navigationstack, toolbar, exportformatsheet, exportprogresssheet, audiomergerservice, cleaninglabviewmodel, denoising]

# Dependency graph
requires:
  - phase: 03-ai-denoising-pipeline
    plan: 03
    provides: CleaningLabViewModel @Observable @MainActor with startDenoising, cancelDenoising, holdBegan, holdEnded, onIntensityChanged, markClipsChanged, denoisedTempURL
  - phase: 02-merge-pipeline-mixing-station-ui
    provides: ExportFormatSheet, ExportProgressSheet, AudioMergerService.export, MixingStationView toolbar pattern
provides:
  - CleaningLabView SwiftUI screen with stale banner, waveform canvas, intensity slider, A/B button, export, non-dismissible progress modal
  - MixingStationView Denoise toolbar button (wand.and.sparkles) pushing CleaningLabView via navigationDestination
  - AudioMergerService.exportFile(inputURL:format:destinationURL:) for single-file format conversion
  - navigateToCleaningLab(): merges clips to temp .wav then pushes CleaningLabView
affects: [human-verification, Phase 3 end-to-end testing]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CleaningLabView as pure rendering layer over CleaningLabViewModel — all logic in ViewModel"
    - "WaveformCanvasView: SwiftUI Canvas symmetrical bar waveform from 50 Float peaks"
    - "Non-dismissible progress sheet via .sheet(isPresented: .constant(viewModel.isProcessing)) + .interactiveDismissDisabled(true)"
    - "A/B button via .onLongPressGesture(minimumDuration:0, pressing:) — fires holdBegan/holdEnded on press/release"
    - "AudioMergerService.exportFile: single-track AVMutableComposition wrap for pre-built audio file export"
    - "navigationDestination(isPresented:) + State URL var for programmatic NavigationStack push"

key-files:
  created:
    - SonicMerge/Features/Denoising/CleaningLabView.swift
  modified:
    - SonicMerge/Features/MixingStation/MixingStationView.swift
    - SonicMerge/Services/AudioMergerService.swift

key-decisions:
  - "AudioMergerService.exportFile(inputURL:format:destinationURL:) added as Rule 2 deviation — plan specified AudioMergerService.export(inputURL:format:) but existing API is clips-based; single-file export required for denoised output path"
  - "navigateToCleaningLab() merges clips to .wav before pushing — CleaningLabViewModel receives a pre-built merged file URL rather than raw clips, matching Plan 03-03 design"
  - "Two separate ExportProgressSheet instances in CleaningLabView — one for denoising progress (.constant(isProcessing)), one for export progress (@State showExportProgressSheet)"
  - "CleaningLabView exports via ActivityViewController (UIActivityViewController) after format conversion completes — matches Phase 2 share flow"

patterns-established:
  - "Single-file AudioMergerService export path: exportFile(inputURL:) wraps input in AVMutableComposition for format conversion without re-merging clips"

requirements-completed: [DNS-02, DNS-03, UX-02]

# Metrics
duration: 8min
completed: 2026-03-12
---

# Phase 3 Plan 04: CleaningLabView — Full UI Screen Summary

**SwiftUI CleaningLabView with Canvas waveform, intensity slider, A/B hold-to-compare button, non-dismissible ExportProgressSheet modal, and MixingStationView Denoise toolbar integration**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-03-12T16:22:51Z
- **Completed:** 2026-03-12T16:30:00Z
- **Tasks:** 1 of 2 automated (Task 2 is human-verify checkpoint)
- **Files modified:** 3 (created CleaningLabView.swift, modified MixingStationView.swift + AudioMergerService.swift)

## Accomplishments

- `CleaningLabView.swift` created with all 7 layout sections: stale banner, full-width Canvas waveform, intensity slider, A/B long-press button, denoise/re-process button, export toolbar item, non-dismissible progress modal
- `WaveformCanvasView` private view: SwiftUI Canvas drawing symmetrical bars from 50 Float peaks with scrub line overlay
- `MixingStationView` updated: `wand.and.sparkles` Denoise toolbar button; `navigateToCleaningLab()` merges clips to temp .wav then pushes `CleaningLabView` via `navigationDestination`
- `AudioMergerService.exportFile(inputURL:format:destinationURL:)` added: wraps a pre-built audio file in `AVMutableComposition` for format conversion without re-merging clips
- BUILD SUCCEEDED verified

## Task Commits

Each task committed atomically:

1. **Task 1: CleaningLabView full screen + MixingStationView toolbar** - `10abdab` (feat)

*Task 2 (checkpoint:human-verify) — awaiting human verification*

## Files Created/Modified

- `SonicMerge/Features/Denoising/CleaningLabView.swift` — Full Cleaning Lab screen: 7 layout sections, WaveformCanvasView Canvas, A/B long-press, export via ActivityViewController, non-dismissible progress sheet
- `SonicMerge/Features/MixingStation/MixingStationView.swift` — Added Denoise toolbar button + navigateToCleaningLab() + navigationDestination for CleaningLabView
- `SonicMerge/Services/AudioMergerService.swift` — Added exportFile(inputURL:format:destinationURL:) for single-file format conversion

## Decisions Made

- **AudioMergerService.exportFile addition**: The plan specified `AudioMergerService.export(inputURL:format:)` but the existing API is `export(clips:transitions:format:destinationURL:)`. The CleaningLabView export path operates on a pre-built .wav file (denoisedTempURL), not on clips. Adding `exportFile(inputURL:)` was a Rule 2 (missing critical functionality) auto-addition — it wraps the input file in a single-track `AVMutableComposition` and delegates to the existing `exportM4A`/`exportWAV` private methods.

- **Two-sheet pattern in CleaningLabView**: Two separate `ExportProgressSheet` presentations are used — one bound to `viewModel.isProcessing` (denoising) and one bound to `@State showExportProgressSheet` (export). Both use `interactiveDismissDisabled(true)`.

- **navigateToCleaningLab merges first**: The Denoise button in MixingStationView triggers a full merge-to-WAV via `AudioMergerService.export` before pushing `CleaningLabView`. This matches the `CleaningLabViewModel` contract where `startDenoising(mergedFileURL:)` receives a single pre-built URL.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added AudioMergerService.exportFile(inputURL:format:destinationURL:)**
- **Found during:** Task 1 (CleaningLabView export path implementation)
- **Issue:** Plan specified `AudioMergerService.export(inputURL: viewModel.denoisedTempURL!, format: selectedFormat)` but the existing `AudioMergerService.export` API is `export(clips:transitions:format:destinationURL:)`. No single-file export path existed.
- **Fix:** Added `exportFile(inputURL:format:destinationURL:)` method to AudioMergerService that wraps the input in a single-track AVMutableComposition and calls the existing `exportM4A`/`exportWAV` private methods.
- **Files modified:** `SonicMerge/Services/AudioMergerService.swift`
- **Verification:** BUILD SUCCEEDED; pattern is consistent with existing export paths
- **Committed in:** `10abdab` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Required for CleaningLabView export path to compile and function. No scope creep — reuses existing private export methods.

## Issues Encountered

None. BUILD SUCCEEDED on first compile attempt after implementing all sections.

## User Setup Required

None — no external service configuration required. DeepFilterNet3.mlpackage bundle requirement documented in docs/DENOISING_SETUP.md from Plan 03-01.

## Next Phase Readiness

- Phase 3 complete pending human verification checkpoint (Task 2)
- Human verifier should follow 9-step verification guide in the plan's checkpoint task
- Haptic feedback (UX-02) requires physical device for confirmation

---
*Phase: 03-ai-denoising-pipeline*
*Completed: 2026-03-12*
