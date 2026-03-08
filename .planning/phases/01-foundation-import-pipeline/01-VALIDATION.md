---
phase: 1
slug: foundation-import-pipeline
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-08
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (bundled with Xcode 16, Swift 6 target) |
| **Config file** | None required — Xcode detects `@Test` annotations automatically |
| **Quick run command** | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing SonicMergeTests/AudioNormalizationServiceTests` |
| **Full suite command** | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing SonicMergeTests` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing SonicMergeTests/AudioNormalizationServiceTests`
- **After every plan wave:** Run `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing SonicMergeTests`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 0 | IMP-01 | Unit | `xcodebuild test ... -only-testing SonicMergeTests/ImportViewModelTests` | ❌ W0 | ⬜ pending |
| 1-01-02 | 01 | 0 | IMP-03 | Unit | `xcodebuild test ... -only-testing SonicMergeTests/AudioNormalizationServiceTests/testOutputSampleRate` | ❌ W0 | ⬜ pending |
| 1-01-03 | 01 | 0 | IMP-03 | Unit | `xcodebuild test ... -only-testing SonicMergeTests/AudioNormalizationServiceTests/testOutputChannelCount` | ❌ W0 | ⬜ pending |
| 1-01-04 | 01 | 0 | IMP-03 | Unit | `xcodebuild test ... -only-testing SonicMergeTests/AudioNormalizationServiceTests/testMonoUpmix` | ❌ W0 | ⬜ pending |
| 1-01-05 | 01 | 0 | IMP-03 | Unit | `xcodebuild test ... -only-testing SonicMergeTests/AudioNormalizationServiceTests/testDurationPreserved` | ❌ W0 | ⬜ pending |
| 1-01-06 | 01 | 0 | IMP-03 | Integration | `xcodebuild test ... -only-testing SonicMergeTests/PersistenceTests/testClipSurvivesRelaunch` | ❌ W0 | ⬜ pending |
| 1-01-07 | 01 | 0 | SC | Unit | `xcodebuild test ... -only-testing SonicMergeTests/AppGroupTests/testContainerURLNotNil` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `SonicMergeTests/` target — does not exist; must be added in Xcode (New Target > Unit Testing Bundle, Swift Testing)
- [ ] `SonicMergeTests/AudioNormalizationServiceTests.swift` — stubs for IMP-03 (sample rate, channel count, mono upmix, duration)
- [ ] `SonicMergeTests/ImportViewModelTests.swift` — stubs for IMP-01 (URL handling, security-scoped access)
- [ ] `SonicMergeTests/PersistenceTests.swift` — stubs for SwiftData round-trip with in-memory store
- [ ] `SonicMergeTests/AppGroupTests.swift` — stubs for App Group container URL resolution
- [ ] `SonicMergeTests/Fixtures/` — `mono_44100.wav`, `stereo_48000.m4a`, `aac_22050.aac` (1–2 second audio fixtures for fast CI)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| System document picker opens with audio file types filtered | IMP-01 | Requires live device/simulator UI interaction; UITest fragile for system sheets | Tap Import button → verify Files app opens showing only .m4a, .wav, .aac files |
| App Group container accessible in future Share Extension target | SC-4 | Requires both targets provisioned; Share Extension is Phase 5 | After Phase 5: verify Share Extension can read files from group container |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
