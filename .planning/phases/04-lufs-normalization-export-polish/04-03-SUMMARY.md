---
phase: 04-lufs-normalization-export-polish
plan: 03
subsystem: ui
tags: [swiftui, export, lufs, normalization, share-sheet, activity-view-controller]

# Dependency graph
requires:
  - phase: 04-02
    provides: ExportOptions struct, lufsNormalize parameter in AudioMergerService.export()

provides:
  - ExportFormatSheet LUFS toggle row with correct UI-SPEC layout (HStack labels + Toggle)
  - ExportProgressSheet dynamic title via isNormalizing parameter
  - MixingStationViewModel.exportMerged(options:) threads LUFS flag end-to-end
  - dismissShareSheet() resets exportProgress to 0
  - ActivityViewController completionWithItemsHandler fires state reset on every share dismissal

affects: [04-04-CleaningLabView-wiring, 05-ui-polish]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ExportOptions as value type passed through callback chain from sheet to ViewModel to service"
    - "completionWithItemsHandler pattern for UIActivityViewController dismissal callback"

key-files:
  created: []
  modified:
    - SonicMerge/Features/MixingStation/ExportFormatSheet.swift
    - SonicMerge/Features/MixingStation/ExportProgressSheet.swift
    - SonicMerge/Features/MixingStation/MixingStationViewModel.swift
    - SonicMerge/Features/MixingStation/MixingStationView.swift
    - SonicMerge/Features/MixingStation/ActivityViewController.swift
    - SonicMergeTests/MixingStationViewModelTests.swift

key-decisions:
  - "ExportProgressSheet.isNormalizing uses var (not let) with default false for backward compatibility at call sites not yet passing the parameter"
  - "isNormalizingExport reset in the Task completion block (alongside isExporting = false) to correctly track normalizing state through export lifecycle"
  - "Test call site updated from exportMerged(format:) to exportMerged(options:) — Rule 1 auto-fix since signature change breaks compilation"

patterns-established:
  - "completionWithItemsHandler pattern: UIViewControllerRepresentable wires handler to Coordinator.onDismiss in makeUIViewController"

requirements-completed: [EXP-03]

# Metrics
duration: 10min
completed: 2026-03-19
---

# Phase 4 Plan 3: MixingStation LUFS Wiring Summary

**LUFS toggle UI wired end-to-end: ExportFormatSheet shows 'Normalize to -16 LUFS' HStack row, ViewModel threads lufsNormalize to AudioMergerService, state resets on any share sheet dismissal via completionWithItemsHandler**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-03-19T15:14:00Z
- **Completed:** 2026-03-19T15:21:25Z
- **Tasks:** 2
- **Files modified:** 6 (5 source + 1 test)

## Accomplishments
- Replaced placeholder `Toggle("Normalize Loudness (-16 LUFS)", ...)` with full UI-SPEC HStack layout: VStack labels + Toggle with correct tint
- ExportProgressSheet title is now dynamic: "Exporting & Normalizing..." when isNormalizing=true
- MixingStationViewModel.exportMerged refactored to accept ExportOptions and thread lufsNormalize to AudioMergerService
- Fixed dismissShareSheet() bug: missing `exportProgress = 0` reset now corrected
- ActivityViewController wires completionWithItemsHandler to coordinator.onDismiss, ensuring state reset fires regardless of share action
- All 5 MixingStationViewModelTests pass GREEN including testDismissShareSheetResetsState

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Toggle row to ExportFormatSheet + fix ExportProgressSheet dynamic title** - `9a7a233` (feat)
2. **Task 2: Update MixingStationViewModel + MixingStationView + ActivityViewController** - `4c445ee` (feat)

## Files Created/Modified
- `SonicMerge/Features/MixingStation/ExportFormatSheet.swift` - Replaced simple Toggle with HStack/VStack layout per UI-SPEC (correct copy, foreground colors, .tint accent)
- `SonicMerge/Features/MixingStation/ExportProgressSheet.swift` - Added isNormalizing: Bool = false parameter; dynamic title text
- `SonicMerge/Features/MixingStation/MixingStationViewModel.swift` - exportMerged now takes ExportOptions; added isNormalizingExport state; fixed dismissShareSheet to reset exportProgress
- `SonicMerge/Features/MixingStation/MixingStationView.swift` - Updated ExportFormatSheet callback to pass options; added isNormalizing: to ExportProgressSheet call site
- `SonicMerge/Features/MixingStation/ActivityViewController.swift` - Wire completionWithItemsHandler to coordinator.onDismiss in makeUIViewController
- `SonicMergeTests/MixingStationViewModelTests.swift` - Fixed test call site: exportMerged(options:) (signature changed)

## Decisions Made
- `ExportProgressSheet.isNormalizing` declared with `var` (not `let`) and default `false` for backward compatibility — call sites that don't pass `isNormalizing` still compile unmodified
- `isNormalizingExport` is set before the export Task begins and reset inside the Task completion block alongside `isExporting = false` to correctly track state through the async lifecycle
- Test `cancelExportStopsExportTaskAndCleansUp` call site updated from `exportMerged(format:)` to `exportMerged(options:)` as a Rule 1 auto-fix — the signature change broke compilation

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated test call site for changed exportMerged signature**
- **Found during:** Task 2 (MixingStationViewModel changes)
- **Issue:** MixingStationViewModelTests.swift line 80 called `vm.exportMerged(format: .m4a)` — would fail to compile after signature change to `exportMerged(options:)`
- **Fix:** Updated to `vm.exportMerged(options: ExportOptions(format: .m4a, lufsNormalize: false))`
- **Files modified:** SonicMergeTests/MixingStationViewModelTests.swift
- **Verification:** All 5 tests pass GREEN after fix
- **Committed in:** `4c445ee` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug: compile-breaking call site)
**Impact on plan:** Essential fix — test file must match the new ViewModel signature. No scope creep.

## Issues Encountered
None - all changes applied cleanly as specified.

## Next Phase Readiness
- MixingStation export path fully wired for LUFS normalization
- Plan 04-04 (CleaningLabView wiring) can proceed — it follows the same ExportOptions + callback pattern established here
- ActivityViewController state reset now reliable via completionWithItemsHandler on all share dismissal paths

---
*Phase: 04-lufs-normalization-export-polish*
*Completed: 2026-03-19*
