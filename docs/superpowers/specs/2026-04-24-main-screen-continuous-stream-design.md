---
title: Main Screen "Continuous Stream" Refactor — Design Spec
date: 2026-04-24
author: brainstorming
status: draft
branch: phase-09-polish-accessibility
supersedes_sections_of: .planning/phases/07-mixing-station-restyle/07-UI-SPEC.md (timeline density, gap controls, toolbar icon layout, reorder mechanism)
---

# Main Screen "Continuous Stream" Refactor

## Goal

Redesign the SonicMerge main screen (Mixing Station) to feel like a continuous, high-density professional audio stream — not a sparse list of files. This is a progressive-disclosure refactor on top of the Phase 7 "Modern Spatial Utility" visual system: same tokens, tighter geometry, smart junctions replacing always-visible gap pills, and a cleaner toolbar.

## Why now

Post-Phase 7/8/9 visual audit: the timeline has correct primitives (SquircleCard, mesh waveforms, spine) but wrong information density. Users see ~2 clips per screen when they should see 4–5. Gap controls (`0.5s | 1.0s | 2.0s | Crossfade` on every row) create visual noise equal in weight to the clips themselves. Toolbar icons are imbalanced (1 pill left, 3 icons crammed right) and flatten a preference (Appearance) to the same weight as primary feature actions (Denoise, Export).

## Decisions Captured from Brainstorming

| # | Decision | Source |
|---|---|---|
| D-01 | Scope: full main screen — timeline + toolbar + trust banner + empty state | User Q1 = C |
| D-02 | Junction interaction uses native iOS `Menu` (not inline expansion, not popover) | User Q2 = A |
| D-03 | Toolbar: `+` left; Denoise + Export + `•••` right; Appearance moves into `•••` | User Q3 = B |
| D-04 | Junction label uses SF Symbols only (no emoji): `clock` for gaps, `arrow.triangle.merge` for crossfade | User Q4 = B |
| D-05 | Inline "Insert clip here…" is an action inside the Junction menu (not a separate `+` chip) | User Q5 = A |
| D-06 | Trust banner is first-launch only (hidden after first successful import; never returns) | User 6a |
| D-07 | Empty state gets a light restyle: indigo glow on waveform icon + drop-files hint line | User 6b |
| D-08 | Reorder mechanism: replace `List.onMove` with `LazyVStack` + `.draggable`/`.dropDestination` so 3-line handles disappear | Compact timeline requirement |
| D-09 | Zero new design tokens — build the spine gradient from existing `accentGlow` + `.opacity(0)` | Simplification |
| D-10 | ViewModel and services stay frozen — no new `@Published` properties, no new public methods | Inherited Phase 7 invariant (respected) |

## Non-Goals

- Restyling the Cleaning Lab / AI Orb screen (Phase 8 — untouched)
- Changing export formats, LUFS normalization, or denoising logic (services frozen)
- Re-theming the palette (Deep Indigo + System Purple stay)
- Adding a new blur layer (GPU budget still 2 blur layers/screen max; this spec adds zero)
- Adding an "About" or settings sheet for the migrated "Private by design" copy (can follow in a later phase)

---

## Scope — File Touch List

| File | Action | Purpose |
|---|---|---|
| `SonicMerge/Features/MixingStation/MixingStationView.swift` | Modify | Toolbar restructure (D-03); trust banner `@AppStorage` gate (D-06); empty state restyle (D-07) |
| `SonicMerge/Features/MixingStation/MergeTimelineView.swift` | Modify | `List` → `LazyVStack` (D-08); replace `GapRowView` rows with `JunctionView` (D-02); tighten spacing (50% reduction) |
| `SonicMerge/Features/MixingStation/GapRowView.swift` | **Delete** | Superseded by `JunctionView` |
| `SonicMerge/Features/MixingStation/JunctionView.swift` | **Create** | New Smart Junction component (D-02, D-04, D-05) |
| `SonicMerge/Features/MixingStation/MergeSlotRow.swift` | Modify | Reduced vertical padding; drag-ready via `.draggable`; remove any remaining handle affordance |
| `SonicMerge/Features/MixingStation/TimelineSpineView.swift` | Modify | 2pt flat → 1pt gradient (D-09) |
| `SonicMerge/Features/MixingStation/MergeOperatorLabel.swift` | Modify | Keep `.equals` bottom-terminator case; the `.plus` case is no longer instantiated from the timeline (remains as a type, unused) |
| `SonicMerge/DesignSystem/SonicMergeTheme.swift` | Untouched | Zero new tokens |
| `SonicMerge/DesignSystem/SonicMergeTheme+Appearance.swift` | Untouched | Zero new tokens |
| `SonicMerge/Features/MixingStation/MixingStationViewModel.swift` | **Untouched** | Hard invariant (D-10) |
| `SonicMerge/Services/AudioMergerService.swift` | **Untouched** | Hard invariant (D-10) |
| `SonicMergeTests/MixingStationViewModelTests.swift` | Possibly touched | Only if reorder API usage changes; no new VM surface so likely untouched |

**No new Swift packages. No new design tokens. No new ViewModel API.**

---

## Phase 7 Invariants — Status

| Invariant | Status in this refactor |
|---|---|
| No ViewModel / service changes | **Respected** (D-10) |
| Single Section + `.onMove` for reorder | **Superseded.** The current `MergeTimelineView` actually renders four `List { Section { ... } }` blocks (trust strip, SEQUENCE header, clip `ForEach` with `.onMove`, OUTPUT card). This refactor replaces the entire `List` with a single `ScrollView { LazyVStack { ... } }` composition. The four visual regions remain (trust strip / sequence header / clip column / output card) but now as plain sibling views in the `LazyVStack`, not `List` Sections. `.onMove` is replaced by `.draggable`/`.dropDestination` **only on clip rows**. The plan phase must validate no reorder regression with a prototype spike (R-01). |
| iOS 17 minimum with `#available(iOS 18, *)` guards for MeshGradient | **Respected** — no MeshGradient changes; existing guards preserved |
| Max 2 blur layers per screen | **Respected** — this refactor adds 0 blur layers |
| Zero new tokens beyond what Phase 6/7 defined | **Strengthened** — this refactor adds 0 tokens |
| Forbidden font weights (`.heavy`, `.bold`, `.medium`, `.black`) | **Respected** — only `.regular` and `.semibold` used in new/modified code |

---

## Component Contracts

### Compact Timeline Geometry

Density target: 4–5 clips simultaneously visible on an iPhone 15/16 (screen height ~852pt, usable content area ~620pt after toolbar + output card + safe areas, once the trust banner is hidden).

**Spacing table (delta from Phase 7):**

| Property | Phase 7 | New | Rationale |
|---|---|---|---|
| Inter-row vertical gap (card↔junction, junction↔card) | 24pt (`Spacing.lg`) | **12pt** | User requirement: −50% vertical spacing |
| Clip card internal vertical padding | 16pt | **10pt** | Tighter card breathing room |
| Clip card internal horizontal padding | 16pt | **14pt** | Slight tightening |
| Clip card corner radius | 24pt (`Radius.card`) | **24pt** (unchanged) | User said 24–28pt; keeping the token avoids a breaking change |
| Waveform thumbnail | 100pt × 52pt | **96pt × 44pt** | −15% area, preserves 11:5 ratio |
| Waveform inner corner radius | 10pt | **8pt** | Proportional |
| Play pill | 44pt × 44pt | **44pt × 44pt** | HIG floor — do not shrink |
| JunctionView capsule height | n/a | **28pt** (44pt tap target via `.contentShape`) | New component |
| JunctionView horizontal padding | n/a | **12pt** | New component |

**Computed card height:** max(waveform 44pt, play 44pt) + 2 × 10pt padding = **~64pt card** + 12pt gap + 28pt junction + 12pt gap = **~116pt per clip+junction row**.

Five full clip+junction rows + 1 trailing card = 5 × 116 + 64 ≈ **644pt** — exceeds the 620pt budget, but scrolling begins at clip 5, which matches the "4–5 clips simultaneously visible" target.

### `JunctionView` (new)

**File:** `SonicMerge/Features/MixingStation/JunctionView.swift`

**Public API:**

```swift
struct JunctionView: View {
    let transition: GapTransition       // existing model type
    let onTransitionChange: (GapTransition) -> Void
    let onInsertClip: () -> Void
    // ... body uses the two callbacks via a native Menu
}
```

**Visual:**

| Property | Value |
|---|---|
| Container | `Capsule().fill(semantic.surfaceCard).overlay(Capsule().stroke(semantic.accentGlow@0.35, lineWidth: 1))` |
| Height | 28pt |
| Horizontal padding | 12pt |
| Tap target | 44pt (`.contentShape(Rectangle())` + `.frame(minWidth: 72, minHeight: 44)`) |
| Label composition | `HStack(spacing: 6) { Image(systemName: symbol); Text(labelText) }` |
| Symbol | `clock` when transition is a gap; `arrow.triangle.merge` when crossfade |
| Label text | `"0.5s"` / `"1.0s"` / `"2.0s"` / `"Cross"` |
| Label typography | `.caption.semibold` |
| Tint | `accentAction` — applied to both symbol and text |
| Alignment on spine | Centered horizontally; capsule opaque card fill occludes the 1pt spine behind |

**Menu content (native iOS `Menu { ... } label: { capsule }`):**

```
Transition                        ← .titleKey header (optional)
├── ✓ 0.5 seconds              [clock]
├──   1.0 seconds              [clock]
├──   2.0 seconds              [clock]
├── ─────────────
├──   Crossfade                [arrow.triangle.merge]
├── ─────────────
└──   Insert clip here         [plus]
```

Implementation uses a `Picker` bound to a transient `@State` to get free checkmark behavior, followed by `Divider()` and two `Button` rows (Crossfade, Insert clip here):

```swift
Menu {
    Picker("Transition", selection: $binding) {
        Label("0.5 seconds", systemImage: "clock").tag(GapTransition.gap(0.5))
        Label("1.0 seconds", systemImage: "clock").tag(GapTransition.gap(1.0))
        Label("2.0 seconds", systemImage: "clock").tag(GapTransition.gap(2.0))
    }
    Divider()
    Button {
        binding = .crossfade(0.5)
    } label: {
        Label("Crossfade", systemImage: "arrow.triangle.merge")
    }
    Divider()
    Button(action: onInsertClip) {
        Label("Insert clip here", systemImage: "plus")
    }
} label: {
    capsule
}
```

**Haptic:** `.sensoryFeedback(.impact(weight: .light), trigger: transition)` — keyed off the **outer `transition` prop** (the VM round-trip value), NOT the transient `@State` `binding` used internally by the Picker. This prevents a double-fire (local flip + re-render). Implementation pattern: `@State private var binding` seeds from `transition` and on change calls `onTransitionChange(binding)`; the `.sensoryFeedback` modifier watches `transition`, which only updates after the parent re-renders with the new value.

**"Insert clip here" flow (no new ViewModel surface):**

The existing ViewModel reorder method is `viewModel.moveClip(fromOffsets: IndexSet, toOffset: Int)` (see `MixingStationViewModel.swift:169`). The existing import path always appends newly imported clips at the end of `viewModel.clips`.

1. `onInsertClip()` callback fires with the junction's target index `insertAt` (e.g., `2` for the junction between clips 1 and 2)
2. `MergeTimelineView` captures the current `oldCount = viewModel.clips.count` into `@State var pendingInsert: (index: Int, oldCount: Int)?`
3. `MergeTimelineView` triggers the existing `.fileImporter` (same sheet the toolbar `+` uses)
4. `.onChange(of: viewModel.clips.count)` observer fires when `viewModel.clips.count > pendingInsert.oldCount`
5. The newly imported clips occupy the **tail** positions — specifically the range `pendingInsert.oldCount ..< viewModel.clips.count`. Build `IndexSet(pendingInsert.oldCount ..< viewModel.clips.count)` as `fromOffsets`
6. Call `viewModel.moveClip(fromOffsets: tailRange, toOffset: pendingInsert.index)`
7. Clear `pendingInsert = nil`

**Guard:** the `.onChange` observer must no-op if `pendingInsert == nil` (prevents double-firing when the user imports via the toolbar `+` instead). The observer must also no-op if the delta is zero or negative (import cancelled, or user deleted a clip between tap and import-completion).

**Fallback path (if the above orchestration proves fragile in the plan phase):** remove the "Insert clip here" action from the Menu. The toolbar `+` still works as append-only; users drag-reorder after import. Plan phase owns this decision based on prototype spike outcome.

### Timeline Spine (`TimelineSpineView`) — refinement

| Property | Phase 7 | New |
|---|---|---|
| Width | 2pt | **1pt** |
| Fill | `accentGlow@0.35` flat | **`LinearGradient(stops: [.init(color: accentGlow@0.55, location: 0.0), .init(color: accentGlow@0.0, location: 1.0)], startPoint: .top, endPoint: .bottom)`** |
| Per-row `.background(alignment: .leading)` pattern | preserved | preserved — still the only layout-stable approach (holds for LazyVStack too) |
| Leading inset | 60pt | 60pt |
| Visibility rule | `clips.count >= 2` | `clips.count >= 2` |
| `reduceTransparency` top stop | 0.35 → 0.55 | 0.55 → **0.75** |
| `.accessibilityHidden(true)` | yes | yes |

### Reorder Mechanism — `List.onMove` → `LazyVStack` + drag/drop (D-08)

**Why the change:** User explicitly requires no 3-line reorder handles. SwiftUI `List.onMove` requires edit mode, which forces the handles. There is no public API to hide them.

**New mechanism:**

- Replace the outer `List { Section { ForEach { ... } } }` with `LazyVStack(spacing: 0) { ForEach { ... } }` inside a `ScrollView`
- Each clip row becomes `.draggable(clip.id) { dragPreview }` where `dragPreview` is a lightweight scaled-down rendering of the row
- Each row becomes a `.dropDestination(for: UUID.self) { droppedIDs, location in ... }` that computes source/destination and calls the existing ViewModel reorder method
- Swipe-to-delete: the current implementation uses `.swipeActions` on each `List` row (`MergeTimelineView.swift:82-88`), which is a **`List`-only modifier** — it stops working the moment we move to `LazyVStack`. `MergeSlotRow` also exposes Delete via a context menu (`MergeSlotRow.swift:64-72`), so delete is never lost entirely. Migration options: (1) add a custom trailing-swipe gesture on each row to restore the swipe-delete UX, (2) accept that delete is now context-menu-only. **Recommended default: option 1** (preserves muscle memory). Plan phase owns the final choice.

**Reorder animation:** `.animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78), value: viewModel.clips.map(\.id))` on the `LazyVStack`.

**Haptics preserved:** pickup + drop haptics via `.sensoryFeedback(.impact(weight: .medium))` on drag lift and `.impact(weight: .light)` on drop.

### Toolbar Restructure (D-03)

**Left side (unchanged placement, unchanged symbol):**
- `ToolbarItem(placement: .topBarLeading)` → Import button, `Label("Import", systemImage: "plus")`

**Right side (new order, three items).** Note on source-vs-visual order: SwiftUI renders `.topBarTrailing` items right-to-left from source order. The current code's source order is Appearance → Export → Denoise, producing visual order Denoise | Export | Appearance. The new source order below (Denoise → Export → `•••`) produces visual order `•••` | Export | Denoise — i.e., `•••` sits at the far right corner. If the intent is to keep Denoise visually adjacent to the Import button on the left edge (nav-bar norm), accept that arrangement; if the intent is `•••` at the far right as the canonical "more" position, this layout is correct. The diagram below (`[+]` left, Denoise / Export / `•••` right) is the intended visual.

```swift
ToolbarItem(placement: .topBarTrailing) {
    // Denoise — unchanged
    Button { navigateToCleaningLab() } label: {
        Label("Denoise", systemImage: "wand.and.sparkles")
    }
    .disabled(viewModel.clips.isEmpty)
}
ToolbarItem(placement: .topBarTrailing) {
    // Export — unchanged
    Button { showExportSheet = true } label: {
        Label("Export", systemImage: "square.and.arrow.up")
    }
    .disabled(viewModel.clips.isEmpty || viewModel.isExporting)
}
ToolbarItem(placement: .topBarTrailing) {
    // NEW: overflow menu — contains Appearance picker
    Menu {
        Picker("Appearance", selection: $themePreferenceRaw) {
            Text("System").tag(ThemePreference.system.rawValue)
            Text("Light").tag(ThemePreference.light.rawValue)
            Text("Dark conveyor").tag(ThemePreference.dark.rawValue)
        }
    } label: {
        Label("More options", systemImage: "ellipsis.circle")
    }
}
```

**Net delta vs current `MixingStationView`:** the old `paintpalette` top-bar-trailing item is deleted; the new `ellipsis.circle` Menu wraps the same Appearance `Picker` currently inside the `paintpalette` Menu. All other items migrate unchanged.

### Trust Banner First-Launch Gating (D-06)

**Intent clarification.** Today the `LocalFirstTrustStrip` lives inside `MergeTimelineView` (currently `MergeTimelineView.swift:22`, wrapped in its own Section). On a **fresh install** with zero clips, the app renders the empty state via `MixingStationView`, so `MergeTimelineView` isn't mounted and the banner is already invisible — that's the status quo. The problem this gate fixes is that **after the user has ever imported**, the banner keeps showing at the top of the populated timeline on every subsequent launch.

So the gate's purpose: hide the banner once the user has imported at least once, **and** keep it hidden permanently across launches.

**New storage:**

```swift
@AppStorage("sonicMerge.hasImportedFirstClip") private var hasImportedFirstClip: Bool = false
```

**Chosen host view:** `MergeTimelineView` — the banner stays where it currently is. This keeps the change local and avoids moving the banner across view boundaries.

**Render rule (inside `MergeTimelineView.body`, replacing the current unconditional `Section { LocalFirstTrustStrip() }`):**

```swift
if !hasImportedFirstClip {
    LocalFirstTrustStrip()
        .padding(.vertical, SonicMergeTheme.Spacing.sm)
}
```

(No Section wrapper once we migrate to `LazyVStack` — the banner is a plain sibling view.)

**Flip rule:** inside `MixingStationView` (since that's where the `@AppStorage` ideally co-locates with import orchestration), add:

```swift
.onChange(of: viewModel.clips.count) { _, newCount in
    if newCount > 0 && !hasImportedFirstClip {
        hasImportedFirstClip = true
    }
}
```

Both views read the same `@AppStorage` key — the flag is a single source of truth. Once true, it persists across launches and the banner never returns.

**What happens to the "Private by design" copy:** out of scope for this spec. It can reappear in a future "About" sheet accessed via the `•••` menu. No stub or placeholder added in this refactor.

### Empty State Restyle (D-07)

**File:** `MixingStationView.swift` — `emptyState` computed var.

```swift
private var emptyState: some View {
    VStack(spacing: SonicMergeTheme.Spacing.md) {
        Image(systemName: "waveform")
            .font(.system(size: 48))
            .foregroundStyle(Color(uiColor: semantic.accentAction))
            .shadow(
                color: Color(uiColor: semantic.accentGlow).opacity(0.35),
                radius: 20, x: 0, y: 0
            )
            .accessibilityHidden(true)
        Text("No clips yet")
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .foregroundStyle(Color(uiColor: semantic.textPrimary))
        Text("Tap + to add audio files\nor drop them here")
            .font(.system(.body, design: .rounded))
            .foregroundStyle(Color(uiColor: semantic.textSecondary))
            .multilineTextAlignment(.center)
        Button {
            showDocumentPicker = true
        } label: {
            Label("Import Audio", systemImage: "plus.circle.fill")
        }
        .buttonStyle(PillButtonStyle(variant: .filled, size: .regular))
    }
}
```

Only the shadow and the body text change. Everything else is preserved from Phase 7.

---

## Copywriting Contract

| Element | Copy | Delta |
|---|---|---|
| Junction capsule (gap) | `"0.5s"` / `"1.0s"` / `"2.0s"` | Same as Phase 7 gap labels |
| Junction capsule (crossfade) | `"Cross"` | New — shorter than Phase 7 "Crossfade" to fit the compact capsule |
| Junction menu — section | (no header) | Native Picker groups the 3 gap items implicitly |
| Junction menu — gap items | `"0.5 seconds"` / `"1.0 seconds"` / `"2.0 seconds"` | Full-word form for VoiceOver clarity |
| Junction menu — crossfade | `"Crossfade"` | Unchanged |
| Junction menu — insert | `"Insert clip here"` | New |
| Toolbar ••• accessibility | `"More options"` | New |
| Empty state body | `"Tap + to add audio files\nor drop them here"` | Changed from `"Tap Import to add audio files"` |
| Trust banner | Copy unchanged — just gated on first launch | — |

---

## Iconography

| Usage | Symbol | Size / weight |
|---|---|---|
| Junction — gap | `clock` | `.caption.semibold` |
| Junction — crossfade | `arrow.triangle.merge` | `.caption.semibold` |
| Junction menu — insert | `plus` | system-default (menu) |
| Toolbar overflow | `ellipsis.circle` | toolbar default |
| Empty-state icon | `waveform` | 48pt (unchanged) |
| All other toolbar / card icons | unchanged from Phase 7 | — |

**Explicit non-goal:** no emoji. Entire app is SF Symbols only.

---

## Accessibility Contract

| Target | Rule |
|---|---|
| JunctionView capsule | `.accessibilityLabel("Transition: \(currentLabel). Double-tap to change.")`, `.accessibilityAddTraits(.isButton)` |
| JunctionView Menu items | Native `Picker` semantics inherit `.isSelected` for the current choice automatically; non-Picker `Button` rows (Crossfade, Insert) use their Label text |
| Clip card with reorder | `.accessibilityActions { Button("Move up") { vm.moveClip(fromOffsets: [i], toOffset: i - 1) }; Button("Move down") { vm.moveClip(fromOffsets: [i], toOffset: i + 2) } }` — **required** because we removed the visible drag handle. Note: SwiftUI `.moveClip(fromOffsets:toOffset:)` uses the iOS "move before this offset" semantics, so moving down from index `i` targets `i + 2` (not `i + 1`). |
| Timeline spine | `.accessibilityHidden(true)` |
| Toolbar `•••` | `.accessibilityLabel("More options")` |
| Empty-state icon | `.accessibilityHidden(true)` (heading conveys meaning) |
| Empty-state body text | Standard Text a11y (unchanged) |
| Dynamic Type | All text uses SwiftUI system roles. Waveform thumbnail remains fixed at 96×44 (decorative). JunctionView capsule can grow in height with Dynamic Type — confirm via `.xxxLarge` test; acceptable to cap label text to 1 line with `.lineLimit(1)` if overflow threatens the capsule shape. |
| Minimum touch target | 44pt — enforced on play pill, toolbar buttons, and JunctionView (via `.contentShape` + `.frame(minHeight: 44)`) |
| Contrast | No new color combinations; all inherited Phase 6 tokens pass AA at the new typography sizes |

**Reduce Motion:**

- `LazyVStack` reorder animation suppressed (`.animation(nil, ...)` branch)
- JunctionView: no custom animation; native Menu open/close is system-controlled
- Empty-state glow: static (non-animated) → no-op

**Reduce Transparency:**

- Spine top stop: 0.55 → 0.75 (defined in spine contract)
- JunctionView capsule stroke: 0.35 → 0.55
- No other transparency in the refactored surface

---

## Risks & Spikes the Plan Phase Must Handle

### R-01 — Reorder Mechanism Regression (HIGH)

**Risk:** `List.onMove` was locked in by Phase 7 to avoid a known reorder crash. Replacing with `LazyVStack` + `.draggable`/`.dropDestination` is architecturally different, but it's still a different drag API on a mutable collection. If iOS 17 has quirks with `.dropDestination` reordering of identifiable items in a `LazyVStack`, we could reintroduce instability under a different stack trace.

**Mitigation:** Plan phase must include a prototype spike — implement the new reorder in isolation, test with 3+ clips, verify no crash on repeated reorder + quick drop cancellations.

**Fallback:** If the spike reveals instability, revert to `List.onMove` and accept the 3-line handles as the cost of stability. Document the decision in the phase SUMMARY.

### R-02 — Swipe-to-Delete Loss (MEDIUM)

**Risk:** `List` provides swipe-to-delete for free; `LazyVStack` does not. Users may have muscle memory for swipe-delete.

**Mitigation options the plan phase picks from:**
1. Add a custom swipe gesture to each `MergeSlotRow` — moderate code, best UX continuity
2. Rely on context menu "Delete Clip" as the only delete path — simplest code, a UX regression
3. Add a `.trailingSwipeActions` equivalent via a third-party pattern — not preferred (no new deps rule)

**Recommended default:** option 1 (custom swipe gesture) — maintains existing UX.

### R-03 — Insert-Clip-Here Async Orchestration (MEDIUM)

**Risk:** Inserting at a junction index requires observing import-completion, computing new indices, and reordering — all from the view, with no new VM surface. Races or double-fires could produce wrong ordering.

**Mitigation:** Guard the `.onChange(of: viewModel.clips.count)` observer with a `pendingInsert: (index: Int, oldCount: Int)?` gate so the reorder fires at most once per import session.

**Binary spike exit criterion (decided during plan phase):** implement the flow and run 5 trial insertions each at a different junction index with 3 files per import. **Pass** if all 5 trials land clips at exactly the intended index, no clip duplication, no observer misfire on a subsequent toolbar-`+` import. **Fail** (drop "Insert clip here" from the Menu) if any trial produces wrong ordering, duplicate insertions, or an observer fire during unrelated toolbar imports.

### R-04 — Trust Banner Flag Desync (LOW)

**Risk:** `@AppStorage` flag is device-local. If user reinstalls or resets, banner returns — acceptable and arguably correct behavior.

**Mitigation:** None needed. Document behavior in phase SUMMARY.

### R-05 — JunctionView Dynamic Type Overflow (LOW)

**Risk:** At `.xxxLarge` sizing, `"1.0s"` + `clock` symbol may not fit inside a 28pt capsule.

**Mitigation:** If unit testing reveals truncation, allow the capsule to grow vertically (remove fixed height; rely on `.padding` instead). Label text already uses `.lineLimit(1)`.

---

## Open Questions (Deliberately Deferred)

These are NOT part of this spec; noted so they don't get lost:

- Where the "Private by design" copy lives after first launch (About sheet? Settings? Small footer in `•••`?)
- Whether the Junction menu should offer a custom-ms slider for power users (today: fixed 0.5 / 1.0 / 2.0)
- Whether to badge the `•••` overflow when a non-default Appearance is active
- Migration: what happens to Phase 7's `MergeOperatorKind.plus` case — deleted entirely, or kept as unused case for future? (Recommend delete.)

---

## Acceptance Criteria

The refactor is complete when all of the following hold on an iPhone 15/16 simulator (iOS 17 and iOS 18) in light mode:

1. **Density:** With 5+ imported clips, the user sees ≥4 clip cards + ≥3 junctions simultaneously without scrolling.
2. **Junctions:** Each junction renders as a single capsule showing the current transition. Tapping opens a native iOS Menu with gap / crossfade / insert options. Changing via the menu updates the transition immediately with a light haptic.
3. **Spine:** The spine is 1pt thick with a visible top-to-bottom indigo→transparent gradient. Still hidden when `clips.count < 2`.
4. **Toolbar:** `+` on the left. Three items on the right, left-to-right: Denoise, Export, `•••`. The `•••` Menu contains the Appearance picker with three options. No `paintpalette` icon in the top bar.
5. **Trust banner:** Visible only on a fresh install with zero imported clips. Hides permanently after the first successful import. Does not return on subsequent launches.
6. **Empty state:** Shows waveform icon with visible indigo halo, heading, body with `\nor drop them here`, and Import CTA.
7. **Reorder:** Long-press on any clip card lifts the card, dragging over another card reorders them on drop. No 3-line handles visible at any time. No reorder crash across the following exercises (all part of the R-01 spike): (a) 10 consecutive successful reorders with 5 clips; (b) reorder during an active drop animation (start second drag before first animation settles); (c) rapid drag cancel (release outside any drop target) repeated 5 times; (d) reorder with exactly 2 clips (swap). Any crash or state-desync on any scenario fails the spike and triggers the `List.onMove` fallback.
8. **Accessibility:** VoiceOver announces transition state on each junction capsule; Dynamic Type at `.xxxLarge` keeps all text readable; Reduce Motion suppresses the reorder spring animation; Reduce Transparency raises the spine top stop to 0.75.
9. **No regressions:** Import, export, denoise navigation, theme picker (now inside `•••`), swipe-to-delete-or-equivalent all work identically to the pre-refactor behavior.
10. **Invariants preserved:** No ViewModel or service diff. Zero new design tokens. Zero new Swift package dependencies. Zero new blur layers.

---

## Approval

- [ ] Design approved by user
- [ ] Spec reviewer approved
- [ ] Ready for writing-plans
