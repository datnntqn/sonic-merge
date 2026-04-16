---
phase: 8
slug: cleaning-lab-ai-orb
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`import Testing`) |
| **Config file** | PBXFileSystemSynchronizedRootGroup — zero config |
| **Quick run command** | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SonicMergeTests/PillButtonStyleTintTests 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 \| tail -30` |
| **Estimated runtime** | ~45 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5`
- **After every plan wave:** Run `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 45 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 0 | CL-02/CL-03 | unit | `xcodebuild test -only-testing:SonicMergeTests/PillButtonStyleTintTests` | ❌ W0 | ⬜ pending |
| 08-01-02 | 01 | 0 | CL-02/CL-03 | unit | `xcodebuild test -only-testing:SonicMergeTests/LimeGreenSliderTests` | ❌ W0 | ⬜ pending |
| 08-01-03 | 01 | 0 | CL-01 | unit | `xcodebuild test -only-testing:SonicMergeTests/AIOrbViewTests` | ❌ W0 | ⬜ pending |
| 08-xx-xx | xx | x | CL-01 | unit | Assert progress ring trim matches viewModel.progress | ❌ W0 | ⬜ pending |
| 08-xx-xx | xx | x | CL-02 | manual | Visual: intensity % uses accentAI dark / accentAction light | manual-only | ⬜ pending |
| 08-xx-xx | xx | x | CL-03 | unit | `grep -c 'Color(red:' CleaningLabView.swift` → 0 | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `SonicMergeTests/PillButtonStyleTintTests.swift` — covers CL-02/CL-03: Tint enum cases, labelColor branches, backward-compat default
- [ ] `SonicMergeTests/LimeGreenSliderTests.swift` — covers CL-02/CL-03: value binding clamp, onEditingChanged callbacks
- [ ] `SonicMergeTests/AIOrbViewTests.swift` — covers CL-01: view instantiates without crash; orbLabel returns correct string per state

*Existing infrastructure covers build verification. Wave 0 adds component-specific tests.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Intensity % uses accentAI in dark, accentAction in light | CL-02 | Color rendering requires visual device inspection | Toggle dark/light mode on device, verify % label color switches |
| AI Orb pulsating animation visual quality | CL-01 | Canvas animation quality is subjective/visual | Run on device, verify smooth nebula pulsation during denoising |
| Dark mode: pure black background, no residual white | CL-03 | Full-screen visual sweep | Enable dark mode, scroll entire Cleaning Lab, verify no white/grey remnants |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 45s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
