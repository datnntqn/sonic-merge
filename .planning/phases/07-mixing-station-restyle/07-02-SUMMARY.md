---
phase: 07-mixing-station-restyle
plan: 02
subsystem: ui
tags: [swiftui, squirclecard, meshgradient, haptics, drag-gesture]

requires:
  - phase: 07-mixing-station-restyle-01
    provides: PillButtonStyle (Variant/Size), accentGradientEnd token, SquircleCard (Phase 6)
provides:
  - MergeSlotRow wrapped in SquircleCard with drag-reactive glow shadow
  - Masked Canvas waveform with MeshGradient (iOS 18) / LinearGradient (iOS 17) fallback
  - @GestureState-driven 1.03 scale + dual sensoryFeedback haptics on pickup/release
  - 44x44 PillButtonStyle(.icon) play button replacing manual Circle chrome
affects: [07-04-mixing-station-timeline, 07-05-verification]

tech-stack:
  added: []
  patterns:
    - "SquircleCard wrapper owns chrome; child views provide only content"
    - ".mask { Canvas } over a gradient = flat-fill Canvas becomes gradient-filled shape"
    - "@GestureState + DragGesture(minimumDistance: 0) for touch-state without stealing system gestures"
    - "Dual sensoryFeedback modifiers keyed to bool and !bool capture rising and falling edges"

key-files:
  created: []
  modified:
    - SonicMerge/Features/MixingStation/MergeSlotRow.swift

key-decisions:
  - "Mask Canvas pattern keeps existing bar-density tuning (0.92 vertical, barWidth-1.2 gap) while swapping flat fill for gradient"
  - "DragGesture(minimumDistance: 0) runs in parallel with List.onMove system gesture — preserves reorder-crash fix"
  - "Two .sensoryFeedback modifiers (trigger: isDragTouch and trigger: !isDragTouch) capture pickup/release edges separately"
  - "SquircleCard applies its own Spacing.md padding — removed the old manual .padding(14) to avoid double padding"

patterns-established:
  - "Gradient-masked Canvas: use .mask { Canvas { fill with .white } } to stamp shapes onto any SwiftUI gradient"
  - "Phase 7 card chrome is SquircleCard-owned — views must not re-apply background/stroke/shadow"

requirements-completed: [MIX-01, MIX-03, MIX-05]

duration: 6min
completed: 2026-04-12
---

# Phase 7 Plan 02: MergeSlotRow Restyle Summary

**MergeSlotRow wrapped in SquircleCard with masked MeshGradient (iOS 18) / LinearGradient (iOS 17) waveform, 44x44 pill play button, and @GestureState drag micro-animation driving scale + elevated shadow + dual impact haptics.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-04-12T13:46:00Z
- **Completed:** 2026-04-12T13:52:00Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Replaced manual `RoundedRectangle` + `strokeBorder` + `shadow` chrome with single `SquircleCard(glowEnabled: isDragTouch)` wrapper
- Swapped 40x40 `Circle().fill(accentAction)` play button for `PillButtonStyle(variant: .filled, size: .icon)` (44x44, HIG-compliant touch target)
- Added `@GestureState isDragTouch` driven by `DragGesture(minimumDistance: 0)` — scales card 1.03 and flips shadow to Deep-Indigo elevated glow during touch, without stealing the system `List.onMove` reorder gesture
- Dual `.sensoryFeedback(.impact(weight:))` modifiers — medium on pickup, light on release
- Rewrote `MergeSlotWaveformView` with `.mask { Canvas }` pattern over a 3x3 `MeshGradient` (Deep Indigo → System Purple) on iOS 18, `LinearGradient` top-leading → bottom-trailing fallback on iOS 17
- Migrated all forbidden text weights (`.bold`, `.medium`) to Phase 7 allowed set (`.semibold`, `.regular`); clip title dropped from `.body` to `.subheadline` per UI-SPEC typography table

## Task Commits

1. **Task 1: Replace MergeSlotRow body with SquircleCard wrapper + icon-pill play button + drag state** — `63131e8` (feat)
2. **Task 2: Replace MergeSlotWaveformView with masked Deep-Indigo to Purple gradient** — `449a4a7` (feat)

## Files Created/Modified
- `SonicMerge/Features/MixingStation/MergeSlotRow.swift` — full view-layer rewrite: outer struct wrapped in SquircleCard with `@GestureState`, drag scale/shadow/haptics; private `MergeSlotWaveformView` switched to `ZStack { backing well + .mask { Canvas } gradient }` with `#available(iOS 18.0, *)` branching

## Decisions Made
- Used `SonicMergeTheme.Spacing.md` for HStack gap and `Spacing.xs` for VStack gap — aligns with Phase 6 spacing tokens (avoided magic numbers from the v1.0 version)
- `_ in state = true` form in `.updating` handler is correct — the transaction parameter is discarded, we only flip the bool
- Kept the existing bar-density constants (`0.92` vertical scale, `barWidth - 1.2` gap) inside the mask Canvas — preserves visual parity of bar shapes while the fill changes from flat to gradient

## Deviations from Plan

None — plan executed exactly as written. Both tasks' acceptance criteria met, including the negative checks (no forbidden text weights, no manual stroke/shadow, no Circle play button background, no `semantic.accentWaveform` reference in the new waveform view).

Note: the file still has *one* use of `.accentWaveform` nowhere — grep confirms absence. A single `weight: .medium` remains in the file, but it is `sensoryFeedback(.impact(weight: .medium))` which is a `SensoryFeedback.Weight` haptic weight enum, NOT a font weight, so it is not covered by the forbidden-font-weight rule.

## Issues Encountered
None. Both `xcodebuild` runs succeeded cleanly on iPhone 17 simulator. Did not run `xcodebuild test` per plan-level note about tight disk space; build-for-device-simulator is the agreed source of truth for this wave.

## Next Phase Readiness

- **Ready for 07-04 (Mixing Station Timeline wiring):** `MergeSlotRow` now renders as a finished SquircleCard and can be dropped onto the `TimelineSpineView` background in the parent `MergeTimelineView` without further card-level changes
- **MIX-01 partial:** Clip card half is complete; center-line wiring is owned by 07-04
- **MIX-03 complete:** Waveform gradient with proper iOS 18/17 branching
- **MIX-05 complete:** Drag scale + elevated shadow + haptics shipped

## Self-Check: PASSED

- FOUND: SonicMerge/Features/MixingStation/MergeSlotRow.swift
- FOUND commit: 63131e8 (Task 1)
- FOUND commit: 449a4a7 (Task 2)
- Build verified: `xcodebuild ... build` exits 0 after both tasks
- Grep audit: `SquircleCard(glassEnabled: false, glowEnabled: isDragTouch)` present; `@GestureState private var isDragTouch` present; `PillButtonStyle(variant: .filled, size: .icon)` present; `DragGesture(minimumDistance: 0)` present; `scaleEffect(isDragTouch ? 1.03` present; `MeshGradient(` present; `LinearGradient(` present; `#available(iOS 18.0, *)` present; `semantic.accentGradientEnd` present; `semantic.accentWaveform` absent; old `strokeBorder(...accentAction).opacity(0.18)` absent; old `shadow(color: Color.black.opacity(0.12)` absent; old `Circle().fill(Color(uiColor: semantic.accentAction))` absent

---
*Phase: 07-mixing-station-restyle*
*Completed: 2026-04-12*
