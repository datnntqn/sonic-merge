---
phase: 06-design-system-foundation
plan: "01"
subsystem: design-system
tags: [design-system, colors, tokens, spacing, dark-mode, tdd]
dependency_graph:
  requires: []
  provides: [DS-01-color-tokens, DS-01-spacing-enum, DS-01-semantic-slots]
  affects: [06-02-components, phase-07-mixing-station-ui, phase-08-cleaning-lab-ui, phase-09-polish]
tech_stack:
  added: []
  patterns: [UIColor-in-SonicMergeSemantic, Color-uiColor-at-SwiftUI-callsites]
key_files:
  created: []
  modified:
    - SonicMerge/DesignSystem/SonicMergeTheme.swift
    - SonicMerge/DesignSystem/SonicMergeTheme+Appearance.swift
    - SonicMergeTests/SonicMergeThemeTests.swift
    - SonicMergeShareExtension/AppConstants.swift
decisions:
  - "[06-01]: primaryAccent updated to Deep Indigo #5856D6 — replaces #007AFF per D-03, unifying primary and AI accents on Deep Indigo"
  - "[06-01]: limeGreen #A7C957 added as accentAI — reserved exclusively for AI/denoising features, not used for decorative purposes"
  - "[06-01]: darkConveyor() palette replaced wholesale — v1.0 charcoal dark overwritten with pure black #000000 base per D-02"
  - "[06-01]: Radius.card updated to 24pt — squircle card style for Phase 7+ SquircleCard components per DS-02"
  - "[06-01]: Spacing enum with 7 tiers added to SonicMergeTheme — xs(4) through xxxl(64), multiples of 4pt per UI-SPEC"
  - "[06-01]: AppConstants.swift duplicated into SonicMergeShareExtension — app extensions are separate processes, cannot reference main app types"
metrics:
  duration: 5min
  completed: "2026-04-11"
  tasks_completed: 2
  files_modified: 4
---

# Phase 06 Plan 01: Design Token Migration v1.0 → v1.1 Summary

**One-liner:** Migrated color token system to v1.1 Modern Spatial Utility palette (#FBFBFC/#000000 background, Deep Indigo #5856D6 accent, Lime Green #A7C957 AI accent) with Spacing enum and 4 new SonicMergeSemantic slots.

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | TDD failing tests for v1.1 palette, Spacing, semantic slots | ccf829e | SonicMergeThemeTests.swift, SonicMergeShareExtension/AppConstants.swift |
| 1+2 (GREEN) | Update SonicMergeTheme.swift + SonicMergeTheme+Appearance.swift | 764ad40 | SonicMergeTheme.swift, SonicMergeTheme+Appearance.swift |

---

## Verification Results

- `xcodebuild test -only-testing SonicMergeTests/SonicMergeThemeTests`: ALL 23 TESTS PASSED
- `xcodebuild build`: BUILD SUCCEEDED (zero errors)
- `grep "static let card: CGFloat = 24"`: FOUND in SonicMergeTheme.swift
- `grep "var accentAI: UIColor"`: FOUND in SonicMergeTheme+Appearance.swift

---

## Changes Made

### SonicMergeTheme.swift — ColorPalette v1.1

| Token | Old | New |
|-------|-----|-----|
| `canvasBackground` | `#F8F9FA` (0.973, 0.976, 0.980) | `#FBFBFC` (251/255, 251/255, 252/255) |
| `primaryAccent` | `#007AFF` (0, 0.478, 1) | `#5856D6` Deep Indigo (88/255, 86/255, 214/255) |
| `aiAccent` | `#5856D6` (unchanged) | `#5856D6` (unchanged) |
| `limeGreen` | (new) | `#A7C957` (167/255, 201/255, 87/255) |
| `darkBackground` | (new) | `#000000` pure black |
| `darkCardSurface` | (new) | `#0F0F0F` (15/255) |
| `darkTextPrimary` | (new) | `UIColor(white: 0.96, alpha: 1)` |
| `darkTextSecondary` | (new) | `UIColor(white: 0.55, alpha: 1)` |

**Radius:** `card` 12pt → 24pt. `chip` 8pt (unchanged).

**Spacing enum added:**
```
xs=4  sm=8  md=16  lg=24  xl=32  xxl=48  xxxl=64
```

### SonicMergeTheme+Appearance.swift — SonicMergeSemantic v1.1

4 new token slots added to `SonicMergeSemantic`:
- `accentAI: UIColor` — Lime Green #A7C957 (same in both modes)
- `accentGlow: UIColor` — Deep Indigo #5856D6 (glow shadows, ring borders)
- `surfaceCard: UIColor` — #FFFFFF light / #0F0F0F dark
- `surfaceGlass: UIColor` — #FBFBFC@0.6 light / #000000@0.7 dark

`darkConveyor()` rewritten from v1.0 charcoal palette to v1.1 pure black:
- surfaceBase: #000000 (was charcoal `0.07, 0.08, 0.09`)
- accentAction: Deep Indigo #5856D6 (was neon-mint `0.18, 0.92, 0.62`)

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] AppConstants not found in SonicMergeShareExtension target**
- **Found during:** Task 1 RED phase (test build)
- **Issue:** `ShareExtensionViewController.swift` (introduced in Phase 05) references `AppConstants` from the main app target, which is not visible to the share extension process
- **Fix:** Created `SonicMergeShareExtension/AppConstants.swift` with the subset of AppConstants APIs needed by the extension (`appGroupID`, `clipsDirectory()`, `AppGroupError`)
- **Files modified:** SonicMergeShareExtension/AppConstants.swift (created)
- **Commit:** ccf829e

**2. [Rule 1 - Minor] Test file missing `import SwiftUI`**
- **Found during:** Task 1 RED phase
- **Issue:** Tests using `ColorScheme.dark/.light` (from SwiftUI) failed to compile without explicit import
- **Fix:** Added `import SwiftUI` to `SonicMergeThemeTests.swift`
- **Files modified:** SonicMergeTests/SonicMergeThemeTests.swift
- **Commit:** ccf829e

**3. [TDD Note] Tasks 1 and 2 GREEN committed together**
- Both tasks share the same test file (`SonicMergeThemeTests.swift`). The Task 2 tests reference `SonicMergeSemantic` properties (accentAI, surfaceCard, etc.) which caused compile failure until Task 2 implementation was also complete. The GREEN commit covers both tasks atomically to maintain a compilable state.

---

## Known Stubs

None. All color token values are wired to real constants. No placeholder values flow to UI rendering.

---

## Self-Check: PASSED

- [x] `SonicMerge/DesignSystem/SonicMergeTheme.swift` — FOUND
- [x] `SonicMerge/DesignSystem/SonicMergeTheme+Appearance.swift` — FOUND
- [x] `SonicMergeTests/SonicMergeThemeTests.swift` — FOUND
- [x] `SonicMergeShareExtension/AppConstants.swift` — FOUND
- [x] Commit `ccf829e` — FOUND (test RED phase)
- [x] Commit `764ad40` — FOUND (feat GREEN phase)
- [x] All 23 SonicMergeThemeTests passed
- [x] BUILD SUCCEEDED with zero errors
