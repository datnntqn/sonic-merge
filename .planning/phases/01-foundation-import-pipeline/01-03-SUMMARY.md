---
phase: 01-foundation-import-pipeline
plan: 03
subsystem: audio-processing
tags: [avfoundation, avfaudio, swift, ios, pcm, aac, avastereader, avassetwriter, avconverter]

# Dependency graph
requires:
  - phase: 01-01
    provides: AudioNormalizationServiceTests stubs (RED state), audio fixtures (mono_44100.wav, stereo_48000.m4a, aac_22050.aac)
  - phase: 01-02
    provides: AudioClip @Model, AppConstants (clipsDirectory), AppGroupError
provides:
  - AudioNormalizationService actor: normalize(sourceURL:destinationURL:) transcodes any audio to 48kHz/stereo/AAC .m4a
  - NormalizationError enum (noAudioTrack, writeFailed, monoUpmixFailed)
  - ImportViewModel stub (placeholder for Plan 04 — enables test compilation)
  - SonicMergeApp.modelContainer with App Group URL guard (no assertion crash in test host)
affects: [01-04-import-pipeline, 02-mixing-station-ui]

# Tech tracking
tech-stack:
  added: [AVAssetReader, AVAssetReaderTrackOutput, AVAssetWriter, AVAssetWriterInput, AVAudioConverter, CMBlockBuffer, CMAudioFormatDescription]
  patterns: [linear-pcm-decompress-then-reencode, actor-confinement-avfoundation, mono-upmix-channelmap, app-group-url-guard-pattern]

key-files:
  created:
    - SonicMerge/Services/AudioNormalizationService.swift
    - SonicMerge/ViewModels/ImportViewModel.swift
  modified:
    - SonicMerge/SonicMergeApp.swift

key-decisions:
  - "Check FileManager.containerURL(forSecurityApplicationGroupIdentifier:) != nil before creating ModelConfiguration(groupContainer:) to avoid internal assertion crash in test host process"
  - "AVAudioFormat init on iOS 26.2 requires commonFormat:sampleRate:interleaved:channelLayout: signature (not commonFormat:sampleRate:channels:interleaved: or commonFormat:sampleRate:channelLayout:)"
  - "ImportViewModel stub added to app target so ImportViewModelTests.swift compiles; Plan 04 replaces with full implementation"
  - "All AVFoundation objects (AVAssetReader, AVAssetWriter, AVAudioConverter) created and destroyed inside the actor method — no stored properties crossing actor boundaries (Swift 6 Sendable compliance)"

patterns-established:
  - "App Group URL guard: check FileManager.containerURL before creating ModelConfiguration with groupContainer — prevents SwiftData assertion crash when entitlement is absent"
  - "Linear PCM decompress-then-reencode: AVAssetReader outputs kAudioFormatLinearPCM; AVAssetWriter encodes to kAudioFormatMPEG4AAC — prevents AVErrorInvalidSourceMedia"
  - "Mono upmix via channelMap: AVAudioConverter.channelMap = [0, 0] routes mono source channel to both L and R output channels"
  - "Actor-confined AVFoundation: all AVFoundation objects are local to the actor method; nothing stored as actor properties, avoiding Swift 6 Sendable violations"

requirements-completed: [IMP-03]

# Metrics
duration: 21min
completed: 2026-03-08
---

# Phase 1 Plan 03: AudioNormalizationService Summary

**AVAssetReader (Linear PCM decompression) + AVAssetWriter (48kHz/stereo/AAC encoding) Swift actor with AVAudioConverter mono upmix via channelMap=[0,0], making all 4 AudioNormalizationServiceTests GREEN**

## Performance

- **Duration:** 21 min
- **Started:** 2026-03-08T14:41:16Z
- **Completed:** 2026-03-08T15:02:30Z
- **Tasks:** 1 (TDD: RED confirmed, GREEN implemented and verified)
- **Files modified:** 3

## Accomplishments
- AudioNormalizationService actor transcodes any AVFoundation-readable audio to 48kHz/stereo/AAC .m4a in a single normalize(sourceURL:destinationURL:) call
- Mono upmix correctly duplicates the mono channel to both L and R output channels via AVAudioConverter channelMap=[0,0] — testMonoUpmix passes
- All 4 AudioNormalizationServiceTests pass: testOutputSampleRate, testOutputChannelCount, testMonoUpmix, testDurationPreserved
- Fixed SonicMergeApp.modelContainer to guard App Group URL resolution before creating ModelConfiguration — eliminates assertion crash in test host process across all test files
- Added ImportViewModel stub so ImportViewModelTests.swift compiles while Plan 04 is pending

## Task Commits

Each task was committed atomically:

1. **TDD GREEN: AudioNormalizationService implementation** - `aebf6ae` (feat)

_Note: RED state was confirmed by running xcodebuild which produced "Cannot find 'AudioNormalizationService' in scope" before implementation._

## Files Created/Modified
- `SonicMerge/Services/AudioNormalizationService.swift` - Actor with normalize(), upmixMonoBuffer(), NormalizationError enum, and CMBlockBuffer extension
- `SonicMerge/ViewModels/ImportViewModel.swift` - Minimal stub (Plan 04 placeholder) — enables ImportViewModelTests.swift compilation
- `SonicMerge/SonicMergeApp.swift` - Fixed modelContainer: guard App Group URL availability before ModelConfiguration to prevent test host crash

## Decisions Made
- **AVAudioFormat API on iOS 26.2:** `AVAudioFormat(commonFormat:sampleRate:channelLayout:)` requires `interleaved:` parameter before `channelLayout:`. Correct signature: `AVAudioFormat(commonFormat:sampleRate:interleaved:channelLayout:)`. The plan's code template omitted the interleaved label.
- **App Group URL guard:** `ModelConfiguration(schema:groupContainer:)` triggers `_assertionFailure` internally on iOS 26.2 when the App Group entitlement is absent (test host process). The fix is to call `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)` first and only create the App Group ModelConfiguration when the URL resolves.
- **ImportViewModel stub:** `ImportViewModelTests.swift` references `ImportViewModel` which doesn't exist until Plan 04. Added a minimal stub to the main app target so the test file compiles and AudioNormalizationServiceTests can execute. Plan 04 replaces the stub with the full implementation.
- **Mono upmix implementation:** The plan's code correctly uses AVAudioConverter with channelMap=[0,0] for per-buffer conversion. The CMSampleBuffer → AVAudioPCMBuffer → upmix → CMSampleBuffer pipeline works correctly in practice.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] AVAudioFormat init missing interleaved parameter**
- **Found during:** TDD GREEN (implementing AudioNormalizationService)
- **Issue:** `AVAudioFormat(commonFormat:sampleRate:channelLayout:)` fails compilation with "missing argument for parameter 'interleaved' in call" on iOS 26.2 SDK
- **Fix:** Updated both srcFormat and dstFormat AVAudioFormat inits to use `commonFormat:sampleRate:interleaved:channelLayout:` signature; also used AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Mono) for srcFormat to be explicit
- **Files modified:** SonicMerge/Services/AudioNormalizationService.swift
- **Verification:** Build succeeded; all 4 tests pass
- **Committed in:** aebf6ae (task commit)

**2. [Rule 3 - Blocking] SonicMergeApp.modelContainer crashed test host with assertion**
- **Found during:** TDD GREEN (running AudioNormalizationServiceTests)
- **Issue:** `ModelConfiguration(schema:groupContainer:)` triggers internal `_assertionFailure` in the test host process when App Group entitlement is absent. This crashed the entire test runner before any tests could run.
- **Fix:** Added `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:) != nil` guard. App Group ModelConfiguration is only created when the URL resolves; otherwise falls back to the default sandbox container.
- **Files modified:** SonicMerge/SonicMergeApp.swift
- **Verification:** PersistenceTests and AudioNormalizationServiceTests both launch and execute correctly
- **Committed in:** aebf6ae (task commit)

**3. [Rule 3 - Blocking] ImportViewModelTests.swift prevented test target compilation**
- **Found during:** TDD GREEN (running AudioNormalizationServiceTests)
- **Issue:** `ImportViewModelTests.swift` references `ImportViewModel` which doesn't exist yet (Plan 04 deliverable). This caused a compile error that blocked the entire SonicMergeTests target — all tests including AudioNormalizationServiceTests couldn't run.
- **Fix:** Added minimal `ImportViewModel` stub to `SonicMerge/ViewModels/ImportViewModel.swift` with the `ObservableObject` + `@Published var clips: [AudioClip]` + `importFiles(from:)` stub. Plan 04 replaces this with the full implementation.
- **Files modified:** SonicMerge/ViewModels/ImportViewModel.swift (new file)
- **Verification:** SonicMergeTests target compiles; all 4 AudioNormalizationServiceTests pass
- **Committed in:** aebf6ae (task commit)

---

**Total deviations:** 3 auto-fixed (1 Rule 1 bug, 2 Rule 3 blocking)
**Impact on plan:** All auto-fixes required for compilation and test execution. The AVAudioFormat fix corrects an SDK API difference from the plan template. The ModelContainer and ImportViewModel fixes address pre-existing issues exposed by attempting to run the tests. No scope creep.

## Issues Encountered
- iOS 26.2 SDK changed `AVAudioFormat` init signature to require explicit `interleaved:` parameter before `channelLayout:` — plan template omitted this label
- `ModelConfiguration(schema:groupContainer:)` is not safe to call without first verifying the App Group container URL resolves — triggers assertion failure in SDK if entitlement is absent
- The `ImportViewModelTests.swift` stub from Plan 01 was always intended to be RED until Plan 04 but caused a compile error preventing all tests from running

## User Setup Required
None — test infrastructure fix is automatic (URL guard + stub). No manual configuration needed.

## Next Phase Readiness
- AudioNormalizationService is production-ready and fully tested — Plan 04 (ImportViewModel) can call it directly
- ImportViewModel stub is in place; Plan 04 replaces the stub with the full multi-file import pipeline
- All 4 AudioNormalizationServiceTests are GREEN and will serve as regression tests
- SonicMergeApp.modelContainer now runs correctly in both app and test host contexts

**Blockers:**
- App Group entitlement not yet added — required before device testing (covered by Plan 04's human-verify checkpoint)

## Self-Check: PASSED

| Item | Status |
|------|--------|
| SonicMerge/Services/AudioNormalizationService.swift | FOUND |
| SonicMerge/ViewModels/ImportViewModel.swift | FOUND |
| SonicMerge/SonicMergeApp.swift (modified) | FOUND |
| .planning/phases/01-foundation-import-pipeline/01-03-SUMMARY.md | FOUND |
| Commit aebf6ae (TDD GREEN: AudioNormalizationService) | FOUND |
| testOutputSampleRate | PASSED |
| testOutputChannelCount | PASSED |
| testMonoUpmix | PASSED |
| testDurationPreserved | PASSED |
| xcodebuild TEST SUCCEEDED | VERIFIED |

---
*Phase: 01-foundation-import-pipeline*
*Completed: 2026-03-08*
