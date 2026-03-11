---
phase: 02-merge-pipeline-mixing-station-ui
plan: 01
subsystem: testing
tags: [swift-testing, tdd, waveform, audio-merger, swiftdata, red-state]

# Dependency graph
requires:
  - phase: 01-foundation-import-pipeline
    provides: AudioClip model, AudioNormalizationService pattern, PBXFileSystemSynchronizedRootGroup test inclusion

provides:
  - WaveformServiceTests.swift — failing stubs for IMP-04 waveform generation (RED)
  - MixingStationViewModelTests.swift — failing stubs for MRG-01, MRG-02, EXP-04 (RED)
  - AudioMergerServiceTests.swift — failing stubs for MRG-03, MRG-04, EXP-01, EXP-02 (RED)
  - Defined API surface for WaveformService, MixingStationViewModel, AudioMergerService, GapTransition

affects: 02-02, 02-03, 02-04

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Contract-first TDD: stub tests define API surface before any production code is written"
    - "BundleLocator pattern for fixture URL resolution in Swift Testing (private final class BundleLocator {})"
    - "In-memory ModelContainer for isolation: ModelContainer(for: AudioClip.self, GapTransition.self, configurations: config)"

key-files:
  created:
    - SonicMergeTests/WaveformServiceTests.swift
    - SonicMergeTests/MixingStationViewModelTests.swift
    - SonicMergeTests/AudioMergerServiceTests.swift
  modified: []

key-decisions:
  - "WaveformService API: actor with func generate(audioURL:destinationURL:) async throws — 50 Float peaks written to sidecar file"
  - "MixingStationViewModel API: @Observable @MainActor with moveClip(fromOffsets:toOffset:), deleteClip(atOffsets:), cancelExport(), exportMerged(format:), isExporting, exportedFileURL, clips, fetchAll()"
  - "AudioMergerService API: actor with export(clips:transitions:format:destinationURL:) -> AsyncStream<Float> and ExportFormat enum (.m4a, .wav)"
  - "GapTransition API: @Model with leadingClipSortOrder, gapDuration, isCrossfade, audioClip relationship"
  - "Crossfade duration fixed at 0.5s — tests assert total duration of 1.5s for two 1s clips with crossfade"

patterns-established:
  - "Wave 0 RED stubs: stub references type names and method signatures; compile error is the failure signal"
  - "AsyncStream<Float> for export progress reporting — mirrors AVAssetExportSession polling pattern"

requirements-completed: [IMP-04, MRG-01, MRG-02, MRG-03, MRG-04, EXP-01, EXP-02, EXP-04]

# Metrics
duration: 3min
completed: 2026-03-11
---

# Phase 2 Plan 01: TDD Stub Files Summary

**Contract-first RED stubs for WaveformService, MixingStationViewModel, AudioMergerService, and GapTransition — locking API surface before implementation begins**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-11T15:10:22Z
- **Completed:** 2026-03-11T15:13:33Z
- **Tasks:** 3 completed
- **Files modified:** 3

## Accomplishments

- Created WaveformServiceTests.swift with 2 IMP-04 stubs (actor API with 50-peak sidecar file)
- Created MixingStationViewModelTests.swift with 3 stubs (MRG-01 reorder, MRG-02 delete, EXP-04 cancel)
- Created AudioMergerServiceTests.swift with 4 stubs (MRG-03 gap, MRG-04 crossfade, EXP-01 m4a, EXP-02 wav)
- All files auto-included in test target via PBXFileSystemSynchronizedRootGroup — no project.pbxproj edits required
- All three files in RED compile state — only missing-type errors, no syntax errors in stub code itself

## Task Commits

Each task was committed atomically:

1. **Task 1: Create WaveformServiceTests.swift stub** - `f19ac71` (test)
2. **Task 2: Create MixingStationViewModelTests.swift stub** - `5331cc1` (test)
3. **Task 3: Create AudioMergerServiceTests.swift stub** - `579e461` (test)

## Files Created/Modified

- `SonicMergeTests/WaveformServiceTests.swift` - IMP-04 stubs: generates 50 Float peaks, writes sidecar to destination URL
- `SonicMergeTests/MixingStationViewModelTests.swift` - MRG-01/MRG-02/EXP-04 stubs: reorder, delete, cancel export
- `SonicMergeTests/AudioMergerServiceTests.swift` - MRG-03/MRG-04/EXP-01/EXP-02 stubs: gap duration, crossfade, m4a, wav export

## Decisions Made

- WaveformService stores exactly 50 Float peaks per clip — test asserts `data.count == 50 * MemoryLayout<Float>.size`
- AudioMergerService.export returns `AsyncStream<Float>` progress (0.0–1.0) — test confirms `finalProgress == 1.0`
- Crossfade overlap fixed at 0.5s — test asserts 1.5s total duration for two 1s clips
- GapTransition initializer: `GapTransition(leadingClipSortOrder: Int, gapDuration: Double, isCrossfade: Bool)` and `GapTransition(leadingClipSortOrder: Int)` default form
- MixingStationViewModel requires `fetchAll()` async method to populate `clips` from ModelContext

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- iPhone 16 simulator name caused xcodebuild destination error (visionOS platform lookup); resolved by using `iPhone 16e` which matched available iOS 26.2 simulator. Not a code issue — purely a build invocation detail.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All three RED stubs committed and structurally valid (no syntax errors in stub files)
- API contracts locked: Wave 1/2 implementations must satisfy these exact method signatures
- Plan 02 (GapTransition model) can proceed — stubs reference GapTransition throughout
- Plan 03 (WaveformService) can proceed — WaveformServiceTests defines the exact generate() signature
- Plan 04 (AudioMergerService) can proceed — AudioMergerServiceTests defines export() return type and fixture path convention

---
*Phase: 02-merge-pipeline-mixing-station-ui*
*Completed: 2026-03-11*

## Self-Check: PASSED

- FOUND: SonicMergeTests/WaveformServiceTests.swift
- FOUND: SonicMergeTests/MixingStationViewModelTests.swift
- FOUND: SonicMergeTests/AudioMergerServiceTests.swift
- FOUND: .planning/phases/02-merge-pipeline-mixing-station-ui/02-01-SUMMARY.md
- FOUND commit: f19ac71 (WaveformServiceTests stub)
- FOUND commit: 5331cc1 (MixingStationViewModelTests stub)
- FOUND commit: 579e461 (AudioMergerServiceTests stub)
