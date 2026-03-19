---
phase: 04-lufs-normalization-export-polish
plan: "01"
subsystem: testing
tags: [swift-testing, tdd, lufs, wave-0, fixtures, audio]

requires:
  - phase: 03-ai-denoising-pipeline
    provides: AudioMergerService export API, NoiseReductionService test patterns, Swift Testing BundleLocator pattern

provides:
  - stereo_-24lufs_48000.wav fixture at known amplitude for deterministic gain scalar assertions
  - LUFSNormalizationServiceTests.swift with 3 failing stubs referencing LUFSNormalizationService (DNE)
  - MixingStationViewModelTests.swift extended with 2 failing stubs for ExportOptions and dismissShareSheet reset

affects:
  - 04-02 (must create LUFSNormalizationService, ExportOptions, and lufsNormalize parameter to make tests green)
  - 04-03 (must fix dismissShareSheet() to reset exportProgress = 0)

tech-stack:
  added: []
  patterns:
    - "Wave 0 RED-state TDD: tests reference non-existent types to force compile failure until implementation plans run"
    - "Fixture generation via Python wave module + afconvert (project standard, no ffmpeg dependency)"
    - "BundleLocator private final class inside struct for Bundle(for:) fixture resolution"

key-files:
  created:
    - SonicMergeTests/Fixtures/stereo_-24lufs_48000.wav
    - SonicMergeTests/LUFSNormalizationServiceTests.swift
  modified:
    - SonicMergeTests/MixingStationViewModelTests.swift

key-decisions:
  - "Used BundleLocator private inner class (project pattern) instead of SonicMergeTestsMarker outer class — all existing test files use this convention"
  - "Fixture amplitude 0.063 (~-24 dBFS) chosen to guarantee gain scalar > 1.0 when targeting -16 LUFS — exact LUFS value not required, only needs to be measurably below target"

patterns-established:
  - "Wave 0 tests: intentionally reference types that do not exist (LUFSNormalizationService, ExportOptions, lufsNormalize parameter) to enforce RED compile state"

requirements-completed: [EXP-03]

duration: 4min
completed: 2026-03-19
---

# Phase 4 Plan 01: Wave 0 Test Infrastructure for LUFS Normalization Summary

**Three failing test stubs — LUFSNormalizationServiceTests (3 tests), MixingStationViewModelTests extended (+2 tests), and stereo_-24lufs_48000.wav fixture — establishing RED compile state for EXP-03**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-19T14:42:17Z
- **Completed:** 2026-03-19T14:46:37Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Generated `stereo_-24lufs_48000.wav` (580,096 bytes, stereo 48 kHz 16-bit PCM) via Python wave + afconvert — provides a deterministic ~-24 dBFS fixture for gain scalar unit tests
- Created `LUFSNormalizationServiceTests.swift` with 3 failing stubs: `testGainScalarForKnownLoudness`, `testGainScalarAlreadyAtTarget`, `testExportWithLUFSEnabled` — all reference `LUFSNormalizationService` and `lufsNormalize` parameter that don't exist yet
- Extended `MixingStationViewModelTests.swift` from 3 to 5 tests: added `testExportOptionsLUFSFlag` (references `ExportOptions` DNE) and `testDismissShareSheetResetsState` (asserts `exportProgress == 0` which current implementation does not reset)

## Task Commits

Each task was committed atomically:

1. **Task 1: Generate stereo_-24lufs_48000.wav fixture** - `f4f44ba` (chore)
2. **Task 2: Create LUFSNormalizationServiceTests.swift** - `d06b934` (test)
3. **Task 3: Add failing stubs to MixingStationViewModelTests.swift** - `64a428f` (test)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `SonicMergeTests/Fixtures/stereo_-24lufs_48000.wav` - 3-second 1 kHz sine at ~-24 dBFS, stereo 48 kHz PCM WAV
- `SonicMergeTests/LUFSNormalizationServiceTests.swift` - 3 RED-state test stubs for EXP-03 gain scalar and export integration
- `SonicMergeTests/MixingStationViewModelTests.swift` - Appended 2 new failing stubs; 5 total @Test methods

## Decisions Made

- Used `BundleLocator` private inner class pattern (matching all existing test files) instead of `SonicMergeTestsMarker` outer class specified in plan — project convention is private inner class per struct
- Fixture amplitude `0.063` (≈ -24 dBFS) sufficient for gain scalar tests: only needs to be measurably below -16 LUFS so `gainScalar > 1.0` reliably holds; exact LUFS not required at this stage

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Used BundleLocator pattern instead of SonicMergeTestsMarker**
- **Found during:** Task 2 (Create LUFSNormalizationServiceTests.swift)
- **Issue:** Plan specified `SonicMergeTestsMarker` outer class, but all existing test files use `private final class BundleLocator {}` as inner class within the test struct — using a different name would break convention and potentially conflict
- **Fix:** Used `private final class BundleLocator {}` inside `LUFSNormalizationServiceTests` struct, matching AudioMergerServiceTests, NoiseReductionServiceTests, WaveformServiceTests patterns
- **Files modified:** SonicMergeTests/LUFSNormalizationServiceTests.swift
- **Verification:** Matches grep results from all existing test files
- **Committed in:** d06b934 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - convention alignment)
**Impact on plan:** Consistent with project pattern. No behavior change — BundleLocator and SonicMergeTestsMarker serve identical purpose.

## Issues Encountered

None — all tasks executed cleanly with shell tools and file writes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- RED state confirmed: `LUFSNormalizationService`, `ExportOptions`, and `lufsNormalize` parameter do not exist — build will fail on compile
- Plan 04-02 must create: `LUFSNormalizationService` actor with `gainScalar(for:) async -> Double`, `ExportOptions` struct with `format` and `lufsNormalize` fields, and `lufsNormalize` parameter on `AudioMergerService.export`
- Plan 04-03 must fix: `dismissShareSheet()` to reset `exportProgress = 0` (currently only resets `showShareSheet` and `exportedFileURL`)
- All 3 test files are committed and will be auto-included by Xcode's `PBXFileSystemSynchronizedRootGroup`

---
*Phase: 04-lufs-normalization-export-polish*
*Completed: 2026-03-19*

## Self-Check: PASSED

- FOUND: SonicMergeTests/Fixtures/stereo_-24lufs_48000.wav
- FOUND: SonicMergeTests/LUFSNormalizationServiceTests.swift
- FOUND: SonicMergeTests/MixingStationViewModelTests.swift (modified)
- FOUND: .planning/phases/04-lufs-normalization-export-polish/04-01-SUMMARY.md
- Commits f4f44ba, d06b934, 64a428f all present in git log
