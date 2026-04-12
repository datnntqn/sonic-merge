---
phase: 07-mixing-station-restyle
plan: 04
subsystem: mixing-station
tags: [swiftui, timeline, spine, squirclecard, pillbutton, restyle]

requires:
  - 07-01  # TimelineSpineView primitive, PillButtonStyle Variant/Size, accentGradientEnd
  - 07-02  # MergeSlotRow SquircleCard wrapper (transparent-bg so spine shows)
  - 07-03  # GapRowView transparent pill row (spine threads through)
provides:
  - MergeTimelineView clip rows with per-row TimelineSpineView background at 60pt leading inset
  - mergeOutputCard rebuilt as SquircleCard with PillButtonStyle Export CTA
  - MergeOperatorLabel with opaque surfaceBase circle fill (spine-threading illusion) + .title3 .semibold glyph
affects:
  - 07-05-verification

tech-stack:
  added: []
  patterns:
    - "Per-row .background(alignment: .leading) { TimelineSpineView() } — avoids ancestor overlay that would break Section/ForEach/.onMove reorder-crash invariant"
    - "Conditional spine visibility via `if viewModel.clips.count >= 2` inside the background closure — zero layout impact at count < 2"
    - "SquircleCard wrapper owns chrome; view body provides only content (no manual RoundedRectangle/padding(18))"
    - "Opaque operator chip fill threads the decorative spine through the visual chain"

key-files:
  created: []
  modified:
    - SonicMerge/Features/MixingStation/MergeTimelineView.swift
    - SonicMerge/Features/MixingStation/MergeOperatorLabel.swift

key-decisions:
  - "Spine attached as per-row .background on the clip VStack (not as a sibling ancestor layer) — preserves reorder-crash-fix invariant (single Section wrapping ForEach with .onMove on ForEach)"
  - "Spine visibility gated on viewModel.clips.count >= 2 inside the background closure — hides the line entirely at 0 or 1 clips with no layout shift"
  - "MergeSlotRow vertical padding migrated from raw 6 to Spacing.sm (8pt) — tokenized rhythm, within UI-SPEC tolerance of Spacing.lg/2 (12pt)"
  - "Operator chip uses surfaceBase (opaque) rather than surfaceElevated@0.55 — this is the spine-threading illusion: the chip visually cuts through the continuous 2pt line"
  - "Operator chip stroke migrated from accentAction to accentGlow (same hex, semantic rename per 07-UI-SPEC) — zero visual change"
  - "mergeOutputCard Export Button uses PillButtonStyle(variant: .filled, size: .regular) — Label font/weight/foreground are owned by the style, no explicit .font on the Label"

requirements-completed: [MIX-01, MIX-02]

metrics:
  duration: "4min"
  completed: "2026-04-12"
---

# Phase 7 Plan 04: MergeTimelineView Spine Wiring + Output Card Restyle Summary

Wired the Phase 7 MIX-02 central connecting line into `MergeTimelineView` as a per-row `.background(alignment: .leading) { TimelineSpineView() }` gated on `clips.count >= 2`, rebuilt `mergeOutputCard` as a `SquircleCard` with a `PillButtonStyle` Export button, and switched `MergeOperatorLabel` to an opaque `surfaceBase` circle fill so the spine visually threads through the `+` chips — all without touching the single-Section / ForEach / .onMove reorder-crash invariant.

## What Shipped

### MergeTimelineView.swift

- **Spine background** — per-row `.background(alignment: .leading) { if viewModel.clips.count >= 2 { TimelineSpineView() } }` on the clip VStack. Attached inside the ForEach row, NOT at the Section level, so it does not interfere with `.onMove` attachment to the ForEach.
- **SEQUENCE header typography** — `.heavy → .semibold` on the label; `.medium → .regular` on the subtitle (Phase 7 allowed weights only).
- **MergeSlotRow row padding** — raw `.vertical, 6` → `.vertical, SonicMergeTheme.Spacing.sm` (8pt). Tokenized.
- **mergeOutputCard** — completely rebuilt:
  - Outer chrome replaced: manual `RoundedRectangle(...).fill(surfaceSlot)` + `.overlay(...strokeBorder...)` + `.padding(18)` → `SquircleCard(glassEnabled: false, glowEnabled: false) { ... }`.
  - VStack spacing locked to `Spacing.md` (16pt) — resolves UI-checker non-blocking flag (a).
  - OUTPUT label `.heavy → .semibold`.
  - Estimated-length text `.medium → .semibold` (UI-SPEC subheadline role).
  - Export button: manual `RoundedRectangle(cornerRadius: 14).fill(accentAction)` + `.buttonStyle(.plain)` + explicit `.font(.body, .bold)` → `.buttonStyle(PillButtonStyle(variant: .filled, size: .regular))`. The Label now only provides `frame(maxWidth: .infinity)`; font/weight/foreground are owned by the style.

### MergeOperatorLabel.swift

- **Glyph font:** `.system(size: 22, weight: .bold, design: .rounded)` → `.system(.title3, design: .rounded, weight: .semibold)`. Migrates off the forbidden `.bold` weight.
- **Circle fill:** `surfaceElevated.opacity(0.55)` → `surfaceBase` (opaque). This is the spine-threading illusion — the decorative 2pt line visually threads through the `+` chip because the chip draws a solid disc that occludes the line inside its bounds while the line continues above and below.
- **Circle stroke:** `accentAction.opacity(0.35)` → `accentGlow.opacity(0.35)`. Same Deep Indigo hex, semantic rename per 07-UI-SPEC — zero visual delta.
- Unchanged: kind enum, 44×44 frame, outer `HStack { Spacer(); ...; Spacer() }`, `.padding(.vertical, 6)`, `.accessibilityLabel`.

## Reorder-Crash Invariant — PRESERVED

The single `Section { ForEach(...) { ... }.onMove { ... } }` structure is intact. Audit confirmation:

- `grep -c "\.onMove" MergeTimelineView.swift` → **1** (exactly one call)
- `.onMove` is attached to the `ForEach`, not to individual rows
- No new sibling `VStack`/`Group` wrapper introduced around the ForEach
- Spine is attached via `.background(alignment: .leading) { ... }` on the **row VStack**, which is a visual-only modifier that does not affect gesture propagation or layout hierarchy
- The DragGesture(minimumDistance: 0) micro-interaction from 07-02 on each MergeSlotRow is untouched

## Task Commits

1. **Task 1: Attach TimelineSpineView background + SEQUENCE typography + VStack spacing lock** — `2ec7457` (feat)
2. **Task 2: SquircleCard output card + PillButtonStyle export + opaque operator chip** — `c4bf40d` (feat)

## Files Modified

- `SonicMerge/Features/MixingStation/MergeTimelineView.swift` — spine background on ForEach row VStack, SEQUENCE/OUTPUT typography migration, mergeOutputCard rebuilt as SquircleCard + PillButtonStyle Export
- `SonicMerge/Features/MixingStation/MergeOperatorLabel.swift` — opaque surfaceBase fill, accentGlow stroke, .title3 .semibold glyph

## Verification

- `xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' build` → **BUILD SUCCEEDED** (twice — once after each task)
- `grep -c "\.onMove" MergeTimelineView.swift` → **1** (invariant preserved)
- `grep -q "TimelineSpineView()"` → **found**
- `grep -q "\.background(alignment: \.leading)"` → **found**
- `grep -q "viewModel.clips.count >= 2"` → **found**
- `grep -q "SquircleCard(glassEnabled: false, glowEnabled: false)"` → **found**
- `grep -q "PillButtonStyle(variant: \.filled, size: \.regular)"` → **found**
- `grep -q "Export merged audio"` → **found** (copy unchanged)
- `! grep -q "RoundedRectangle(cornerRadius: 14"` (old Export bg) → **absent**
- `! grep -q "\.padding(18)"` (old manual card padding) → **absent**
- No forbidden text weights on any `Text(...)` in either file (`! grep -E 'Text\([^)]*\)\.font\([^)]*\.(heavy|bold|medium|black)'`) → **clean**
- `grep -q "surfaceBase"` in MergeOperatorLabel → **found**
- `grep -q "accentGlow"` in MergeOperatorLabel → **found**
- `grep -q "\.title3"` in MergeOperatorLabel → **found**
- `! grep -q "weight: .bold"` in MergeOperatorLabel → **absent**
- `! grep -q "surfaceElevated"` in MergeOperatorLabel → **absent**

Note: `xcodebuild test` not executed — deferred per Phase 7 environmental note (disk ~100 MiB free, test-host install fails with ENOSPC). `xcodebuild build` is the agreed source of truth for this wave, which is why the reorder-crash and spine-threading behaviors will be validated in 07-05 human-verify integration checkpoint.

## Deviations from Plan

None — plan executed exactly as written. All acceptance criteria satisfied, all invariants preserved, build green after each task.

## Issues Encountered

None.

## Next Phase Readiness

- **07-05 (Mixing Station Polish / Verification):** All MIX-01 (SquircleCard all audio surfaces) and MIX-02 (central connecting line) requirements are now shipped. 07-05 is free to focus on human-verify integration checkpoint and any final polish without structural changes to the timeline.
- **MIX-01 COMPLETE:** Clip rows (07-02) + output card (this plan) are both SquircleCards.
- **MIX-02 COMPLETE:** Spine visible per-row between clips when count ≥ 2; threads through opaque operator chips; hidden at count < 2.

---
*Phase: 07-mixing-station-restyle*
*Completed: 2026-04-12*

## Self-Check: PASSED

- FOUND: SonicMerge/Features/MixingStation/MergeTimelineView.swift (modified)
- FOUND: SonicMerge/Features/MixingStation/MergeOperatorLabel.swift (modified)
- FOUND: commit 2ec7457 (Task 1)
- FOUND: commit c4bf40d (Task 2)
- BUILD: `xcodebuild build` on iPhone 17 simulator → SUCCEEDED
- INVARIANT: exactly 1 `.onMove` in MergeTimelineView.swift
- GREP: TimelineSpineView(), .background(alignment: .leading), clips.count >= 2, SquircleCard(glassEnabled: false, glowEnabled: false), PillButtonStyle(variant: .filled, size: .regular) — all present
- NEGATIVE GREP: RoundedRectangle(cornerRadius: 14, .padding(18), surfaceElevated, weight: .bold — all absent in expected files
