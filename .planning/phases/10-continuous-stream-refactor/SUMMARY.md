# Phase 10 — Continuous Stream Refactor — Implementation Summary

**Branch:** `phase-10-continuous-stream-refactor`
**Spec:** `docs/superpowers/specs/2026-04-24-main-screen-continuous-stream-design.md` (commit `cda3efd`)
**Implemented:** 2026-04-25 in a single session, executed against the design spec without an intermediate `PLAN.md` per user direction ("do all plan in one time").

---

## Wave ledger (atomic commits, in dependency order)

| Wave | Commit | Scope | Risk | Status |
|------|--------|-------|------|--------|
| 1 | `3716f25` | Spine refinement (1pt + gradient) + empty-state indigo halo | Low | Shipped |
| 2 | `068c4fb` | Toolbar overflow `•••` menu + first-launch trust banner gate | Low–Med | Shipped |
| 3 | `91eb9fa` | `JunctionView` capsule with native Menu; retire `GapRowView` | Med | Shipped |
| 4 | `8065320` | Compact geometry (10/14 card padding, 96×44 waveform, 12pt gaps) | Med | Shipped |
| 5 | `f2130ad` | `List.onMove` → `LazyVStack` + `.draggable`/`.dropDestination` (R-01) | **High** | Shipped — see runtime-verification note below |
| 6 | `d2d1d85` | Remove obsolete `GapRowLabelsTests`, write SUMMARY.md | n/a | Shipped |
| 7 | `6f5b6b9` | Custom trailing-swipe-to-delete via `.simultaneousGesture` (R-02 option 1) | Med | Shipped |
| 8 | `caf9def` | Wire "Insert clip here" Junction Menu action (D-05 / R-03) | Med | Shipped |

Each wave commits independently. If any wave proves regressive in real-world testing, it can be reverted via `git revert <sha>` without disturbing the others.

---

## What shipped vs. spec

### Shipped per-spec
- D-01 Scope (full main screen)
- D-02 Junction = native iOS Menu
- D-03 Toolbar `+` left, Denoise/Export/`•••` right with Appearance inside `•••`
- D-04 SF Symbols (`clock` for gaps, `arrow.triangle.merge` for crossfade)
- D-06 Trust banner first-launch gating via `@AppStorage("sonicMerge.hasImportedFirstClip")`
- D-07 Empty state with indigo halo on `waveform` icon + "drop them here" hint
- D-08 Reorder mechanism via `LazyVStack` + `.draggable`/`.dropDestination`
- D-09 Zero new design tokens; spine gradient built from existing `accentGlow`
- D-10 Zero ViewModel/service changes (hard invariant — held)
- Compact Timeline Geometry: −50% inter-row gap (16→12pt), tighter card padding, smaller waveform
- Empty-state copy "Tap + to add audio files\nor drop them here"
- Toolbar `•••` Label uses `"More options"` accessibility string

### Shipped in Waves 7–8 (originally deferred, then completed in this session)

- **D-05 — "Insert clip here" Junction menu item (Wave 8).** Wired with a `pendingInsert` async gate. Tap junction's "Insert clip here" → presents `.fileImporter` → `.onChange(viewModel.clips.count)` observer detects newly-imported tail clips and calls `viewModel.moveClip(fromOffsets:toOffset:)` to land them at the requested junction position. Toolbar imports are unaffected (gate is only set by junction taps). R-03 spike acceptance owed (5 trial insertions × 3 files at 5 different junction indices) — runtime test only.
- **R-02 option 1 — Custom swipe-to-delete (Wave 7).** A `DragGesture(minimumDistance: 12)` attached as `.simultaneousGesture` to `MergeSlotRow` so it coexists with the existing Phase 7 touch-tracker. Negative translation reveals a red trash swatch with linear opacity ramp; past the 80pt commit threshold a release fires `onDelete?()`. Rubber-band resistance (35%) caps reveal at 120pt. Vertical-dominant gestures are ignored. Animation gated on `accessibilityReduceMotion`. Context-menu Delete remains as the secondary path and the only path under VoiceOver.

### Still deferred

- **Explicit pickup/drop haptics during drag.** Spec called for `.impact(.medium)` on lift and `.impact(.light)` on drop. Not added — relying on the system's native drag haptic + `MergeSlotRow`'s existing `.sensoryFeedback` on the Phase 7 `isDragTouch` micro-animation gesture (which fires on touch-down regardless of whether a real drag completes).

---

## File-touch ledger

| File | Action | Wave |
|------|--------|------|
| `SonicMerge/Features/MixingStation/TimelineSpineView.swift` | Modified — 1pt + gradient | 1 |
| `SonicMerge/Features/MixingStation/MixingStationView.swift` | Modified — empty state, toolbar, `@AppStorage` flag | 1, 2 |
| `SonicMerge/Features/MixingStation/MergeTimelineView.swift` | Modified — trust gate, GapRowView→JunctionView, geometry, full LazyVStack rewrite, then `pendingInsert` orchestration for D-05 | 2, 3, 4, 5, 8 |
| `SonicMerge/Features/MixingStation/JunctionView.swift` | **Created** (new component); Wave 8 added optional `onInsertClip` callback | 3, 8 |
| `SonicMerge/Features/MixingStation/GapRowView.swift` | **Deleted** (superseded by JunctionView) | 3 |
| `SonicMerge/DesignSystem/SquircleCard.swift` | Modified — added `contentPadding: EdgeInsets` parameter (API-additive, no breaking change) | 4 |
| `SonicMerge/Features/MixingStation/MergeSlotRow.swift` | Modified — tighter padding via SquircleCard, 96×44 waveform, corner radius 8; Wave 7 added custom horizontal swipe-to-delete + red Delete swatch | 4, 7 |
| `SonicMerge/Features/MixingStation/MergeOperatorLabel.swift` | Untouched — `.plus` case remains as a type but is no longer instantiated; `.equals` still used at the bottom | (n/a) |
| `SonicMerge/Features/MixingStation/MixingStationViewModel.swift` | **Untouched** — hard invariant per D-10 | (n/a) |
| `SonicMerge/Services/AudioMergerService.swift` | **Untouched** — hard invariant per D-10 | (n/a) |

---

## Acceptance criteria status

| # | Criterion | Status | Verification |
|---|-----------|--------|--------------|
| 1 | Density: 5+ clips → ≥4 cards + ≥3 junctions visible without scrolling | Built — needs eyes | Geometry math: 64pt card + 12pt gap + 28pt junction + 12pt gap = 116pt per row. Five rows = 580pt; usable area ~620pt → fits 5 cards + 4 junctions. Math passes; visual confirmation owed. |
| 2 | Junction renders as single capsule; tap opens native Menu; selection updates with light haptic | Built | Code path verified; runtime tap behavior owed. |
| 3 | Spine 1pt with top→bottom indigo→transparent gradient; hidden when `clips.count < 2` | Built | Visibility rule preserved from Phase 7. |
| 4 | Toolbar: `+` left; Denoise · Export · `•••` right; Appearance inside `•••`; no paintpalette | Built | Source order Denoise → Export → `•••` produces visual `•••` at far right. |
| 5 | Trust banner visible only on fresh install; hides permanently after first import | Built | `@AppStorage("sonicMerge.hasImportedFirstClip")` flips on first `viewModel.clips.count > 0`. R-04 noted: device-local flag, reinstall returns banner — acceptable. |
| 6 | Empty state: waveform icon with halo, heading, body with `\nor drop them here`, Import CTA | Built | All in `MixingStationView.emptyState`. |
| 7 | Reorder: long-press → drag, no 3-line handles, no crash across (a)–(d) | **Build-only** | Acceptance criteria 7's runtime exercises (10 consecutive reorders, reorder during animation, rapid drag cancel × 5, 2-clip swap) require human runtime testing. If any scenario crashes, revert Wave 5 (`git revert f2130ad`) — Waves 1–4 still ship. |
| 8 | A11y: VoiceOver state on junction, Dynamic Type readable, Reduce Motion suppresses spring | Built | `.accessibilityLabel` + `.accessibilityActions` for Move up/down on rows; `.animation(reduceMotion ? nil : ...)` gate. Dynamic Type at `.xxxLarge` not yet tested. |
| 9 | No regressions in import / export / denoise nav / theme picker / delete-or-equivalent | Build-only | Code path preserved; runtime regression check owed. Delete now has two paths: trailing swipe (Wave 7) + context-menu (existing). |
| 10 | Invariants: no VM/service diff, zero new tokens, zero new packages, zero new blur layers | **Verified** | `git diff main..HEAD -- SonicMerge/Features/MixingStation/MixingStationViewModel.swift SonicMerge/Services/` returns empty. No `Color(...)` or `UIColor(...)` literals introduced; all colors come from `semantic.*`. No package manifest touched. SquircleCard's existing blur layer is the only one and unchanged. |

---

## Risks (status update vs. spec)

| Risk | Spec severity | Mitigation taken | Residual |
|------|---------------|------------------|----------|
| R-01 Reorder mechanism regression | HIGH | Implemented per spec; build clean. Spike acceptance (criterion 7) is build-verified only — runtime test on physical/simulator device owed. | Medium — could surface iOS-version-specific quirks in `.dropDestination` not visible at compile time. |
| R-02 Swipe-to-delete loss | MEDIUM | **Wave 7** implemented option 1 (custom trailing-swipe DragGesture coexisting via `.simultaneousGesture`). Threshold 80pt, rubber-band cap 120pt, reduceMotion-gated animation. | Low — gesture interaction with `.draggable` (long-press reorder) and the existing `isDragTouch` tracker is build-clean but not runtime-tested. If conflicts surface, revert `6f5b6b9`. |
| R-03 Insert-clip-here async orchestration | MEDIUM | **Wave 8** implemented per spec — `pendingInsert: (index, oldCount)?` gate + dedicated `.fileImporter` + `.onChange(viewModel.clips.count)` observer. Cancel + delta≤0 paths clear the gate. Toolbar imports unaffected. | Med — runtime verification of the 5-trial spike (5 different junction indices, 3 files each, no duplication, no toolbar-+ misfire) owed. Edge case: all-duplicate imports leave the gate dangling until the next count-change or file-importer use. |
| R-04 Trust banner flag desync | LOW | None — accepting that reinstall/reset returns banner | Low — acceptable. |
| R-05 JunctionView Dynamic Type overflow | LOW | Capsule height is `frame(height: 28)`; if `.xxxLarge` truncates, can switch to `.padding(.vertical, ...)` instead of fixed height in a follow-up. | Low — needs Dynamic Type spot-check. |

---

## Tests

Phase 10 added zero ViewModel/service code, so no new unit tests.

**Regression-test result (after Waves 1–8):** 53 / 58 pass on iPhone 17 Sim (iOS 26.2, `-parallel-testing-enabled NO`). Test count drops by one vs Phase 9 (59 → 58) because Wave 6 deleted the obsolete `GapRowLabelsTests` (single-test file that asserted the deleted `GapRowAccessibility.label` static string). The 5 failures are the same Phase 9 baseline (3× Phase 5 ShareExtension stubs, 1× Phase 3 ABPlayback stub, 1× Phase 2 AudioMergerService crossfade duration assertion) — confirmed pre-existing on `main`. Phase 10 introduced **zero** new test failures.

---

## How to revert if needed

```bash
# Revert specific waves atomically (each commit is independent):
git revert caf9def   # Wave 8 — Insert clip here (R-03 orchestration)
git revert 6f5b6b9   # Wave 7 — Custom swipe-to-delete (R-02 gesture)
git revert f2130ad   # Wave 5 — LazyVStack reorder (R-01)
git revert 8065320   # Wave 4 — Compact geometry
git revert 91eb9fa   # Wave 3 — JunctionView (would re-need GapRowView)
git revert 068c4fb   # Wave 2 — Toolbar overflow + trust gate
git revert 3716f25   # Wave 1 — Spine + empty-state glow

# Revert everything (back to phase-09-polish-accessibility tip):
git checkout main
git reset --hard 2a70aba   # only safe before pushing
```

Note: Waves 3 ↔ 4 ↔ 5 are mostly orthogonal but some MergeTimelineView edits stack. If you revert Wave 3, you'll need to also restore `GapRowView.swift` (and the `GapRowLabelsTests` if you want green tests) — easier to just `git revert` the commit chain than recreate the file.

The most likely reverts in field testing:
- **Wave 5** if `.draggable`/`.dropDestination` reorder shows iOS-specific instability under the criterion-7 stress exercises.
- **Wave 7** if the custom swipe gesture conflicts with `.draggable`'s long-press activation in unexpected ways.
- **Wave 8** if the `pendingInsert` observer misfires (e.g., the all-duplicates edge case becomes visible).
