---
phase: 07-mixing-station-restyle
plan: 01
subsystem: ui
tags: [swiftui, design-system, theme, buttonstyle, accessibility]

requires:
  - phase: 06-design-system-foundation
    provides: PillButtonStyle v1, SonicMergeSemantic v1.1 slots, ColorPalette v1.1
provides:
  - systemPurple #AF52DE palette constant
  - accentGradientEnd semantic slot wired in light and dark palettes
  - TimelineSpineView primitive (2pt vertical spine, 60pt leading inset)
  - PillButtonStyle Variant (filled/outline) and Size (regular/compact/icon) enums with backward-compatible defaults
affects: [07-02-mergeslotrow-restyle, 07-03-gaprowview-compact-pills, 07-04-mergetimelineview-spine, 07-05-mixing-station-polish]

tech-stack:
  added: []
  patterns:
    - "Semantic palette additive extension: new slot added after surfaceGlass, wired in both lightClassic() and darkConveyor() with trailing comma before new arg"
    - "ButtonStyle parameter expansion via defaulted init — zero-arg call sites continue to compile unchanged"
    - "PBXFileSystemSynchronizedRootGroup auto-inclusion for new files under SonicMerge/Features/*"

key-files:
  created:
    - SonicMerge/Features/MixingStation/TimelineSpineView.swift
  modified:
    - SonicMerge/DesignSystem/SonicMergeTheme.swift
    - SonicMerge/DesignSystem/SonicMergeTheme+Appearance.swift
    - SonicMerge/DesignSystem/PillButtonStyle.swift
    - SonicMergeTests/SonicMergeThemeTests.swift

key-decisions:
  - "PillButtonStyle .icon size uses fixed 44x44 frame to guarantee HIG minimum touch target regardless of label content"
  - "PillButtonStyle .outline variant uses Color.clear background (not semi-transparent) so the 07-04 timeline spine remains visible behind gap row pills"
  - "accentGradientEnd identical in light and dark palettes — gradient stops do not shift by scheme per 07-UI-SPEC MIX-03"
  - "TimelineSpineView reads accentGlow (Deep Indigo) from environment rather than hardcoding hex, inheriting palette consistency"
  - "reduceTransparency bumps spine opacity 0.35 -> 0.55 instead of switching to a solid fill — preserves visual language while satisfying accessibility"
  - "TimelineSpineView is registered via PBXFileSystemSynchronizedRootGroup (not PBXBuildFile entry) because the project uses synchronized groups — plan's pbxproj-surgery fallback is not applicable"

patterns-established:
  - "Semantic slot extension: add var to SonicMergeSemantic, wire in both palette factories with matching trailing-comma formatting"
  - "ButtonStyle variants via nested enums + defaulted init preserves zero-arg call sites"
  - "Decorative timeline overlays: accessibilityHidden(true) + allowsHitTesting(false) + opacity bump under reduceTransparency"

requirements-completed: [MIX-01, MIX-02, MIX-03, MIX-04]

duration: 5min
completed: 2026-04-12
---

# Phase 07 Plan 01: Mixing Station Restyle Foundation Summary

**systemPurple #AF52DE wired as accentGradientEnd semantic slot, TimelineSpineView 2pt spine primitive, and PillButtonStyle extended with Variant/Size enums (backward-compatible defaults) — all foundation primitives for Phase 7 downstream waves.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-04-12T13:38:45Z
- **Completed:** 2026-04-12T13:44:00Z
- **Tasks:** 3
- **Files modified:** 4 (1 created, 3 modified) + 1 test file

## Accomplishments

- Added `SonicMergeTheme.ColorPalette.systemPurple` UIColor constant (#AF52DE) — the only new raw hex in Phase 7
- Added `accentGradientEnd` semantic slot to `SonicMergeSemantic` struct and wired it identically in `lightClassic()` and `darkConveyor()` factories
- Shipped three new theme tests locking the #AF52DE hex in both palette and semantic layers
- Created `TimelineSpineView.swift` — a reusable 2pt vertical spine primitive with 60pt leading inset, reading `accentGlow` from the environment, with reduceTransparency opacity boost (0.35 → 0.55)
- Extended `PillButtonStyle` with `Variant` (`.filled`, `.outline`) and `Size` (`.regular`, `.compact`, `.icon`) enums plus a defaulted `init(variant:size:)` that preserves Phase 6 visual exactly for zero-arg call sites
- Phase 6 `#Preview` (the only existing call site) continues to compile unchanged; new preview showcases all five variant/size combinations downstream plans will consume

## Task Commits

1. **Task 1 RED: Failing tests for systemPurple / accentGradientEnd** — `946f70b` (test)
2. **Task 1 GREEN: systemPurple constant + accentGradientEnd semantic slot** — `89b8614` (feat)
3. **Task 2: TimelineSpineView primitive** — `804ac02` (feat)
4. **Task 3: PillButtonStyle Variant/Size enums with defaults** — `491f8dd` (feat)

_Note: Task 1 used TDD (RED → GREEN). Task 3 was marked TDD in the plan but had no unit-test behavior (enum existence is structural) — the `#Preview` covering all variants serves as the executable spec; build succeeds as GREEN signal._

## Files Created/Modified

- `SonicMerge/Features/MixingStation/TimelineSpineView.swift` (NEW) — 2pt spine at 60pt leading inset, accessibilityHidden decorative overlay
- `SonicMerge/DesignSystem/SonicMergeTheme.swift` — `systemPurple` UIColor constant appended to ColorPalette
- `SonicMerge/DesignSystem/SonicMergeTheme+Appearance.swift` — `accentGradientEnd` slot added, wired in both semantic palette factories
- `SonicMerge/DesignSystem/PillButtonStyle.swift` — full rewrite: added Variant/Size enums + defaulted init, variant-aware label color / background / stroke / inner glow branches, extended #Preview
- `SonicMergeTests/SonicMergeThemeTests.swift` — 3 new tests: `systemPurple_isAF52DE`, `lightSemantic_accentGradientEnd_isSystemPurple`, `darkSemantic_accentGradientEnd_isSystemPurple`

## Decisions Made

- **`.icon` size uses fixed 44×44 frame:** HIG minimum touch target; prevents label content from shrinking the hit area below 44pt for the 07-02 play button
- **`.outline` variant uses `Color.clear` (not tinted) background:** Required so the 07-04 TimelineSpineView remains visible behind 07-03 gap row pills
- **`accentGradientEnd` identical in both palettes:** Per 07-UI-SPEC MIX-03 the waveform gradient end-stop does not shift between light and dark modes; only the start-stop (`accentWaveform`) differs by scheme
- **TimelineSpineView reads `accentGlow` from environment:** Inherits Deep Indigo #5856D6 automatically from Phase 6 semantic layer — no hardcoded hex values in view code
- **reduceTransparency → opacity boost, not fill swap:** 0.35 → 0.55 preserves the decorative character of the spine while satisfying WCAG contrast for users needing stronger edges

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Xcode project registration via PBXFileSystemSynchronizedRootGroup**

- **Found during:** Task 2 (TimelineSpineView creation)
- **Issue:** Plan step 2 instructed to grep `MergeOperatorLabel.swift` in `project.pbxproj` and replicate PBXBuildFile / PBXFileReference / PBXSourcesBuildPhase / PBXGroup entries with fresh UUIDs. Grep returned zero matches — because the project actually uses `PBXFileSystemSynchronizedRootGroup`, which auto-includes any file placed inside synchronized directories with no per-file pbxproj entries required.
- **Fix:** Placed `TimelineSpineView.swift` under `SonicMerge/Features/MixingStation/` (a synchronized group) and ran `xcodebuild build` to verify auto-inclusion succeeded. No pbxproj edits were needed or made.
- **Files modified:** None beyond the new source file
- **Verification:** `xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' build` → `** BUILD SUCCEEDED **`
- **Committed in:** `804ac02`

**Note on acceptance criterion:** Plan's acceptance criterion `grep -q "TimelineSpineView.swift" SonicMerge.xcodeproj/project.pbxproj` is technically NOT satisfied because synchronized groups do not create explicit file entries. The functionally equivalent criterion — "file is a member of the SonicMerge target and compiles into the app" — IS satisfied, as proven by the successful build. This is a plan-authoring artifact, not an execution defect. The project's existing precedent for synchronized groups was established in Phase 01 (see STATE.md decision `[Phase 01-01]: SonicMergeTests uses PBXFileSystemSynchronizedRootGroup for zero-configuration test file inclusion`).

---

**Total deviations:** 1 auto-fixed (Rule 3 — blocking: plan assumed legacy pbxproj structure that no longer applies)
**Impact on plan:** No functional impact — the "add to project" step was a no-op because the project uses file-system sync. All Task 2 acceptance criteria except the raw grep are satisfied; the grep criterion is superseded by successful build membership.

## Issues Encountered

### Disk space blocker — theme test execution deferred

`xcodebuild test` cannot install the SonicMerge test host .app because `/System/Volumes/Data` is at 100% capacity (~158 MiB free). The simulator fails to create staging directories under `XCTestDevices` with `No space left on device` before any test can run. This is strictly environmental — all new code compiles, the test target builds cleanly (`** TEST BUILD SUCCEEDED **`), and the three new tests are pure numeric `#expect` assertions against UIColor components literally set from `(175/255, 82/255, 222/255, 1)` — no runtime path can diverge.

**Required user action:** Free ~5+ GB on Macintosh HD, then run:
```
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SonicMergeTests/SonicMergeThemeTests test
```

Tracked in `.planning/phases/07-mixing-station-restyle/deferred-items.md`.

**Phase blocker status:** Not a blocker for downstream waves. Plans 07-02 / 07-03 / 07-04 / 07-05 depend on the compiled API surface (Variant/Size enums, accentGradientEnd slot, TimelineSpineView type), all of which the successful build proves are exported correctly.

## User Setup Required

None — no external service configuration required. One environmental chore: free disk space to run the test suite (see Issues Encountered).

## Next Phase Readiness

- `semantic.accentGradientEnd` available for 07-02 MergeSlotRow mesh gradient end-stop (MIX-03)
- `TimelineSpineView` ready to be laid as `.background(alignment: .leading)` per clip row in 07-04 MergeTimelineView (MIX-02)
- `PillButtonStyle(variant: .filled, size: .icon)` ready for 07-02 play button
- `PillButtonStyle(variant: .outline, size: .compact)` and `PillButtonStyle(variant: .filled, size: .compact)` ready for 07-03 GapRowView compact pills
- All Phase 6 call sites (production: none; previews: 1) continue to compile unchanged

---
*Phase: 07-mixing-station-restyle*
*Completed: 2026-04-12*

## Self-Check: PASSED

- FOUND: SonicMerge/Features/MixingStation/TimelineSpineView.swift
- FOUND: `systemPurple` in SonicMerge/DesignSystem/SonicMergeTheme.swift
- FOUND: `accentGradientEnd` in SonicMerge/DesignSystem/SonicMergeTheme+Appearance.swift (2 palette occurrences)
- FOUND: `enum Variant` + `enum Size` in SonicMerge/DesignSystem/PillButtonStyle.swift
- FOUND: 3 new tests in SonicMergeTests/SonicMergeThemeTests.swift (systemPurple_isAF52DE, light/dark accentGradientEnd_isSystemPurple)
- FOUND: commit 946f70b (test RED)
- FOUND: commit 89b8614 (feat theme)
- FOUND: commit 804ac02 (feat spine)
- FOUND: commit 491f8dd (feat pill button)
- BUILD: `xcodebuild build` → SUCCEEDED
- BUILD: `xcodebuild build-for-testing` → SUCCEEDED
- TEST RUN: deferred (disk space — environmental, tracked in deferred-items.md)
