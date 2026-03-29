---
phase: 5
slug: share-extension
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-29
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`import Testing`) |
| **Config file** | SonicMergeTests/SonicMergeTests.xctest |
| **Quick run command** | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SonicMergeTests` |
| **Full suite command** | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick unit tests for the affected module
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-00 | 01 | 1 | IMP-02 | stub | `xcodebuild build-for-testing -scheme SonicMerge` | Plan 01 Task 0 creates | ⬜ pending |
| 05-01-01 | 01 | 1 | IMP-02 | unit | `xcodebuild test -scheme SonicMerge -only-testing:SonicMergeTests/ShareExtensionTests` | Created by 05-01-00 | ⬜ pending |
| 05-01-02 | 01 | 1 | IMP-02 | unit | `xcodebuild test -scheme SonicMerge -only-testing:SonicMergeTests/MixingStationViewModelTests/testDuplicateDisplayNameIsSkipped` | Created by 05-01-00 | ⬜ pending |
| 05-01-03 | 01 | 1 | IMP-02 | unit | `xcodebuild test -scheme SonicMerge -only-testing:SonicMergeTests/MixingStationViewModelTests/testPendingImportPickedUpOnActive` | Created by 05-01-00 | ⬜ pending |
| 05-02-01 | 02 | 2 | IMP-02 | integration | Manual — requires Share Sheet interaction | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `SonicMergeTests/ShareExtensionTests.swift` — 3 failing test stubs: testFileCopyToClipsDirectory, testLargeFileCopyDoesNotCrash, testPendingKeyWrittenAndCleared (created by Plan 01 Task 0)
- [x] `SonicMergeTests/MixingStationViewModelTests.swift` — 1 failing test stub: testPendingImportPickedUpOnActive (created by Plan 01 Task 0)
- [ ] App Group entitlement configured in both targets before any handoff code runs

*Wave 0 stubs are created by Plan 05-01 Task 0 before implementation tasks begin.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Share Sheet appears in third-party apps | IMP-02 | Requires physical device / simulator UI interaction | Open Files app, long-press audio file, tap Share, verify SonicMerge appears in sheet |
| File appears in Mixing Station after share | IMP-02 | Requires end-to-end app handoff | Share audio from Voice Memos, manually open SonicMerge, verify clip appears in timeline |
| 30 MB+ file share does not crash extension | IMP-02 | Memory ceiling only testable at runtime | Share a 30 MB+ .m4a from Files app; extension must not crash (check Console for OOM) |
| No duplicate clip on double-share | IMP-02 | Requires UI state inspection | Share same file twice quickly; verify only one clip added to timeline |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
