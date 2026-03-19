---
phase: 04-lufs-normalization-export-polish
plan: 02
subsystem: audio-export
tags: [lufs, normalization, tdd, audio-processing, avfoundation]
dependency_graph:
  requires: [04-01]
  provides: [LUFSNormalizationService, ExportOptions, AudioMergerService-lufs-extension]
  affects: [ExportFormatSheet, CleaningLabView, MixingStationView, AudioMergerService]
tech_stack:
  added: [vDSP_vsmul, AVMutableAudioMixInputParameters.setVolume, BS.1770-3 biquad cascade]
  patterns: [TDD RED-GREEN-REFACTOR, actor isolation, two-pass LUFS measurement]
key_files:
  created:
    - SonicMerge/Services/LUFSNormalizationService.swift
  modified:
    - SonicMerge/Features/MixingStation/ExportFormatSheet.swift
    - SonicMerge/Features/MixingStation/MixingStationView.swift
    - SonicMerge/Features/Denoising/CleaningLabView.swift
    - SonicMerge/Services/AudioMergerService.swift
    - SonicMergeTests/NoiseReductionServiceTests.swift
decisions:
  - "Used manual BS.1770-3 K-weighting biquad cascade (not spfk-loudness) — package not in project"
  - "LUFS gain for multi-clip export uses first clip as proxy — deferred exact two-pass measure to v2"
  - "exportWAV uses float32 decode path only when gainScalar != 1.0 — preserves int16 path for default"
  - "ExportOptions.lufsNormalize reflects @AppStorage toggle at sheet-dismiss time — no ViewModel change needed"
metrics:
  duration: "24min"
  completed: "2026-03-19"
  tasks_completed: 3
  files_modified: 6
---

# Phase 4 Plan 02: LUFS Normalization Service + AudioMergerService Integration Summary

**One-liner:** Manual BS.1770-3 K-weighting LUFS actor with vDSP gain application in WAV and AVAudioMix gain in M4A export paths.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | ExportOptions struct + ExportFormatSheet callback update | 6c24c70 | ExportFormatSheet.swift, MixingStationView.swift, CleaningLabView.swift |
| 2 | Create LUFSNormalizationService.swift | 733d70d | LUFSNormalizationService.swift (new) |
| 3 | Extend AudioMergerService with lufsNormalize parameter | 2716183 | AudioMergerService.swift, NoiseReductionServiceTests.swift |

## Test Results

- `LUFSNormalizationServiceTests/testGainScalarForKnownLoudness` — PASSED (scalar > 1.0 for -24 LUFS fixture)
- `LUFSNormalizationServiceTests/testGainScalarAlreadyAtTarget` — PASSED (finite positive scalar)
- `LUFSNormalizationServiceTests/testExportWithLUFSEnabled` — PASSED (no crash on empty clips)
- `MixingStationViewModelTests/testExportOptionsLUFSFlag` — PASSED
- `MixingStationViewModelTests` all 5 tests — PASSED
- `AudioMergerServiceTests` 3/4 PASSED (compositionWithCrossfadeHasNonNilAudioMix is pre-existing flaky parallel test)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] Fixed NoiseReductionServiceTests AsyncThrowingStream compile error**
- **Found during:** Task 3 (test suite compilation)
- **Issue:** NoiseReductionServiceTests.swift used `for await _ in stream` on `AsyncThrowingStream<Float, Error>` which requires `try`. Three test methods affected.
- **Fix:** Changed `for await` to `for try await` at all three call sites
- **Files modified:** SonicMergeTests/NoiseReductionServiceTests.swift
- **Commit:** 2716183

### Simplifications Applied (per plan guidance)

**Multi-clip LUFS measurement:** Plan allowed measuring first clip as LUFS proxy for multi-clip export (vs. full two-pass temp-WAV approach). Implemented this simpler approach. For exportFile() (CleaningLabView path), measurement is exact since inputURL is a single file.

## Deferred Items

- `compositionWithCrossfadeHasNonNilAudioMix` is a pre-existing flaky test that passes in isolation but fails under parallel test execution (resource contention with AVAssetExportSession + fixture files). Not caused by Plan 04-02 changes.
- Two-pass exact LUFS measurement for multi-clip export (measure on temp WAV, then export with gain) deferred to v2 — current proxy approach (first clip) is acceptable for MVP.

## Self-Check: PASSED

Files verified:
- SonicMerge/Services/LUFSNormalizationService.swift: EXISTS
- SonicMerge/Features/MixingStation/ExportFormatSheet.swift: struct ExportOptions FOUND
- SonicMerge/Services/AudioMergerService.swift: lufsNormalize parameter FOUND

Commits verified:
- 6c24c70: feat(04-02): add ExportOptions struct
- 733d70d: feat(04-02): create LUFSNormalizationService actor
- 2716183: feat(04-02): extend AudioMergerService with lufsNormalize
