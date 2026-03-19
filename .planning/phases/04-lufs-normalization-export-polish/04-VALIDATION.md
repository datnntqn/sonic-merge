---
phase: 4
slug: lufs-normalization-export-polish
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-19
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`import Testing` — all existing `SonicMergeTests` files) |
| **Config file** | None — PBXFileSystemSynchronizedRootGroup auto-includes files |
| **Quick run command** | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing SonicMergeTests/LUFSNormalizationServiceTests 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 \| tail -40` |
| **Estimated runtime** | ~60 seconds (full suite) |

---

## Sampling Rate

- **After every task commit:** Run `LUFSNormalizationServiceTests` and `MixingStationViewModelTests` only
- **After every plan wave:** Run full suite
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 4-W0-01 | W0 | 0 | EXP-03 | unit | `xcodebuild test ... -only-testing SonicMergeTests/LUFSNormalizationServiceTests/testGainScalarForKnownLoudness` | ❌ Wave 0 | ⬜ pending |
| 4-W0-02 | W0 | 0 | EXP-03 | unit | `xcodebuild test ... -only-testing SonicMergeTests/LUFSNormalizationServiceTests/testGainScalarAlreadyAtTarget` | ❌ Wave 0 | ⬜ pending |
| 4-W0-03 | W0 | 0 | EXP-03 | integration | `xcodebuild test ... -only-testing SonicMergeTests/LUFSNormalizationServiceTests/testExportWithLUFSEnabled` | ❌ Wave 0 | ⬜ pending |
| 4-W0-04 | W0 | 0 | EXP-03 | unit | `xcodebuild test ... -only-testing SonicMergeTests/MixingStationViewModelTests/testExportOptionsLUFSFlag` | ❌ Wave 0 | ⬜ pending |
| 4-W0-05 | W0 | 0 | Share reset | unit | `xcodebuild test ... -only-testing SonicMergeTests/MixingStationViewModelTests/testDismissShareSheetResetsState` | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `SonicMergeTests/LUFSNormalizationServiceTests.swift` — stubs for EXP-03 gain scalar logic (testGainScalarForKnownLoudness, testGainScalarAlreadyAtTarget, testExportWithLUFSEnabled)
- [ ] `SonicMergeTests/Fixtures/stereo_-24lufs_48000.wav` — test fixture at known loudness level for deterministic gain scalar assertion
- [ ] New test methods in `SonicMergeTests/MixingStationViewModelTests.swift` — testExportOptionsLUFSFlag, testDismissShareSheetResetsState

*Note: Existing `MixingStationViewModelTests.swift` file will receive new test methods — no new file needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Exported file measures -16 LUFS in external tool | EXP-03 | Requires external LUFS analyzer (e.g., Auphonic, Reaper) outside iOS | Export audio with LUFS toggle ON; analyze result in external tool; confirm integrated LUFS is -16 ± 1 |
| Share sheet auto-presents immediately after export | EXP-03 (UX) | UI presentation timing requires device/simulator observation | Export with LUFS enabled; confirm share sheet appears without extra tap |
| Progress title shows "Exporting & Normalizing..." | EXP-03 (UX) | Text rendering requires visual observation | Toggle LUFS on; start export; observe ExportProgressSheet title label |
| After share dismiss, state fully resets | EXP-03 (UX) | Requires share sheet interaction on device | Share file; dismiss sheet; confirm exportProgress = 0 and UI returns to ready state |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
