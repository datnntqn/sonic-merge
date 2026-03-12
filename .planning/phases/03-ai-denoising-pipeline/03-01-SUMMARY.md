---
phase: 03-ai-denoising-pipeline
plan: 01
subsystem: testing
tags: [xctest, swift-testing, core-ml, deepfilternet3, coremltools, tdd, denoising]

# Dependency graph
requires:
  - phase: 02-merge-pipeline-mixing-station-ui
    provides: AudioMergerService, WaveformService, ExportFormatSheet patterns reused by Phase 3
provides:
  - Failing test stubs for DNS-01 (NoiseReductionService), DNS-02 (WetDryBlendTests), DNS-03 (ABPlaybackTests)
  - DeepFilterNet3 coremltools conversion script (scripts/convert_deepfilternet3.py)
  - Developer setup guide (docs/DENOISING_SETUP.md)
affects: [03-ai-denoising-pipeline]

# Tech tracking
tech-stack:
  added: [deepfilternet, coremltools, FLOAT16 precision, iOS17 minimum deployment target]
  patterns: [Swift Testing Issue.record() for red-state stubs, explicit RNN state I/O (not MLState)]

key-files:
  created:
    - SonicMergeTests/NoiseReductionServiceTests.swift
    - SonicMergeTests/WetDryBlendTests.swift
    - SonicMergeTests/ABPlaybackTests.swift
    - scripts/convert_deepfilternet3.py
    - docs/DENOISING_SETUP.md
  modified: []

key-decisions:
  - "Used Swift Testing Issue.record() stubs (not XCTest XCTFail) to match project test framework — all existing tests use import Testing"
  - "RNN hidden states exported as explicit ct.TensorType I/O in conversion script — MLState requires iOS 18+, deployment target is iOS 17+"
  - "FLOAT16 precision in conversion script targets ~4.2 MB bundle size vs ~8.4 MB FLOAT32"

patterns-established:
  - "Wave 0 stub pattern: Issue.record() in @Test func to guarantee RED state before implementation"
  - "WetDryBlendTests is self-contained (no model/file deps) — pure math tests remain fast and dependency-free"

requirements-completed: [DNS-01, DNS-02, DNS-03]

# Metrics
duration: 15min
completed: 2026-03-12
---

# Phase 3 Plan 01: AI Denoising Pipeline Wave 0 Summary

**Seven failing test stubs for DNS-01/02/03 + coremltools conversion script with iOS 17 explicit RNN state I/O + developer setup guide for DeepFilterNet3 .mlpackage prerequisite**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-12T15:36:12Z
- **Completed:** 2026-03-12T15:51:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Three failing test stub files covering all DNS-01, DNS-02, DNS-03 behaviors (7 test methods total)
- All stubs use Swift Testing `Issue.record()` to guarantee RED state before any implementation
- coremltools conversion script with `minimum_deployment_target=iOS17`, FLOAT16 precision, and explicit RNN tensor I/O (not MLState)
- Developer prerequisite guide with 5-step setup including tensor name inspection step

## Task Commits

Each task was committed atomically:

1. **Task 1: Create failing test stubs** - `a592f6d` (test)
2. **Task 2: Write coremltools conversion script and developer setup guide** - `908febf` (chore)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified
- `SonicMergeTests/NoiseReductionServiceTests.swift` - 3 failing stubs for DNS-01 (denoised file created, output format valid, progress monotonically increasing)
- `SonicMergeTests/WetDryBlendTests.swift` - 3 failing stubs for DNS-02 (zero intensity, full intensity, half intensity linear mid)
- `SonicMergeTests/ABPlaybackTests.swift` - 1 failing stub for DNS-03 (position preserved on A/B switch)
- `scripts/convert_deepfilternet3.py` - One-time developer conversion tool for DeepFilterNet3 → Core ML
- `docs/DENOISING_SETUP.md` - 5-step developer prerequisite guide

## Decisions Made
- Used Swift Testing `Issue.record()` stubs instead of XCTest `XCTFail` — the project consistently uses `import Testing` not `import XCTest`; all existing SonicMergeTests files follow this pattern
- `minimum_deployment_target=ct.target.iOS17` in conversion script prevents MLState generation (MLState is iOS 18+ only)
- FLOAT16 precision targets ~4.2 MB bundle size; script warns if output exceeds 10 MB

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Used Swift Testing framework instead of specified XCTest**
- **Found during:** Task 1 (creating test stubs)
- **Issue:** Plan specified `import XCTest` and `XCTFail()` but every existing test file in the project uses `import Testing` and `@Test` / `#expect` / `Issue.record()` (Swift Testing). Using XCTest would create an inconsistency.
- **Fix:** Used Swift Testing `Issue.record("not implemented — ...")` in `@Test` functions — semantically equivalent (guaranteed failure) and consistent with the project pattern.
- **Files modified:** All 3 new test files
- **Verification:** `xcodebuild build-for-testing` returns TEST BUILD SUCCEEDED
- **Committed in:** `a592f6d` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — framework consistency)
**Impact on plan:** Necessary for project consistency. Behavior is identical (tests are RED). No scope creep.

## Issues Encountered
- `xcodebuild build-for-testing -destination 'platform=iOS Simulator,name=iPhone 16'` failed — iPhone 16 simulator not available on this machine. Used `iPhone 17` instead (iOS 26.2). Build succeeded.

## User Setup Required

**Developer must complete before executing Plan 03-02 (Wave 1):**
1. `pip install coremltools deepfilternet torch`
2. `python scripts/convert_deepfilternet3.py`
3. Add `SonicMerge/Resources/DeepFilterNet3.mlpackage` to both `SonicMerge` and `SonicMergeTests` Xcode targets
4. Open auto-generated `DeepFilterNet3.swift` and note exact tensor property names
5. Update `NoiseReductionService.swift` (Wave 1) with those exact names

See `docs/DENOISING_SETUP.md` for complete instructions.

## Next Phase Readiness
- Wave 0 complete: all 7 test stubs exist and build
- Wave 1 (Plan 03-02) is blocked until developer completes DeepFilterNet3 .mlpackage conversion and Xcode project setup
- WetDryBlendTests (DNS-02) has no external dependencies — can turn green in Wave 2 independently of model availability

## Self-Check: PASSED

---
*Phase: 03-ai-denoising-pipeline*
*Completed: 2026-03-12*
