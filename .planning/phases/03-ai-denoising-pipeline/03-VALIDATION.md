---
phase: 3
slug: ai-denoising-pipeline
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-12
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode built-in, iOS 17+) |
| **Config file** | SonicMergeTests target (PBXFileSystemSynchronizedRootGroup — auto-includes all files in Tests/) |
| **Quick run command** | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SonicMergeTests/NoiseReductionServiceTests` |
| **Full suite command** | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Estimated runtime** | ~60 seconds (full suite); ~15 seconds (quick NoiseReductionServiceTests only) |

---

## Sampling Rate

- **After every task commit:** Run quick command targeting the new test file for that task
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 0 | DNS-01 | unit | `xcodebuild test ... -only-testing:SonicMergeTests/NoiseReductionServiceTests/testDenoisedFileCreated` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 0 | DNS-01 | unit | `xcodebuild test ... -only-testing:SonicMergeTests/NoiseReductionServiceTests/testOutputFormatIsValid` | ❌ W0 | ⬜ pending |
| 03-01-03 | 01 | 0 | DNS-01 | unit | `xcodebuild test ... -only-testing:SonicMergeTests/NoiseReductionServiceTests/testProgressMonotonicallyIncreases` | ❌ W0 | ⬜ pending |
| 03-01-04 | 01 | 0 | DNS-02 | unit | `xcodebuild test ... -only-testing:SonicMergeTests/WetDryBlendTests/testZeroIntensityReturnsOriginal` | ❌ W0 | ⬜ pending |
| 03-01-05 | 01 | 0 | DNS-02 | unit | `xcodebuild test ... -only-testing:SonicMergeTests/WetDryBlendTests/testFullIntensityReturnsDenoised` | ❌ W0 | ⬜ pending |
| 03-01-06 | 01 | 0 | DNS-02 | unit | `xcodebuild test ... -only-testing:SonicMergeTests/WetDryBlendTests/testHalfIntensityIsLinearMid` | ❌ W0 | ⬜ pending |
| 03-01-07 | 01 | 0 | DNS-03 | unit | `xcodebuild test ... -only-testing:SonicMergeTests/ABPlaybackTests/testPositionPreservedOnSwitch` | ❌ W0 | ⬜ pending |
| 03-04-01 | 04 | 4 | UX-02 | manual | — | Manual | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `SonicMergeTests/NoiseReductionServiceTests.swift` — failing stubs for DNS-01 tests (requires bundled .mlpackage in test target)
- [ ] `SonicMergeTests/WetDryBlendTests.swift` — failing stubs for DNS-02 tests (pure unit tests, no model needed)
- [ ] `SonicMergeTests/ABPlaybackTests.swift` — failing stubs for DNS-03 tests (mock AVAudioPlayer or subclass)
- [ ] `DeepFilterNet3.mlpackage` — developer must convert and commit before any DNS-01 test can run; conversion script provided in Wave 0 plan
- [ ] Developer prerequisite: run `pip install coremltools deepfilternet` and execute provided conversion script offline before executing Wave 1+

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Haptic fires on holdEnded | UX-02 | UIImpactFeedbackGenerator not detectable in XCTest; simulator may not have haptic hardware | On physical device: hold "Listen Original" button → release → verify tactile medium-weight tap sensation |
| A/B switch is seamless (no audible gap) | DNS-03 | No XCTest API for subjective audio gap measurement | On device/simulator with audio: hold and release "Listen Original" several times; confirm no audible delay/pop between players |
| Slider blends audio in real-time | DNS-02 | Subjective audio quality assessment | Open CleaningLabView → process audio → drag slider while playing → confirm audible transition between original and denoised |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
