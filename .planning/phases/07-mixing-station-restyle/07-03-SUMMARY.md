---
phase: 07-mixing-station-restyle
plan: 03
subsystem: mixing-station
tags: [restyle, pill-button, gap-row, accessibility, ui]
requires:
  - 07-01  # PillButtonStyle(variant:size:) extended with .outline/.compact
provides:
  - GapRowView rendered as HStack of 4 PillButtonStyle pills
  - Transparent gap row background (timeline spine visibility)
affects:
  - SonicMerge/Features/MixingStation/GapRowView.swift
tech-stack:
  added: []
  patterns:
    - "ForEach + conditional buttonStyle for selected/unselected pill rows"
    - "Color.clear background to let ancestor TimelineSpineView show through"
key-files:
  created: []
  modified:
    - SonicMerge/Features/MixingStation/GapRowView.swift
decisions:
  - "Dropped unused `semantic` environment and `import UIKit` — no longer needed after removing segmented Picker tint"
  - "Kept existing `init(transition:onUpdate:)` and `@State selection` initialization logic untouched — ViewModel contract preserved byte-for-byte"
metrics:
  duration: "3min"
  completed: "2026-04-12"
requirements:
  - MIX-04
---

# Phase 7 Plan 03: GapRow Pill Restyle Summary

Restyled `GapRowView` from a segmented iOS Picker to a horizontal HStack of four `PillButtonStyle` buttons, preserving the existing selection state machine and `onUpdate` callback contract exactly — zero ViewModel changes.

## What Shipped

- `GapRowView.body` rewritten as `HStack(spacing: Spacing.sm)` with `ForEach(GapOption.allCases)` rendering 4 buttons (0.5s, 1.0s, 2.0s, Crossfade)
- Selected pill: `PillButtonStyle(variant: .filled, size: .compact)` (Deep Indigo fill, white label, inner glow)
- Unselected pills: `PillButtonStyle(variant: .outline, size: .compact)` (transparent bg, 1pt accentAction@0.5 stroke)
- Row background is `Color.clear` (was `semantic.surfaceElevated@0.65` + `RoundedRectangle(Radius.chip)` clip shape) — required for MIX-02 timeline spine to show through gap rows
- Selected pill carries `.accessibilityAddTraits(.isSelected)`
- `.accessibilityElement(children: .combine)` + `.accessibilityLabel(GapRowAccessibility.label)` retained from v1.0 (VoiceOver grouping unchanged)
- Removed unused `@Environment(\.sonicMergeSemantic)` property and `import UIKit` (no longer referenced)

## Selection State Logic

Unchanged from pre-07-03:
1. `init(transition:)` computes initial `GapOption` by mapping `transition.isCrossfade` → `.crossfade` else `transition.gapDuration ∈ {1.0, 2.0, 0.5}` → `.one | .two | .half`.
2. Button `action: { selection = option }` sets `@State selection`.
3. `.onChange(of: selection)` fires `onUpdate(newValue.gapDuration, newValue.isCrossfade)` — exact same signature that `MixingStationViewModel.updateTransition` consumes.

**No ViewModel code was modified.** `MixingStationViewModel` and `GapTransition` are untouched.

## Accessibility

| Element             | Trait/Label                                   |
| ------------------- | --------------------------------------------- |
| Row (combined)      | `accessibilityLabel: "Transition between clips"` |
| Selected pill       | `.isSelected` trait added                     |
| Unselected pill     | No extra traits                               |
| VoiceOver grouping  | `.accessibilityElement(children: .combine)`   |

## Deviations from Plan

**1. [Rule 3 - Scope cleanup] Removed now-unused imports and environment**
- **Found during:** Task 1
- **Issue:** After swapping Picker for pills, `semantic` environment and `import UIKit` became dead code (would cause unused-var warnings)
- **Fix:** Removed both. This is an in-file cleanup strictly tied to the current edit — no behavior change.
- **Files modified:** `SonicMerge/Features/MixingStation/GapRowView.swift`
- **Commit:** 105918b

## Verification

- `xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' build` — **BUILD SUCCEEDED**
- Grep audit: `ForEach(GapOption.allCases`, `PillButtonStyle(variant: .filled,  size: .compact)`, `PillButtonStyle(variant: .outline, size: .compact)`, `accessibilityAddTraits(selection == option ? .isSelected : [])`, `background(Color.clear)`, `onUpdate(newValue.gapDuration, newValue.isCrossfade)`, `accessibilityLabel(GapRowAccessibility.label)` — **all present**
- Negative grep: `pickerStyle(.segmented)`, `semantic.surfaceElevated` — **both removed**
- Manual visual check deferred to 07-05 integration checkpoint

## Commits

- `105918b` — feat(07-03): restyle GapRowView as HStack of PillButtonStyle pills

## Self-Check: PASSED

- FOUND: SonicMerge/Features/MixingStation/GapRowView.swift (modified)
- FOUND: commit 105918b in git log
- Build succeeded on iPhone 17 simulator (Xcode 26.2 / iOS 26.2 SDK)
