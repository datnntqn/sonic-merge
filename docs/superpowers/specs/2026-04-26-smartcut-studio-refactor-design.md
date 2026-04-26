# Smart Cut Studio Refactor — Design Spec

**Status:** Draft (brainstorming phase complete; awaiting spec review + user read-through)
**Date:** 2026-04-26
**Owner:** DATNNT
**Implements:** Comprehensive UI/UX refactor of the Smart Cut tab in Cleaning Lab and the Edit Filler List sheet to a "Modern Spatial AI Studio" aesthetic — glassmorphic summary card, single-column wide bento cards for filler groups + a pauses card, tap-to-detail-sheet for occurrences, unified tag-capsule pool for the filler library editor, color audit fixing system-blue links to Deep Indigo @ 50% opacity, pulsating saves badge, rolling-digit slider readout. **Visual layer only — no ViewModel, service, or model changes.**

---

## 1. Overview

The Smart Cut feature shipped its first UI in `fbdf722` and got a partial polish pass in the never-fully-implemented `smartcut-premium-ui` brief. The view layer today is a single `SmartCutCardView` rendering all states (idle, analyzing, results, applied, stale, error) inside one `SquircleCard`, with a sub-component `FillerListPanel` rendering category groups inside gray rounded rectangles using checkbox + chevron-collapse mechanics. The Edit Filler List sheet is a flat `List` with two sections (Default Library, Your Words) and a `TextField` row at the bottom for adding custom words.

The refactor replaces the entire view layer for these surfaces. Five interconnected changes:

1. **Glassmorphic Summary Card** at the top of the Smart Cut tab — frosted glass background, consolidates the section header (title + Reset link) with the stats line ("Found 7 fillers + 2 long pauses") and the saves badge into one focal panel. Saves badge gains a gentle scale-and-glow pulse.
2. **Single-column wide bento cards** for each filler category and one for "Long Pauses" — 28pt continuous squircle, soft Deep Indigo shadow, white card surface. Tapping the card opens a detail sheet; the card itself shows: word, occurrence count, savings, group toggle. Toggle-off state: bold + strikethrough text in Deep Indigo, card opacity 0.40, shadow softened.
3. **Detail sheet** (`.sheet` presentation) for occurrence drill-in — glassmorphic background, occurrence rows as wide capsule pills (▶ preview · excerpt · timestamp · checkbox). Per-occurrence enable/disable lives here.
4. **Pause threshold slider** replacing the `Stepper` — continuous 1.0–3.0s range, rolling-digit readout via `contentTransition(.numericText())`, light haptic at 0.25s snap points while dragging, live "saves 0:31" recomputation.
5. **Edit Filler List → unified tag-capsule pool** — frosted-glass capsules in a wrap layout, every capsule has a Deep Indigo ✕. ✕ on a default-library word toggles it off (capsule stays in place, dimmed + line-through, ✕ hidden in the off state — tap capsule body to re-enable). ✕ on a custom word permanently deletes it. Add input is a capsule-shaped TextField at the bottom; submitting on Enter creates a new custom-word capsule.

Plus a small color audit: system-blue links ("Reset" inside the summary card; "+ Edit filler list" entry-point) re-tinted to Deep Indigo @ 50% opacity. Original/Cleaned `SegmentedPill` is already correct — no change.

The floating `Apply Cuts` button (`FloatingActionBar` chassis) is **unchanged**.

## 2. Goals and non-goals

**Goals:**
- Replace `SmartCutCardView`, `FillerListPanel`, and `EditFillerListSheet` with new components living in `SonicMerge/Features/SmartCut/Views/Studio/`. Old files retired in the same commit chunk that ships the replacement.
- Glassmorphic Summary Card with `ultraThinMaterial` background, 1pt Deep Indigo @ 18% border, 24pt corner radius. Content: ✨ "SMART CUT SUMMARY" eyebrow label · stats line · saves badge · Reset link top-right.
- Saves badge pulse: scale `1.0 ↔ 1.04` over ~1.6s eased, lime green outer glow shadow synced (alpha `0.40 ↔ 0.65`), driven by a single `TimelineView` (Phase 11 pattern). Pulse only when `enabledSavings > 0`; static otherwise. Suppressed when `accessibilityReduceMotion` is on.
- Single-column wide bento cards: 28pt continuous squircle, white `surfaceCard` fill, soft shadow (16pt radius, 6pt y, Deep Indigo @ 0.10 opacity). Card content laid out horizontally: leading column (occurrence count eyebrow + word) · trailing column (saves chip + group toggle).
- Group toggle: a small lime green capsule (when on) or outline capsule (when off) on the trailing edge. Tapping the toggle flips the group on/off without opening the detail sheet. Tapping anywhere else on the card opens the sheet.
- Toggle-off card state: text bold weight + strikethrough + Deep Indigo color; card opacity 0.40; shadow softened (radius 6, alpha 0.04).
- Pauses bento card: same chassis. Trailing column has the slider + "saves 0:31" rolling-digit readout. No tap-to-sheet (no occurrences).
- Detail sheet (`.sheet` presentationDetents `.medium` + `.large`): glassmorphic background. Header: word title + total saves. Each occurrence row is a capsule pill containing ▶ play (filled/outline based on whether currently previewing) · excerpt (line-limited) · timestamp · per-occurrence checkbox. Footer with overall toggle ("Disable all" / "Enable all").
- Pause slider: SwiftUI `Slider(value:in:step:)` with `in: 1.0...3.0, step: 0.25`, `.tint(semantic.accentAction)`. Live readout uses `Text("\(formatThreshold(pauseThreshold))").contentTransition(.numericText())`. Light haptic (`UIImpactFeedbackGenerator(style: .light)`) fires on each step change via `.onChange(of: pauseThreshold)`.
- Edit Filler List unified pool: one section, all capsules wrap-flowed via `Layout` or `FlowLayout`-equivalent. Capsule chrome: `ultraThinMaterial` background, 1pt Deep Indigo border @ 20% opacity, 14pt corner radius. Default-on capsule: full opacity. Default-off: opacity 0.55, line-through, ✕ icon hidden — tap capsule body to re-enable. Custom: same chrome as default-on plus a Deep Indigo ✕ icon trailing; tapping ✕ permanently deletes.
- Add input: capsule-shaped `TextField` matching capsule chrome but with a leading "+" icon and placeholder "Add a word…". Submit on `.onSubmit` creates a new custom capsule with `.spring(response: 0.35, dampingFraction: 0.7)` insertion animation.
- Color audit: replace any `Color.blue` / `Color.accentColor` (where the system tint defaults to blue) on Reset / "+ Edit filler list" / link affordances with `Color(uiColor: semantic.accentAction).opacity(0.5)`.
- iOS 17 baseline preserved; iOS 18 features (e.g., `MeshGradient` if used in a frosted background) behind `#available` guards (Phase 11 pattern).
- Accessibility: every interactive surface has a clear `accessibilityLabel` + `accessibilityHint`; toggle-off cards announce "disabled, double-tap to enable"; saves badge pulse pauses on `accessibilityReduceMotion`; frosted glass falls back to opaque card on `accessibilityReduceTransparency`.

**Non-goals (deferred):**
- ViewModel / service / model changes. `SmartCutViewModel`, `SmartCutService`, `FillerLibrary`, `EditList`, `FillerEdit`, `PauseEdit` are untouched.
- A/B player audio cross-feed plumbing (separate work; carryover from Smart Cut original review).
- Apply Cuts button visual tweak — already shipped via `FloatingActionBar`.
- Smart Cut tab/AI Denoise tab top selector (the `SegmentedPill` parent in Cleaning Lab) — keep as-is.
- Per-occurrence reorder, drag-to-merge, multi-select. The detail sheet keeps the simple 1:1 enable/disable model.
- Persisting last-used pause threshold across app launches.
- Persisting last-active detail sheet across navigation.
- Snapshot tests / UI tests for the new components. Visual changes verified by manual device pass on iPhone 17 Sim (Phase 11 baseline).
- Animating the existing AI Denoise / Smart Cut top tab transition.
- Dark mode visual audit beyond what `semantic` tokens already provide. Spot-check only.

## 3. User journey

### Smart Cut tab — results state (the focal flow)

1. User runs Smart Cut → recognizer completes → state advances to `.results`. The Smart Cut tab content renders:
   - Top: **Glassmorphic Summary Card** — eyebrow label "✨ SMART CUT SUMMARY", stats line "7 fillers + 2 long pauses", **pulsing lime saves badge** "saves ~31s", "Reset" link top-right in Deep Indigo @ 50%.
   - Below: **Original/Cleaned `SegmentedPill`** (existing chrome — Deep Indigo selected = Original; Lime "Cleaned" once Apply ships).
   - Below: **Bento card list** (single-column) — first three cards are filler groups, last card is "⏱ Long Pauses". Each filler card: occurrence-count eyebrow, word label, trailing saves chip + group toggle. Pauses card: slider + saves readout.
   - Bottom: floating **Apply Cuts** action bar (existing).

2. User taps the "you know" card body → `.sheet` opens at `.medium` detent.
   - Sheet header: "you know · 3 occurrences · saves ~6s" with a "Disable all" trailing link.
   - Three occurrence rows as wide capsules: ▶ · "…know is that you know…" · "0:20" · ☑.
   - Per-occurrence checkbox toggles enable/disable for that instance only. Saves badge in the parent summary card recomputes via `contentTransition(.numericText())`.

3. User taps the group toggle on the "like" card (without opening sheet) → entire group toggles off. Card body fades to 0.40 opacity, text bolds + strikes through + colors to Deep Indigo, savings chip dims, shadow softens. Summary card's "saves ~31s" rolls down to reflect the new total.

4. User drags the pause slider from 1.5s to 2.0s.
   - Each 0.25s step fires a light haptic.
   - "Threshold: 2.0s" digit rolls smoothly via `.contentTransition(.numericText())`.
   - "saves 0:18" updates live (model recomputes pause set per current threshold — already supported by `SmartCutViewModel.setPauseThreshold` from `scp-t2`).
   - Summary card saves badge re-rolls to reflect the change.

5. User taps the "+ Edit filler list" link (Deep Indigo @ 50%) below the bento cards → Edit Filler List sheet opens.

### Edit Filler List sheet

1. User sees a single section: "ALL FILLER WORDS" eyebrow, then a wrap-flow grid of capsules. Default-on words appear first (full opacity). Default-off words intermix with default-on (dimmed + line-through, no ✕). Custom words appear at the end with a Deep Indigo ✕ trailing.

2. User taps a default-off capsule body → re-enabled, opacity returns to 1.0, line-through removed; spring animation.

3. User taps the ✕ on a default-on capsule → toggles off (opacity 0.55, line-through, ✕ hidden); spring animation.

4. User taps the ✕ on a custom-word capsule → permanent delete; capsule animates out (`.scale + .opacity` transition, 0.25s).

5. User taps the add-input field → keyboard rises, types "literally", taps Return → new custom capsule slides in next to existing custom capsules; input clears, ready for next entry.

## 4. Architecture

### 4.1 New file structure

All new view files live under `SonicMerge/Features/SmartCut/Views/Studio/`. The "Studio" subfolder names are explicit so the Phase boundary is searchable. Files:

| File | Purpose |
|------|---------|
| `Studio/SmartCutStudioContainer.swift` | Top-level view replacing the body of `SmartCutCardView`. Owns the state-machine switch (idle/analyzing/results/applied/stale/error) and renders one of: idle/processing scaffolds (kept simple — just a centered orb + status text + buttons; no glass card) for non-results states; the studio layout for `.results`/`.applied`/`.stale`. |
| `Studio/StudioSummaryCard.swift` | Glassmorphic summary card. Renders eyebrow, stats line, pulsating saves badge, Reset link. |
| `Studio/StudioPulseSavesBadge.swift` | The pulsating saves badge. `TimelineView`-driven scale + glow modulation. Reused from the existing `SavesBadge` design language but with motion. |
| `Studio/StudioBentoCard.swift` | The single-column wide bento card. Generic — takes a leading view and a trailing view + a `disabled` flag for the toggle-off treatment. Used for both filler cards (driven by `FillerCategoryRow`) and the pauses card (driven by `PauseControlRow`). |
| `Studio/FillerCategoryRow.swift` | Card content for a filler category: count eyebrow, word, trailing saves chip + group toggle, tap surface for opening the detail sheet. |
| `Studio/PauseControlRow.swift` | Card content for the pauses card: ⏱ icon, slider, rolling-digit threshold readout, saves chip. |
| `Studio/FillerOccurrenceSheet.swift` | The detail sheet. Header (title + total saves + disable-all link), wrap-list of occurrence rows, capsule-pill row component. |
| `Studio/StudioGlassChrome.swift` | Reusable view modifiers / chrome views: `glassCardBackground()`, `frostedCapsule()` — keep visual primitives in one place so a tweak propagates. |
| `Studio/EditFillerListStudioSheet.swift` | The unified-pool tag editor. Wrap layout for capsules; capsule input row; submit/delete logic on the existing `FillerLibrary` API. |
| `Studio/StudioFlowLayout.swift` | A simple SwiftUI `Layout` that wraps capsules into rows. Pure presentation; no behavior. |

Old files **retired** (moved to `Trash/` not deleted, so `git log --follow` keeps history; final cleanup commit removes them after a soak period):
- `SonicMerge/Features/SmartCut/SmartCutCardView.swift`
- `SonicMerge/Features/SmartCut/Views/FillerListPanel.swift`
- `SonicMerge/Features/SmartCut/Views/EditFillerListSheet.swift`

(Retirement strategy decided in plan, not spec. Spec just declares intent.)

### 4.2 ViewModel surface — no changes

Existing `SmartCutViewModel` API used as-is:
- `state`, `currentEditList`, `progress`, `enabledSavings`, `pauseThreshold`
- `analyze()`, `apply()`, `reset()`, `cancel()`
- `toggleCategory(_:enabled:)`, `toggleIndividual(_:enabled:)`, `togglePause(_:enabled:)`, `setPauseThreshold(_:)`
- The A/B selection (`abSelection`) and preview playback API.

Existing `FillerLibrary` API used as-is:
- `defaultOnWords`, `defaultOffWords`, `customWords`
- `enableDefault(_:)`, `disableDefault(_:)`, `addCustom(_:)`, `removeCustom(_:)`

The new view layer reads these and dispatches actions; nothing else.

### 4.3 Glass chrome primitives

Two new view modifiers, both sensitive to `accessibilityReduceTransparency`:

```swift
extension View {
    func studioGlassCard(cornerRadius: CGFloat = 24) -> some View
    func studioFrostedCapsule(cornerRadius: CGFloat = 14) -> some View
}
```

`studioGlassCard`:
- Default: `RoundedRectangle(cornerRadius:)` filled with `.ultraThinMaterial`, 1pt stroke `Color(uiColor: semantic.accentGlow).opacity(0.18)`, shadow radius 16 / y 6 / `Color(uiColor: semantic.accentGlow).opacity(0.10)`.
- `reduceTransparency`: replaces `.ultraThinMaterial` with `Color(uiColor: semantic.surfaceCard)`; stroke opacity 0.30.

`studioFrostedCapsule`:
- Default: capsule (or `RoundedRectangle(cornerRadius: 14)`) with `.ultraThinMaterial`, 1pt stroke `Color(uiColor: semantic.accentAction).opacity(0.20)`.
- `reduceTransparency`: replaces material with `surfaceCard`; stroke opacity 0.35.

### 4.4 Pulse animation primitive

`StudioPulseSavesBadge` implements:

```swift
TimelineView(.animation(minimumInterval: 1.0/60.0, paused: shouldPause)) { timeline in
    let t = timeline.date.timeIntervalSinceReferenceDate
    let phase = (sin(t * (2 * .pi / 1.6)) + 1) / 2  // 0...1 over ~1.6s
    let scale = 1.0 + 0.04 * phase
    let glowAlpha = 0.40 + 0.25 * phase
    badgeBody
        .scaleEffect(reduceMotion ? 1.0 : scale)
        .shadow(
            color: Color(uiColor: semantic.accentAI).opacity(reduceMotion ? 0.40 : glowAlpha),
            radius: 12, x: 0, y: 0
        )
}
```

`shouldPause = reduceMotion || enabledSavings == 0`. Single timeline pump per badge.

### 4.5 Bento card structure

`StudioBentoCard` is a generic chassis:

```swift
struct StudioBentoCard<Leading: View, Trailing: View>: View {
    let leading: Leading
    let trailing: Trailing
    let isDisabled: Bool
    let onTap: (() -> Void)?
    // ...
}
```

Renders an HStack with `leading` left, `Spacer()`, `trailing` right, applies `studioGlassCard` (with white opaque surface, not frosted, since the bento sits on the page background not on another glass surface). `isDisabled` triggers the strikethrough/bold/Deep Indigo treatment on text and the opacity dampening at the card level.

`onTap` is hooked to a `.contentShape(Rectangle())` overlay; the **trailing toggle button** intercepts taps before they reach the card. SwiftUI's hit test order honors the inner control; the rest of the card body is a single tap target.

### 4.6 Detail sheet

`FillerOccurrenceSheet` is a `.sheet`-presented view:
- Detents: `.medium` (default), `.large` (drag handle visible).
- Background: `.background(.ultraThinMaterial)` on the sheet root, with a `presentationBackground(.ultraThinMaterial)` modifier (iOS 16.4+).
- Header row: word title (large, bold) + total occurrences + total saves chip on the trailing edge. "Disable all" / "Enable all" link top-right.
- Body: `ScrollView` of capsule pill rows. Each row: `studioFrostedCapsule()` chrome containing ▶ button (filled.ai when this row is currently being previewed by the `previewPlayer`, outlined otherwise), excerpt `Text` (line-limited 1), timestamp text (secondary), checkbox.
- The 4-second preview behavior carries over from the existing `playWindow` — including the recently-added "stop in-flight player before starting new" guard. State (`previewPlayer`, `previewingId: String?`) lives in the sheet view.
- Footer (within sheet, not detent-pinned): empty.
- Dismissal: standard sheet dismiss; if a preview is mid-play, `onDisappear` stops it (existing pattern).

### 4.7 Pause slider

`PauseControlRow` content:

```swift
HStack(spacing: 12) {
    Image(systemName: "clock.badge.exclamationmark")
        .foregroundStyle(Color(uiColor: semantic.textSecondary))
    VStack(alignment: .leading, spacing: 6) {
        HStack {
            Text("Long Pauses").font(.caption).foregroundStyle(Color(uiColor: semantic.textSecondary))
            Spacer()
            Text(formatThreshold(viewModel.pauseThreshold))
                .font(.headline)
                .contentTransition(.numericText())
        }
        Slider(value: $viewModel.pauseThreshold, in: 1.0...3.0, step: 0.25)
            .tint(Color(uiColor: semantic.accentAction))
    }
    SavesChip(seconds: viewModel.totalPauseSavings)
        .contentTransition(.numericText())
}
.onChange(of: viewModel.pauseThreshold) { _, _ in
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
}
```

`SmartCutViewModel.setPauseThreshold(_:)` already recomputes `editList.pauses` synchronously (added in `scp-t2`). No service-layer change.

### 4.8 Edit Filler List unified pool

`EditFillerListStudioSheet`:
- Wrap layout via `StudioFlowLayout` (SwiftUI `Layout` protocol implementation, ~50 LoC).
- Iterates `library.allWords` (computed: `defaultOnWords + defaultOffWords + customWords` ordered by category origin). Each word renders as a `WordCapsule(word:)` view.
- `WordCapsule` chooses chrome based on `library.wordOrigin(_:)`:
  - `.defaultOn` → full opacity, no ✕, tap body → `library.disableDefault(word)`
  - `.defaultOff` → opacity 0.55 + line-through, no ✕, tap body → `library.enableDefault(word)`
  - `.custom` → full opacity, ✕ icon trailing, tap ✕ → `library.removeCustom(word)`; tap body → no-op
- Add input: a capsule-shaped `TextField` at the bottom.
  - Leading "+" icon (Deep Indigo).
  - `.submitLabel(.done)`, `.onSubmit { library.addCustom(text); text = "" }`.
  - Validation: trim whitespace, dedupe (already enforced by `library.addCustom`).
- Insertion animation: `withAnimation(.spring(response: 0.35, dampingFraction: 0.7))` around the add and remove operations.

`FillerLibrary` likely needs a small read-only helper: `wordOrigin(_ word: String) -> WordOrigin` returning one of `.defaultOn`, `.defaultOff`, `.custom`. If the existing API doesn't expose this, add it as a pure-read computed property on `FillerLibrary` — single-line, no behavior change. Spec deems this in-scope (presentation-supporting, not behavioral).

## 5. Visual specifications

### 5.1 Color tokens (no new tokens)

| Slot | Token | Hex | Usage |
|------|-------|-----|-------|
| Primary brand / borders / shadows | `semantic.accentAction` | #5856D6 | All Deep Indigo affordances |
| AI / saves / highlight | `semantic.accentAI` | #A7C957 | Saves badges, glow shadows, group toggle ON |
| Page background | `semantic.surfaceBase` | system | (Underneath everything; PremiumBackground stays) |
| Card surface | `semantic.surfaceCard` | white / very dark | Bento cards' opaque white fill |
| Primary text | `semantic.textPrimary` | system-near-black | Word labels |
| Secondary text | `semantic.textSecondary` | system-gray | Eyebrow labels, timestamps, slider title |
| Glass card border | `semantic.accentGlow` | #5856D6 | 18% opacity stroke on glass surfaces |

System blue (`Color.blue`, default `Color.accentColor` when system tint = blue) is **prohibited** in these views. Uses must be replaced with `accentAction` or `accentAction.opacity(0.5)`.

### 5.2 Dimensions

| Element | Value |
|---------|-------|
| Glass Summary Card corner radius | 24pt |
| Glass Summary Card padding | 16pt all sides |
| Bento card corner radius | 28pt |
| Bento card padding | 16pt vertical, 18pt horizontal |
| Bento card vertical gap | 12pt |
| Tag capsule corner radius | 14pt |
| Tag capsule padding | 5pt vertical, 12pt horizontal (8pt right when ✕ shown) |
| Saves chip corner radius | 12pt |
| Saves chip padding | 6pt vertical, 12pt horizontal |
| Section vertical spacing (Summary → Picker → Bento) | 12pt |

### 5.3 Animations

| Animation | Curve | Duration | Notes |
|-----------|-------|----------|-------|
| Saves badge pulse (scale) | sine via TimelineView | 1.6s period | Range 1.0…1.04. Halts on reduceMotion. |
| Saves badge pulse (glow) | sine via TimelineView | 1.6s period | Synced with scale. Range alpha 0.40…0.65. |
| Numeric content transition (saves, threshold) | `.numericText()` | system | Both `Text(saves)` and `Text(threshold)` use it. Suppressed on reduceMotion. |
| Bento card disable transition | `.spring(response: 0.30, dampingFraction: 0.75)` | ~0.5s | Opacity, color, strikethrough cross-fade. |
| Tag capsule add | `.spring(response: 0.35, dampingFraction: 0.70)` | ~0.5s | Scale + opacity insertion. |
| Tag capsule remove | `.spring(response: 0.30, dampingFraction: 0.80)` | ~0.4s | Scale + opacity removal. |
| Detail sheet present | system sheet animation | system | No customization. |
| Slider drag haptic | per 0.25s step via `.onChange` | n/a | UIImpactFeedbackGenerator, light. |

### 5.4 Typography

Use existing `SonicMergeTheme` font stack. Specific roles:

| Role | Style |
|------|-------|
| Card eyebrow ("3 OCCURRENCES", "⏱ LONG PAUSES") | `.caption2.weight(.semibold)`, secondary, all-caps |
| Card word label | `.title3.weight(.semibold)` |
| Saves chip text | `.subheadline.weight(.semibold).monospacedDigit()` |
| Slider threshold readout | `.headline.weight(.semibold).monospacedDigit()` |
| Summary stats line | `.subheadline`, secondary |
| Summary saves badge | `.headline.weight(.bold).monospacedDigit()` |
| Tag capsule text | `.subheadline` |
| Add-input placeholder | `.subheadline`, secondary |

## 6. Accessibility

- **VoiceOver labels:**
  - Bento filler card: "you know, 3 occurrences, saves 6 seconds, double-tap to view occurrences. Group toggle: enabled, double-tap to disable."
  - Group toggle separated as its own `accessibilityElement(children: .ignore)` with its own label so VoiceOver users can adjust without entering the sheet.
  - Tag capsule (default): "literally, double-tap to delete." (Custom) / "uh, default word, enabled, double-tap to disable." (Default-on) / "basically, default word, disabled, double-tap to enable." (Default-off).
  - Saves badge: "saves 31 seconds." `.accessibilityAddTraits(.updatesFrequently)` while user is dragging slider.
  - Pause slider: native SwiftUI Slider `accessibilityValue("\(viewModel.pauseThreshold) seconds")`.
- **Dynamic Type:** All `Text` uses semantic font roles, no fixed pt sizes. Bento card layout switches to vertical when `dynamicTypeSize >= .xxLarge` (test pass on iPhone 17 Sim).
- **reduceMotion:** Disables saves pulse, disables `.numericText()` content transition fallback, disables card disable spring (snaps).
- **reduceTransparency:** Both `studioGlassCard` and `studioFrostedCapsule` swap material for opaque surface.
- **High contrast (`legibilityWeight`):** Bold-state strikethrough applies regardless; line color follows text color so contrast is preserved.

## 7. iOS compatibility

- **Baseline: iOS 17.** All used APIs available:
  - `.contentTransition(.numericText())` → iOS 17+
  - `presentationBackground(.ultraThinMaterial)` → iOS 16.4+
  - `Slider(value:in:step:)` → iOS 13+
  - `Layout` protocol (for `StudioFlowLayout`) → iOS 16+
  - `TimelineView(.animation)` → iOS 15+
  - `.ultraThinMaterial` → iOS 15+
- **iOS 18 enhancements:** None needed; saves pulse uses standard TimelineView. If a future version wants `MeshGradient` accents on the summary card, gate behind `#available(iOS 18.0, *)` (Phase 11 pattern).

## 8. Testing strategy

Same as Phase 11: **no snapshot harness exists in this repo**, no UI test target dedicated to Smart Cut visual layer. Strategy:

- **Build verify per chunk** during plan execution.
- **Regression test suite** at the end (existing 53/58 baseline; 5 known failures from Phase 5/3/2 stubs unchanged).
- **Human device pass** on iPhone 17 Sim (iOS 26.2): the acceptance gate.
- **No new unit tests added.** ViewModel/service surface unchanged; existing tests cover that path. Pure-presentation refactors aren't unit-testable in this codebase's current setup.

## 9. Migration & deprecation

- `SmartCutCardView`: replaced by `SmartCutStudioContainer` in `CleaningLabView`'s `.tab(.smartCut)` branch. Old file deleted in the same chunk.
- `FillerListPanel`: deleted.
- `EditFillerListSheet`: deleted.
- `SavesBadge` (currently a private struct inside `SmartCutCardView.swift`): replaced by `StudioPulseSavesBadge`.
- Any call sites currently calling these views (none expected outside `CleaningLabView` and `SmartCutCardView` itself) are audited during plan execution.

## 10. Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Glass material on top of `PremiumBackground`'s mesh gradient looks muddy | Medium | High (defeats purpose) | Test on Sim early in Chunk 1; if muddy, override summary card to use opaque `surfaceCard` with stronger Deep Indigo border instead of material. |
| Bento card group toggle hit target conflicts with card-tap-opens-sheet | Medium | Medium (mis-tap risk) | Group toggle gets a 44pt minimum hit target via `.frame(minWidth: 44, minHeight: 44)`. Explicit `Button` keeps SwiftUI's hit-test order priority. Field test the gesture clarity. |
| Detail sheet preview ▶ overlap with multiple sheets stacked | Low | Low | Sheet's `onDisappear` stops the preview player (existing pattern in `FillerListPanel`). Carry over guard. |
| `StudioFlowLayout` proves too simplistic for RTL or wide-glyph words | Low | Low | Layout protocol implementation supports any direction by design. Validate in a Vietnamese/Arabic text run. |
| Removing `SmartCutCardView` breaks deep-link `handlePendingSmartCutOpenIfNeeded()` | Medium | Medium (regression) | Preserve the deep-link callsite — `SmartCutStudioContainer` exposes the same external API surface (focus/scroll-to behavior) that the deep-link relies on. Plan step has explicit verification. |
| Pulse animation on saves badge feels distracting | Medium | Low (subjective) | Configurable via single constant in `StudioPulseSavesBadge`. Easy revert. |

## 11. Open questions / future work

- **Detail sheet "Disable all" semantics:** does it call `viewModel.toggleCategory(_:enabled: false)`, or iterate per-occurrence? Plan decides; behavior is identical.
- **Does the pauses card need a tap target for opening a "Pauses detail" sheet?** Not in scope; out-of-spec since pauses don't have per-instance enable/disable in the current ViewModel surface.
- **Should custom word capsules be sortable / reorderable?** No (out of scope). Insertion order = creation order.

## 12. Acceptance criteria

A reviewer should be able to verify on iPhone 17 Sim:

1. ✅ Smart Cut tab shows a glassmorphic summary card at top with stats + pulsing saves badge + Reset link in Deep Indigo @ 50%.
2. ✅ Below the summary, the A/B SegmentedPill with Original selected by default in Deep Indigo.
3. ✅ Below the picker, single-column wide bento cards: one per filler category, plus one Pauses card. Each filler card shows count eyebrow, word, savings chip, group toggle.
4. ✅ Tapping anywhere on a filler card body (not the toggle) opens the detail sheet.
5. ✅ Detail sheet has glass background; per-occurrence rows include ▶ preview, excerpt, timestamp, checkbox.
6. ✅ Tapping a filler card's group toggle disables the group: card opacity drops to 0.40, text strikethrough + bold + Deep Indigo.
7. ✅ Pauses card has a slider (1.0–3.0s, 0.25s steps); dragging fires light haptic per step; threshold readout rolls smoothly; saves chip recomputes live.
8. ✅ Saves badge pulse pauses on Settings → Accessibility → Reduce Motion.
9. ✅ Glass surfaces fall back to opaque cards on Reduce Transparency.
10. ✅ Edit Filler List sheet shows a single wrap-flow pool of frosted capsules. Default-off capsules dim + line-through; ✕ on default toggles off; ✕ on custom permanent-deletes; add input at bottom.
11. ✅ All "Reset" / "+ Edit filler list" links render in Deep Indigo @ 50% opacity (no system blue).
12. ✅ Test suite: 53 pass / 5 known baseline fail (no Phase 12 regressions).
