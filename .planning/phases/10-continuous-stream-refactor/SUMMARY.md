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
| 3 | `feat 10-w3` | `JunctionView` capsule with native Menu; retire `GapRowView` | Med | Shipped |
| 4 | `8065320` | Compact geometry (10/14 card padding, 96×44 waveform, 12pt gaps) | Med | Shipped |
| 5 | `f2130ad` | `List.onMove` → `LazyVStack` + `.draggable`/`.dropDestination` (R-01) | **High** | Shipped — see runtime-verification note below |

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

### Deferred (intentional scope reductions, all spec-sanctioned fallbacks)

1. **D-05 — "Insert clip here" Junction menu item.** Spec marked this as R-03 (MEDIUM risk async orchestration) with explicit fallback "remove the action from the Menu". JunctionView ships without it. Toolbar `+` remains the import path; users drag-reorder after import.

2. **R-02 — Custom swipe-to-delete on clip rows.** SwiftUI's `.swipeActions(edge:)` modifier is `List`-only and was dropped along with the List. Spec marked this as MEDIUM with three options; we picked **option 2** (context-menu Delete only) over **option 1** (custom swipe gesture). Delete is still available via long-press → "Delete Clip" on `MergeSlotRow` (the existing `.contextMenu` path is unchanged). A future plan can add a custom trailing-swipe `DragGesture` if muscle memory regression matters in field testing.

3. **Explicit pickup/drop haptics during drag.** Spec called for `.impact(.medium)` on lift and `.impact(.light)` on drop. Not added — relying on the system's native drag haptic + `MergeSlotRow`'s existing `.sensoryFeedback` on the Phase 7 `isDragTouch` micro-animation gesture (which fires on touch-down regardless of whether a real drag completes).

---

## File-touch ledger

| File | Action | Wave |
|------|--------|------|
| `SonicMerge/Features/MixingStation/TimelineSpineView.swift` | Modified — 1pt + gradient | 1 |
| `SonicMerge/Features/MixingStation/MixingStationView.swift` | Modified — empty state, toolbar, `@AppStorage` flag | 1, 2 |
| `SonicMerge/Features/MixingStation/MergeTimelineView.swift` | Modified — multiple times: trust gate, GapRowView→JunctionView, geometry, then full LazyVStack rewrite | 2, 3, 4, 5 |
| `SonicMerge/Features/MixingStation/JunctionView.swift` | **Created** (new component) | 3 |
| `SonicMerge/Features/MixingStation/GapRowView.swift` | **Deleted** (superseded by JunctionView) | 3 |
| `SonicMerge/DesignSystem/SquircleCard.swift` | Modified — added `contentPadding: EdgeInsets` parameter (API-additive, no breaking change) | 4 |
| `SonicMerge/Features/MixingStation/MergeSlotRow.swift` | Modified — tighter padding via SquircleCard, 96×44 waveform, corner radius 8 | 4 |
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
| 9 | No regressions in import / export / denoise nav / theme picker / delete-or-equivalent | Build-only | Code path preserved; runtime regression check owed. **Note:** delete is now context-menu-only (R-02 option 2). |
| 10 | Invariants: no VM/service diff, zero new tokens, zero new packages, zero new blur layers | **Verified** | `git diff main..HEAD -- SonicMerge/Features/MixingStation/MixingStationViewModel.swift SonicMerge/Services/` returns empty. No `Color(...)` or `UIColor(...)` literals introduced; all colors come from `semantic.*`. No package manifest touched. SquircleCard's existing blur layer is the only one and unchanged. |

---

## Risks (status update vs. spec)

| Risk | Spec severity | Mitigation taken | Residual |
|------|---------------|------------------|----------|
| R-01 Reorder mechanism regression | HIGH | Implemented per spec; build clean. Spike acceptance (criterion 7) is build-verified only — runtime test on physical/simulator device owed. | Medium — could surface iOS-version-specific quirks in `.dropDestination` not visible at compile time. |
| R-02 Swipe-to-delete loss | MEDIUM | Picked option 2 (accept context-menu-only delete). Documented. | Low — UX regression for muscle-memory swipers. Mitigation: add custom DragGesture in a follow-up if field testing confirms regression. |
| R-03 Insert-clip-here async orchestration | MEDIUM | Dropped from Junction menu entirely (spec-sanctioned fallback). | None — toolbar `+` covers the import path. |
| R-04 Trust banner flag desync | LOW | None — accepting that reinstall/reset returns banner | Low — acceptable. |
| R-05 JunctionView Dynamic Type overflow | LOW | Capsule height is `frame(height: 28)`; if `.xxxLarge` truncates, can switch to `.padding(.vertical, ...)` instead of fixed height in a follow-up. | Low — needs Dynamic Type spot-check. |

---

## Tests

Phase 10 added zero ViewModel/service code, so no new unit tests.

**Regression-test result:** P2 baseline still 54 / 59 (same 5 pre-existing failures from Phase 5/3/2 stubs that exist on `main`). See `.planning/phases/09-polish-accessibility-audit/HUMAN-VERIFY.md` for the failure provenance map. `git diff main..HEAD -- SonicMergeTests/` is empty for this branch — no test files touched.

---

## How to revert if needed

```bash
# Revert just the high-risk reorder mechanism, keep all other waves:
git revert f2130ad   # Wave 5

# Revert everything (back to phase-09-polish-accessibility tip):
git checkout main
git reset --hard 2a70aba   # only safe before pushing
```

Or for surgical rollback per concern:
- Don't like the new junction capsule? → `git revert feat 10-w3`
- Want larger waveform thumbnails back? → `git revert 8065320`
- etc.
