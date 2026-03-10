---
phase: 2
slug: merge-pipeline-mixing-station-ui
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-10
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`import Testing`) |
| **Config file** | None — PBXFileSystemSynchronizedRootGroup auto-includes all files in SonicMergeTests/ |
| **Quick run command** | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing SonicMergeTests 2>&1 \| xcpretty` |
| **Full suite command** | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 \| xcpretty` |
| **Estimated runtime** | ~60 seconds (integration tests export real audio) |

---

## Sampling Rate

- **After every task commit:** Run relevant test class (see Per-Task map below)
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-W0-01 | Wave0 | 0 | IMP-04 | unit stub | `-only-testing SonicMergeTests/WaveformServiceTests` | ❌ W0 | ⬜ pending |
| 02-W0-02 | Wave0 | 0 | MRG-01, MRG-02, EXP-04 | unit stub | `-only-testing SonicMergeTests/MixingStationViewModelTests` | ❌ W0 | ⬜ pending |
| 02-W0-03 | Wave0 | 0 | MRG-03, MRG-04, EXP-01, EXP-02 | unit/integration stub | `-only-testing SonicMergeTests/AudioMergerServiceTests` | ❌ W0 | ⬜ pending |
| 02-IMP04 | WaveformService | 1 | IMP-04 | unit | `-only-testing SonicMergeTests/WaveformServiceTests` | ❌ W0 | ⬜ pending |
| 02-MRG01 | MixingStationVM | 1 | MRG-01 | unit | `-only-testing SonicMergeTests/MixingStationViewModelTests` | ❌ W0 | ⬜ pending |
| 02-MRG02 | MixingStationVM | 1 | MRG-02 | unit | `-only-testing SonicMergeTests/MixingStationViewModelTests` | ❌ W0 | ⬜ pending |
| 02-MRG03 | AudioMerger | 2 | MRG-03 | unit | `-only-testing SonicMergeTests/AudioMergerServiceTests` | ❌ W0 | ⬜ pending |
| 02-MRG04 | AudioMerger | 2 | MRG-04 | unit | `-only-testing SonicMergeTests/AudioMergerServiceTests` | ❌ W0 | ⬜ pending |
| 02-EXP01 | AudioMerger | 2 | EXP-01 | integration | `-only-testing SonicMergeTests/AudioMergerServiceTests` | ❌ W0 | ⬜ pending |
| 02-EXP02 | AudioMerger | 2 | EXP-02 | integration | `-only-testing SonicMergeTests/AudioMergerServiceTests` | ❌ W0 | ⬜ pending |
| 02-EXP04 | MixingStationVM | 2 | EXP-04 | unit | `-only-testing SonicMergeTests/MixingStationViewModelTests` | ❌ W0 | ⬜ pending |
| 02-UX01 | MixingStationUI | 3 | UX-01 | unit | `-only-testing SonicMergeTests/ThemeTests` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `SonicMergeTests/WaveformServiceTests.swift` — stubs for IMP-04 (waveform generation, sidecar file)
- [ ] `SonicMergeTests/MixingStationViewModelTests.swift` — stubs for MRG-01 (reorder), MRG-02 (delete), EXP-04 (cancel)
- [ ] `SonicMergeTests/AudioMergerServiceTests.swift` — stubs for MRG-03 (gap), MRG-04 (crossfade), EXP-01 (.m4a export), EXP-02 (.wav export)
- [ ] `SonicMergeTests/ThemeTests.swift` — optional; verify theme constants match spec (low priority)
- [ ] Confirm `stereo_48000.m4a` fixture from Phase 1 is in test target bundle membership

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Drag-to-reorder visual feedback | MRG-01 | SwiftUI gesture, not headless-testable | Run on simulator: long-press clip, drag to new position, confirm order persists after relaunch |
| Share sheet presentation | EXP-01, EXP-02 | UIActivityViewController, not UI-testable in headless | Tap Export on simulator, verify share sheet appears with a valid audio file |
| Non-dismissible export modal | EXP-04 | Interactive dismiss behavior | Tap Export, attempt to swipe-dismiss modal during progress — confirm it stays |
| Crossfade audible in exported file | MRG-04 | Perceptual audio quality | Export two clips with Crossfade; listen to join point in Voice Memos or QuickTime |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
