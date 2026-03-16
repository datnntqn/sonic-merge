---
phase: 01-foundation-import-pipeline
plan: 01
subsystem: testing
tags: [swift-testing, xcode, avfoundation, swiftdata, fixtures]

requires: []
provides:
  - SonicMergeTests unit test target (host-process bundle linked to SonicMerge.app)
  - Three audio fixture files in SonicMergeTests/Fixtures/ (mono WAV, stereo M4A, AAC)
  - Failing @Test stubs defining contracts for AudioNormalizationService (Plan 03) and ImportViewModel (Plan 02)
  - PersistenceTests passing stub for AudioClip SwiftData round-trip
  - AppGroupTests disabled stub for App Group container (manual verification required)
affects:
  - 01-02 (ImportViewModel implementation must satisfy ImportViewModelTests contract)
  - 01-03 (AudioNormalizationService must satisfy AudioNormalizationServiceTests contract)

tech-stack:
  added:
    - Swift Testing framework (Xcode native, @Test macros)
    - afconvert (macOS built-in audio converter, used to generate fixtures)
  patterns:
    - Test target uses PBXFileSystemSynchronizedRootGroup for zero-configuration file inclusion
    - Audio fixtures excluded from Sources via PBXFileSystemSynchronizedBuildFileExceptionSet, included in Copy Bundle Resources via explicit PBXBuildFile entries
    - Bundle(for: BundleLocator.self) pattern for fixture URL resolution in Swift Testing structs

key-files:
  created:
    - SonicMergeTests/AudioNormalizationServiceTests.swift
    - SonicMergeTests/ImportViewModelTests.swift
    - SonicMergeTests/PersistenceTests.swift
    - SonicMergeTests/AppGroupTests.swift
    - SonicMergeTests/Fixtures/mono_44100.wav
    - SonicMergeTests/Fixtures/stereo_48000.m4a
    - SonicMergeTests/Fixtures/aac_22050.aac
    - SonicMergeTests/Fixtures/GenerateFixtures.swift
  modified:
    - SonicMerge.xcodeproj/project.pbxproj

key-decisions:
  - "SonicMergeTests target uses PBXFileSystemSynchronizedRootGroup so new test files are auto-included without pbxproj edits"
  - "Audio fixtures generated with Python + afconvert (ffmpeg not available) — mono_44100.wav via Python wave module, M4A/AAC via afconvert from WAV source"
  - "ModelContainer API in iOS 26.2 uses variadic ModelConfiguration arguments (not array) — corrected from plan template"
  - "Foundation import required explicitly in PersistenceTests and ImportViewModelTests for FileManager, URL, UUID"

patterns-established:
  - "Test RED state: tests fail to compile when referenced types don't exist yet — intentional contract-first TDD"
  - "Bundle(for: BundleLocator.self) for fixture resolution: use a private class BundleLocator as Bundle(for:) anchor"

requirements-completed:
  - IMP-01
  - IMP-03

duration: 35min
completed: 2026-03-08
---

# Phase 1 Plan 01: Test Infrastructure Setup Summary

**SonicMergeTests target with Swift Testing framework, three 1-second audio fixtures (44.1kHz WAV / 48kHz M4A / 22.05kHz AAC), and four failing @Test stub files defining the Plan 02/03 implementation contracts**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-03-08T14:00:00Z
- **Completed:** 2026-03-08T14:37:00Z
- **Tasks:** 2 of 2
- **Files modified:** 9

## Accomplishments
- SonicMergeTests target added to project.pbxproj with `PBXFileSystemSynchronizedRootGroup` — future test files auto-appear in the target
- Three audio fixtures generated (mono WAV, stereo M4A, AAC) and wired to Copy Bundle Resources build phase
- Four test stub files establish the contracts Plans 02 and 03 must fulfill; AudioNormalizationServiceTests and ImportViewModelTests are correctly RED (compile error) until those plans deliver their types

## Task Commits

1. **Task 1: Add SonicMergeTests target and create audio fixture files** - `b00c63b` (chore)
2. **Task 2: Write failing test stubs for all Phase 1 behaviors** - `b8a65cc` (test)

## Files Created/Modified
- `SonicMerge.xcodeproj/project.pbxproj` - Added SonicMergeTests native target, build phases, configurations, Fixtures group, and target dependency
- `SonicMergeTests/AudioNormalizationServiceTests.swift` - 4 @Test stubs: sample rate, channel count, mono upmix, duration; RED until Plan 03
- `SonicMergeTests/ImportViewModelTests.swift` - 2 @Test stubs: import files, security scoped access; RED until Plan 02
- `SonicMergeTests/PersistenceTests.swift` - AudioClip SwiftData round-trip with in-memory store; passes
- `SonicMergeTests/AppGroupTests.swift` - Container URL test; disabled (App Group entitlement not in test sandbox)
- `SonicMergeTests/Fixtures/mono_44100.wav` - 1s 44,100 Hz mono 16-bit PCM WAV (88 KB)
- `SonicMergeTests/Fixtures/stereo_48000.m4a` - 1s 48,000 Hz stereo AAC M4A (8.9 KB)
- `SonicMergeTests/Fixtures/aac_22050.aac` - 1s 22,050 Hz mono AAC ADTS (2.2 KB)
- `SonicMergeTests/Fixtures/GenerateFixtures.swift` - One-time fixture generator utility (not in target)

## Decisions Made
- Used `PBXFileSystemSynchronizedRootGroup` for the test target — Xcode 26.3+ auto-includes all files in the directory without requiring pbxproj edits per file
- Audio fixtures generated via Python `wave` module (WAV) + macOS `afconvert` (M4A/AAC) because ffmpeg was not available; `GenerateFixtures.swift` kept as documentation but not used
- The iOS 26.2 SDK uses variadic `ModelConfiguration` arguments in `ModelContainer(for:configurations:)` — the plan template used array syntax; corrected to variadic form

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed ModelContainer API call to use variadic rather than array**
- **Found during:** Task 2 (Write failing test stubs)
- **Issue:** `ModelContainer(for: AudioClip.self, configurations: [config])` fails with "cannot pass array of type '[ModelConfiguration]' as variadic arguments" in iOS 26.2 SDK
- **Fix:** Changed to `ModelContainer(for: AudioClip.self, configurations: config)` (variadic form) in both PersistenceTests.swift and ImportViewModelTests.swift
- **Files modified:** SonicMergeTests/PersistenceTests.swift, SonicMergeTests/ImportViewModelTests.swift
- **Verification:** Build-for-testing shows only intended RED errors (missing AudioNormalizationService, ImportViewModel)
- **Committed in:** b8a65cc (Task 2 commit)

**2. [Rule 1 - Bug] Added Foundation import to PersistenceTests and ImportViewModelTests**
- **Found during:** Task 2 (Write failing test stubs)
- **Issue:** `URL`, `FileManager`, `UUID` not in scope because Foundation was not imported
- **Fix:** Added `import Foundation` to both files
- **Files modified:** SonicMergeTests/PersistenceTests.swift, SonicMergeTests/ImportViewModelTests.swift
- **Verification:** Build-for-testing shows only intended RED errors
- **Committed in:** b8a65cc (Task 2 commit)

**3. [Rule 3 - Blocking] Used Python+afconvert instead of ffmpeg for fixture generation**
- **Found during:** Task 1 (Create audio fixture files)
- **Issue:** ffmpeg not installed; GenerateFixtures.swift crashed in Swift script context (AVAssetExportSession fails outside app sandbox in interpreted mode)
- **Fix:** Generated WAV files via Python `wave` module, converted M4A/AAC with macOS built-in `afconvert`; kept GenerateFixtures.swift as documentation
- **Files modified:** SonicMergeTests/Fixtures/GenerateFixtures.swift (updated), audio fixture files created
- **Verification:** Three fixture files exist with correct sizes and formats
- **Committed in:** b00c63b (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (2 Rule 1 bugs, 1 Rule 3 blocking)
**Impact on plan:** All auto-fixes corrected framework API changes and missing imports. No scope creep.

## Issues Encountered
- visionOS 26.2 simulator not installed, causing xcodebuild scheme-level builds to fail. Worked around by overriding `SUPPORTED_PLATFORMS="iphoneos iphonesimulator"` for verification builds.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- SonicMergeTests target is ready to receive implementations from Plans 02 and 03
- Plan 02 (ImportViewModel + AudioClip) will make ImportViewModelTests GREEN
- Plan 03 (AudioNormalizationService) will make AudioNormalizationServiceTests GREEN
- PersistenceTests already GREEN (AudioClip model was pre-built)
- AppGroupTests intentionally disabled pending real-device entitlement setup

---
*Phase: 01-foundation-import-pipeline*
*Completed: 2026-03-08*

## Self-Check: PASSED

- FOUND: SonicMergeTests/AudioNormalizationServiceTests.swift
- FOUND: SonicMergeTests/ImportViewModelTests.swift
- FOUND: SonicMergeTests/PersistenceTests.swift
- FOUND: SonicMergeTests/AppGroupTests.swift
- FOUND: SonicMergeTests/Fixtures/mono_44100.wav
- FOUND: SonicMergeTests/Fixtures/stereo_48000.m4a
- FOUND: SonicMergeTests/Fixtures/aac_22050.aac
- FOUND commit b00c63b (Task 1: SonicMergeTests target + fixtures)
- FOUND commit b8a65cc (Task 2: failing test stubs)
