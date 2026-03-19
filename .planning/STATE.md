---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: planning
stopped_at: Completed 04-03-PLAN.md
last_updated: "2026-03-19T15:23:22.617Z"
last_activity: 2026-03-08 — Roadmap created; all 17 v1 requirements mapped to 5 phases.
progress:
  total_phases: 5
  completed_phases: 2
  total_plans: 18
  completed_plans: 15
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-08)

**Core value:** Users can merge audio clips and remove background noise in seconds — all on-device, with no quality loss and no privacy concerns.
**Current focus:** Phase 1 — Foundation + Import Pipeline

## Current Position

Phase: 1 of 5 (Foundation + Import Pipeline)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-03-08 — Roadmap created; all 17 v1 requirements mapped to 5 phases.

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 01-foundation-import-pipeline P02 | 4 | 2 tasks | 4 files |
| Phase 01-foundation-import-pipeline P01 | 35 | 2 tasks | 9 files |
| Phase 01-foundation-import-pipeline P03 | 23min | 1 tasks | 3 files |
| Phase 01-foundation-import-pipeline P04 | 15min | 2 tasks | 4 files |
| Phase 01-foundation-import-pipeline P04 | 15min | 3 tasks | 4 files |
| Phase 02-merge-pipeline-mixing-station-ui P01 | 3min | 3 tasks | 3 files |
| Phase 02-merge-pipeline-mixing-station-ui P03 | 25min | 2 tasks | 7 files |
| Phase 02-merge-pipeline-mixing-station-ui P04 | 20min | 1 tasks | 2 files |
| Phase 03-ai-denoising-pipeline P01 | 15min | 2 tasks | 5 files |
| Phase 03-ai-denoising-pipeline P02 | 22min | 3 tasks | 3 files |
| Phase 03-ai-denoising-pipeline P03 | 12min | 1 tasks | 2 files |
| Phase 03-ai-denoising-pipeline P04 | 8min | 1 tasks | 3 files |
| Phase 04-lufs-normalization-export-polish P01 | 4min | 3 tasks | 3 files |
| Phase 04-lufs-normalization-export-polish P02 | 24min | 3 tasks | 6 files |
| Phase 04-lufs-normalization-export-polish PP03 | 10min | 2 tasks | 6 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Research]: Use Core ML (not AVAudioEngine Voice Processing) for denoising — Voice Processing cannot process pre-recorded files, only live mic input.
- [Research]: Normalize all audio to a canonical sample rate at import time — AVMutableComposition silently corrupts mismatched-format compositions.
- [Research]: Share Extension must be a thin file relay only — 120 MB process memory ceiling; never process audio in the extension.
- [Research]: Phase 3 (Denoising) requires /gsd:research-phase before planning — Core ML model selection and coremltools pipeline not yet resolved.
- [Phase 01-foundation-import-pipeline]: Store fileURLRelativePath (filename only) in SwiftData — absolute App Group paths shift between device/simulator; reconstruct at runtime via AppConstants.clipsDirectory()
- [Phase 01-foundation-import-pipeline]: UTType.aac not available as static member on iOS SDK; use UTType('public.aac-audio')\! via identifier string
- [Phase 01-foundation-import-pipeline]: AVAudioSession launch failure is non-fatal — normalization via AVAssetWriter does not require active session; Phase 2 retries before first playback
- [Phase 01-01]: SonicMergeTests uses PBXFileSystemSynchronizedRootGroup for zero-configuration test file inclusion (Xcode 26.3+)
- [Phase 01-01]: iOS 26.2 ModelContainer uses variadic ModelConfiguration arguments — plan templates should use variadic not array form
- [Phase 01-01]: Fixtures generated via Python wave module + afconvert (not ffmpeg/Swift script) — these tools are reliably available on macOS
- [Phase 01-foundation-import-pipeline]: Guard FileManager.containerURL before ModelConfiguration(groupContainer:) — prevents assertion crash in test host when App Group entitlement is absent
- [Phase 01-foundation-import-pipeline]: AVAudioFormat on iOS 26.2 requires commonFormat:sampleRate:interleaved:channelLayout: signature — interleaved parameter is required before channelLayout
- [Phase 01-foundation-import-pipeline]: ImportViewModel stub added to app target in Plan 03 to allow test compilation; Plan 04 replaces with full implementation
- [Phase 01-foundation-import-pipeline]: ImportViewModel is @MainActor because ModelContext is main-actor-bound; actor hop to AudioNormalizationService is safe per RESEARCH.md Pitfall 4
- [Phase 01-foundation-import-pipeline]: ContentView.swift retained as EmptyView stub for Xcode target membership rather than deleted from project.pbxproj
- [Phase 01-foundation-import-pipeline]: Human-verified import pipeline on simulator 2026-03-10: clips import, normalize to 48kHz stereo AAC, list, and persist across relaunch confirmed
- [Phase 02-merge-pipeline-mixing-station-ui]: WaveformService actor: generate(audioURL:destinationURL:) writes exactly 50 Float peaks to sidecar file
- [Phase 02-merge-pipeline-mixing-station-ui]: AudioMergerService.export returns AsyncStream<Float> progress (0.0-1.0); ExportFormat enum: .m4a, .wav
- [Phase 02-merge-pipeline-mixing-station-ui]: Crossfade overlap fixed at 0.5s — tests assert 1.5s total for two 1s clips
- [Phase 02-merge-pipeline-mixing-station-ui]: MixingStationViewModel.fetchAll() is async to match test call sites (await vm.fetchAll())
- [Phase 02-merge-pipeline-mixing-station-ui]: ExportFormat kept as top-level enum (not AudioMergerService.ExportFormat) to match existing Plan 02-02 stub API
- [Phase 02-merge-pipeline-mixing-station-ui]: MixingStationView stub created in Plan 03 to enable app target compilation; Plan 05 replaces with full UI
- [Phase 02-merge-pipeline-mixing-station-ui]: ExportFormat kept as top-level enum matching stub API; clipsBaseURL injection for test fixture resolution; iOS 17 compatible exportAsynchronously; WAV via AVAssetReader+AVAssetWriter not AVAssetExportSession
- [Phase 03-ai-denoising-pipeline]: Used Swift Testing Issue.record() stubs (not XCTest XCTFail) to match project test framework — all existing SonicMergeTests files use import Testing
- [Phase 03-ai-denoising-pipeline]: RNN hidden states exported as explicit ct.TensorType I/O in conversion script — MLState requires iOS 18+, deployment target is iOS 17+
- [Phase 03-ai-denoising-pipeline]: DeepFilterNet3 uses batch STFT interface (feat_erb/feat_spec), NOT chunk-RNN — signal processing embedded in NoiseReductionService.swift
- [Phase 03-ai-denoising-pipeline]: vDSP.add() Swift overlay uses (a:b:)/(c:d:) labels not (a:scalar:) — RESEARCH.md Pattern 4 had incorrect labels
- [Phase 03-ai-denoising-pipeline]: CleaningLabViewModel uses dependency injection init(noiseReductionService:waveformService:) for testability — no ModelContext needed; mergedFileURL received from MixingStationViewModel at NavigationLink call site
- [Phase 03-ai-denoising-pipeline]: AudioMergerService.exportFile(inputURL:format:destinationURL:) added for CleaningLabView single-file export path — existing API is clips-based, single-file method wraps input in AVMutableComposition and reuses existing exportM4A/exportWAV methods
- [Phase 03-ai-denoising-pipeline]: CleaningLabView is a pure rendering layer over CleaningLabViewModel; navigateToCleaningLab() merges clips to temp .wav before pushing CleaningLabView, matching ViewModel's single mergedFileURL contract
- [Phase 04-lufs-normalization-export-polish]: Used BundleLocator private inner class (project pattern) over SonicMergeTestsMarker outer class — all existing test files use private inner class convention
- [Phase 04-lufs-normalization-export-polish]: Wave 0 fixture amplitude 0.063 (~-24 dBFS) sufficient for gain scalar tests: measurably below -16 LUFS target, exact LUFS not required
- [Phase 04-lufs-normalization-export-polish]: Manual BS.1770-3 K-weighting biquad cascade used for LUFS measurement — spfk-loudness package not in project
- [Phase 04-lufs-normalization-export-polish]: LUFS gain for multi-clip export uses first clip as proxy — exact two-pass measure deferred to v2
- [Phase 04-lufs-normalization-export-polish]: ExportProgressSheet.isNormalizing uses var with default false for backward compatibility at call sites not yet passing the parameter
- [Phase 04-lufs-normalization-export-polish]: ActivityViewController.completionWithItemsHandler wired to coordinator.onDismiss ensuring state reset fires on every share sheet dismissal path

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 3]: Core ML denoising model selection is unresolved (model identity, bundle size, inference latency on A13/A14). Run /gsd:research-phase before planning Phase 3.
- [Phase 4]: spfk-loudness minimum iOS version unverified from Package.swift. If above iOS 17, fall back to manual BS.1770 vDSP implementation.

## Session Continuity

Last session: 2026-03-19T15:23:22.615Z
Stopped at: Completed 04-03-PLAN.md
Resume file: None
