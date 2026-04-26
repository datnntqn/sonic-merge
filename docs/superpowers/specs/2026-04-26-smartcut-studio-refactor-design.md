# Smart Cut Studio Refactor — Design Spec

**Status:** Draft (brainstorming phase complete; awaiting spec review + user read-through)
**Date:** 2026-04-26
**Owner:** DATNNT
**Implements:** Comprehensive UI/UX refactor of the Smart Cut tab in Cleaning Lab and the Edit Filler List sheet to a "Modern Spatial AI Studio" aesthetic — glassmorphic summary card, single-column wide bento cards for filler groups + a pauses card, tap-to-detail-sheet for occurrences, unified tag-capsule pool for the filler library editor, color audit fixing system-blue links to Deep Indigo @ 50% opacity, pulsating saves badge, rolling-digit slider readout. **Primarily a view-layer refactor.** Two foundational behavior additions are in scope to support the live-recompute pause slider UX (cached recognized segments + `setPauseThreshold(_:)` on the ViewModel — same shape as the never-merged `scp-t1`/`scp-t2` work on the abandoned `smartcut-premium-ui` branch). Otherwise no model/service surface changes.

---

## 1. Overview

The Smart Cut feature shipped its first UI in `fbdf722`. A separate `smartcut-premium-ui` branch (commits `21dff96` … `4fe50f2`) prototyped a polish pass — split summary/filler cards, segment caching, `setPauseThreshold` re-recompute, snap slider — but never merged to main. The view layer ON MAIN today is therefore still: a single `SmartCutCardView` rendering all states (idle, analyzing, results, applied, stale, error) inside one `SquircleCard`, with sub-component `FillerListPanel` rendering category groups inside gray rounded rectangles using checkbox + chevron-collapse mechanics. The Edit Filler List sheet is a flat `List` with two sections (Default Library, Your Words) and a `TextField` row at the bottom for adding custom words. There is no segment cache, no `setPauseThreshold`, no `Update.completed` segments-or-duration payload. This refactor builds from main, not from the unmerged branch.

The refactor replaces the entire view layer for these surfaces, plus adds two foundational behavior additions on the model/service side to enable the live-recompute pause slider UX. Six interconnected changes:

1. **Service + ViewModel — cached recognized segments and live pause recompute (foundational, behavior-bearing).** Extend `SmartCutService.Update.completed` to carry the recognized speech segments + the source duration alongside the EditList. `SmartCutViewModel` caches them on results, exposes `setPauseThreshold(_:)` that re-runs `PauseDetector` against the cached segments and rebuilds `editList.pauses` synchronously. Without this, the pause slider's live "saves 0:31" rolling-digit readout cannot move while dragging — it would only update at next analyze. Same shape as `scp-t1`/`scp-t2` (never merged); content largely portable from that branch.
2. **Glassmorphic Summary Card** at the top of the Smart Cut tab — frosted glass background, consolidates the section header (title + Reset link) with the stats line ("Found 7 fillers + 2 long pauses") and the saves badge into one focal panel. Saves badge gains a gentle scale-and-glow pulse.
3. **Single-column wide bento cards** for each filler category and one for "Long Pauses" — 28pt continuous squircle, soft Deep Indigo shadow, white card surface. Tapping the card opens a detail sheet; the card itself shows: word, occurrence count, savings, group toggle. Toggle-off state: bold + strikethrough text in Deep Indigo, card opacity 0.40, shadow softened.
4. **Detail sheet** (`.sheet` presentation) for occurrence drill-in — glassmorphic background, occurrence rows as wide capsule pills (▶ preview · excerpt · timestamp · checkbox). Per-occurrence enable/disable lives here, dispatching to `viewModel.setEdit(id:enabled:)`.
5. **Pause threshold slider** replacing the `Stepper` — continuous 1.0–3.0s range, snap step 0.25s, rolling-digit readout via `contentTransition(.numericText())`, light haptic on each step change, live "saves 0:31" recomputation via `viewModel.setPauseThreshold(_:)`.
6. **Edit Filler List → unified tag-capsule pool** — frosted-glass capsules in a wrap layout. Every capsule has a Deep Indigo ✕. **Tapping ✕ on any capsule (default or custom) calls `library.remove(_:)` — same code path as today's "Remove" button.** Library semantics are unchanged: the removed default goes into `removedDefaults` (persisted), the removed custom is permanently deleted. Capsule animates out. A "Restore default words" link below the pool clears `removedDefaults` (one tap brings all defaults back). Add input is a capsule-shaped TextField at the bottom; submitting on Enter calls `library.addCustom(_:)`.

Plus a small color audit: system-blue links ("Reset" inside the summary card; "+ Edit filler list" entry-point) re-tinted to Deep Indigo @ 50% opacity. The "Original/Cleaned" affordance today is two `PillButtonStyle` buttons in an HStack inside `SmartCutCardView`; the new design swaps it for the existing `SegmentedPill` component (created by `clt-t1`) — bound to the existing `viewModel.isPlayingCleaned` toggle.

The floating `Apply Cuts` button (`FloatingActionBar` chassis) is **unchanged**.

## 2. Goals and non-goals

**Goals:**
- **(Foundational behavior — `Update.completed` payload extension.)** Extend `SmartCutService.Update.completed` from `case completed(EditList)` to `case completed(EditList, segments: [TranscribedSegment], duration: TimeInterval)`. `service.analyze(input:)` already has access to the segments and asset duration internally; just propagate them outward. All call-sites updated.
- **(Foundational behavior — `SmartCutViewModel.setPauseThreshold(_:)`.)** ViewModel caches `recognizedSegments: [TranscribedSegment]` and `sourceDuration: TimeInterval` on `.completed`. Public method `setPauseThreshold(_ seconds: TimeInterval)` updates `pauseThreshold`, runs `PauseDetector(threshold: seconds).detect(segments: cached, duration: cached)` to produce a fresh `[PauseEdit]` array, replaces `editList.pauses` synchronously while preserving the user's current pause-`isEnabled` flags wherever the new pauses' `id`s match prior pauses' `id`s (id stability strategy: `id` derived from `lowerBound` rounded to 0.001s — same as `scp-t2`'s `uniquingKeysWith` trick to harden against duplicates). No-op when there are no cached segments (i.e., before first `.completed`).
- Replace `SmartCutCardView`, `FillerListPanel`, and `EditFillerListSheet` with new components living in `SonicMerge/Features/SmartCut/Views/Studio/`. Old files retired in the same commit chunk that ships the replacement.
- Glassmorphic Summary Card with `ultraThinMaterial` background, 1pt Deep Indigo @ 18% border, 24pt corner radius. Content: ✨ "SMART CUT SUMMARY" eyebrow label · stats line · saves badge · Reset link top-right.
- Saves badge pulse: scale `1.0 ↔ 1.04` over ~1.6s eased, lime green outer glow shadow synced (alpha `0.40 ↔ 0.65`), driven by a single `TimelineView` (Phase 11 pattern). Pulse only when `enabledSavings > 0`; static otherwise. Suppressed when `accessibilityReduceMotion` is on.
- Single-column wide bento cards: 28pt continuous squircle, white `surfaceCard` fill, soft shadow (16pt radius, 6pt y, Deep Indigo @ 0.10 opacity). Card content laid out horizontally: leading column (occurrence count eyebrow + word) · trailing column (saves chip + group toggle).
- Group toggle: a small lime green capsule (when on) or outline capsule (when off) on the trailing edge. Tapping the toggle flips the group on/off without opening the detail sheet. Tapping anywhere else on the card opens the sheet.
- Toggle-off card state: text bold weight + strikethrough + Deep Indigo color; card opacity 0.40; shadow softened (radius 6, alpha 0.04).
- Pauses bento card: same chassis. Trailing column has the slider + "saves 0:31" rolling-digit readout. No tap-to-sheet (no occurrences).
- Detail sheet (`.sheet` presentationDetents `.medium` + `.large`): glassmorphic background. Header: word title + total saves. Each occurrence row is a capsule pill containing ▶ play (filled/outline based on whether currently previewing) · excerpt (line-limited) · timestamp · per-occurrence checkbox. Footer with overall toggle ("Disable all" / "Enable all").
- Pause slider: SwiftUI `Slider(value:in:step:)` with `in: 1.0...3.0, step: 0.25`, `.tint(semantic.accentAction)`. Live readout uses `Text("\(formatThreshold(pauseThreshold))").contentTransition(.numericText())`. Light haptic (`UIImpactFeedbackGenerator(style: .light)`) fires on each step change via `.onChange(of: pauseThreshold)`.
- Edit Filler List unified pool: one section, all capsules wrap-flowed via a small custom `Layout` (`StudioFlowLayout`). Capsule chrome: `ultraThinMaterial` background, 1pt Deep Indigo border @ 20% opacity, 14pt corner radius. Every capsule (default OR custom) shows a trailing Deep Indigo ✕ icon (no tier distinction in the UI). Tapping ✕ calls `library.remove(_:)` — current behavior, unchanged: defaults move into `removedDefaults` (persisted), custom is permanently removed. Animated removal via `.spring(response: 0.30, dampingFraction: 0.8)` scale+opacity transition.
- "Restore default words" link below the pool, visible only when `library.removedDefaults` is non-empty. Tapping clears `removedDefaults` (UserDefaults set removed) and the wiped defaults animate back into place.
- Add input: capsule-shaped `TextField` at the bottom matching capsule chrome but with a leading "+" icon and placeholder "Add a word…". Submit on `.onSubmit` calls `library.addCustom(_:)` then clears the field. New capsule slides in with `.spring(response: 0.35, dampingFraction: 0.7)`.
- Color audit: replace any `Color.blue` / `Color.accentColor` (where the system tint defaults to blue) on Reset / "+ Edit filler list" / link affordances with `Color(uiColor: semantic.accentAction).opacity(0.5)`.
- iOS 17 baseline preserved; iOS 18 features (e.g., `MeshGradient` if used in a frosted background) behind `#available` guards (Phase 11 pattern).
- Accessibility: every interactive surface has a clear `accessibilityLabel` + `accessibilityHint`; toggle-off cards announce "disabled, double-tap to enable"; saves badge pulse pauses on `accessibilityReduceMotion`; frosted glass falls back to opaque card on `accessibilityReduceTransparency`.

**Non-goals (deferred):**
- Beyond the two goal items above (`Update.completed` payload extension and `setPauseThreshold(_:)`), no further behavior changes to `SmartCutViewModel`, `SmartCutService`, `FillerLibrary`, `EditList`, `FillerEdit`, `PauseEdit`. In particular: `FillerLibrary.remove(_:)` and `addCustom(_:)` keep their existing semantics; no new "user-disabled defaults" set is added (that would require new persisted state and divergence from current capabilities).
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

1. User sees a single section: "ALL FILLER WORDS" eyebrow, then a wrap-flow grid of frosted-glass capsules. Order = `library.allWords` (defaults minus removed, plus custom — already the existing computed property). Every capsule has a trailing Deep Indigo ✕.

2. User taps the ✕ on the "you know" capsule (a default) → `library.remove("you know")` is called; "you know" is added to `removedDefaults` (persisted in UserDefaults). The capsule animates out via `.spring(response: 0.30, dampingFraction: 0.8)` scale+opacity transition; siblings re-flow.

3. After step 2, a "Restore default words (1)" link appears below the pool (visible whenever `library.removedDefaults` is non-empty). Tapping it clears `removedDefaults`; the previously removed default capsule animates back in.

4. User taps the ✕ on the "literally" capsule (a custom word user added previously) → `library.remove("literally")` is called; permanently deleted from `customWords`. Capsule animates out the same way; "Restore" affordance does NOT bring back custom-removed words (current `remove()` semantics preserved).

5. User taps the add-input field at the bottom → keyboard rises, types "kinda", taps Return → `library.addCustom("kinda")` is called; new capsule slides in at the trailing edge of the pool (`.spring(response: 0.35, dampingFraction: 0.7)`); input clears, ready for next entry.

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
| `Studio/EditFillerListStudioSheet.swift` | The unified-pool tag editor. Wrap layout for capsules; capsule input row; submit/delete logic on the existing `FillerLibrary` API + the one-line `restoreAllDefaults()` addition. |
| `Studio/StudioFlowLayout.swift` | SwiftUI `Layout` implementation that wraps capsules into rows. Pure presentation. **Honors `LayoutDirection`**: Layout protocol gets `.environment` injection; the implementation respects RTL by mirroring x-positioning relative to the proposed bounds (~10 extra LoC vs. naive LTR-only implementation). |
| `Studio/SmartCutFormatting.swift` | Free functions `formatTimestamp(_:)` and `formatThreshold(_:)`. Lifted from the now-retired `FillerListPanel` so they don't get orphaned. Used by detail sheet, summary card, pause control row. |

Old files **retired** (moved to `Trash/` not deleted, so `git log --follow` keeps history; final cleanup commit removes them after a soak period):
- `SonicMerge/Features/SmartCut/SmartCutCardView.swift`
- `SonicMerge/Features/SmartCut/Views/FillerListPanel.swift`
- `SonicMerge/Features/SmartCut/Views/EditFillerListSheet.swift`

(Retirement strategy decided in plan, not spec. Spec just declares intent.)

### 4.2 ViewModel + Library + Service surface (with explicit additions)

**Existing `SmartCutViewModel` API the new view layer reads / calls (verbatim names from `SmartCutViewModel.swift`):**
- Read: `state` (`State` enum: `.idle | .analyzing(progress:) | .results | .applied(savedDuration:) | .stale | .error(message:)`), `editList`, `inputURL`, `outputURL`, `estimatedAnalysisMinutes`, `hasDirtyEditsSinceApply`, `pauseThreshold`, `isPlayingCleaned`.
- Write/Action: `setInput(url:)`, `invalidate()`, `markDenoiseChanged()`, `requestReanalyze()`, `analyze()`, `cancelAnalyze()`, `scheduleBackgroundTranscription()`, `setCategory(_:enabled:)`, `setEdit(id:enabled:)` (handles both filler ids and pause ids), `apply()`, `toggleCleaned()`, `pauseAll()`.
- "Total filler savings" / "total pause savings" mappings used in the new UI: `editList.enabledSavings` (already exists, sums fillers + pauses combined). For per-cohort totals, the new view layer computes inline: filler savings = `editList.fillers.filter(\.isEnabled).reduce(0) { $0 + ($1.timeRange.upperBound - $1.timeRange.lowerBound) }`; pause savings = `editList.pauses.filter(\.isEnabled).reduce(0) { $0 + $1.duration }`. **No `EditList` derived properties added.** Inline formatting helper in the new `Studio/Formatting.swift` (see §4.1).

**ViewModel additions (new in this spec):**
- `private(set) var recognizedSegments: [TranscribedSegment] = []` — populated when `Update.completed` fires with the new payload.
- `private(set) var sourceDuration: TimeInterval = 0` — same.
- `func setPauseThreshold(_ seconds: TimeInterval)` — clamps to `1.0...3.0`, updates `pauseThreshold`, runs `PauseDetector(threshold: seconds).detect(segments: recognizedSegments, duration: sourceDuration)` to produce a fresh `[PauseEdit]`. **Preserves user toggles**: if a new pause's id matches a pre-existing pause's id (id derived from `lowerBound` rounded to 0.001s), copy the prior `isEnabled`. Otherwise default to enabled. Replaces `editList.pauses` synchronously. No-op when `recognizedSegments.isEmpty`.

**`SmartCutService.Update` enum addition (new in this spec):**
- Today: `case progress(Double)` and `case completed(EditList)`.
- New: `case completed(EditList, segments: [TranscribedSegment], duration: TimeInterval)`. The service already computes both internally during `analyze`; just propagate. ALL call-sites updated (the only consumer today is `SmartCutViewModel.analyze` switch statement at line 124-134; tests in `SmartCutServiceIntegrationTests.swift` will need a one-line argument-list update).

**Existing `FillerLibrary` API used as-is — no additions:**
- Read: `defaultOnWords` (compile-time constant), `defaultOffWords` (compile-time constant), `customWords` (UserDefaults-backed), `removedDefaults` (UserDefaults-backed), `allWords` (computed: `(defaults - removed) + customWords`), `isEnabledByDefault(_:)`.
- Mutating: `addCustom(_:)`, `remove(_:)` (handles both — removing custom permanently deletes; removing a default adds to `removedDefaults`).
- New "Restore default words" affordance writes directly to `defaults` (clearing `removedKey`) — but to keep this off the call-site, the spec adds **one** small mutating method: `mutating func restoreAllDefaults()` which clears the `removedDefaults` UserDefaults key. Single line; preserves all other library invariants.

**Existing `EditList` / `FillerEdit` / `PauseEdit` — no changes.**

The new view layer reads these and dispatches actions; nothing else mutates.

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

`onTap` is wired via a `Button` wrapping the card's leading content area + a `.contentShape(Rectangle())` overlay on its frame. The **trailing group toggle** is a separate `Button` with its own action, sized 44×44pt minimum hit area. Both buttons live as siblings inside an `HStack`, so SwiftUI's hit test honors the leaf hit (the toggle), not the parent card-body button. This is the established SwiftUI pattern for nested-tap-targets — explicit `Button` for both, no `.onTapGesture` (gesture-vs-button hit ordering is fragile).

### 4.6 Detail sheet

`FillerOccurrenceSheet` is a `.sheet`-presented view:
- Detents: `.medium` (default), `.large` (drag handle visible).
- Background: `.background(.ultraThinMaterial)` on the sheet root, with a `presentationBackground(.ultraThinMaterial)` modifier (iOS 16.4+).
- Header row: word title (large, bold) + total occurrences + total saves chip on the trailing edge. "Disable all" / "Enable all" link top-right.
- Body: `ScrollView` of capsule pill rows. Each row: `studioFrostedCapsule()` chrome containing ▶ button (filled.ai when this row is currently being previewed by the `previewPlayer`, outlined otherwise), excerpt `Text` (line-limited 1), timestamp text (secondary), checkbox.
- Per-occurrence checkbox tap → `viewModel.setEdit(id: edit.id, enabled: !edit.isEnabled)`. (`setEdit` handles both filler ids and pause ids — the only public API for individual toggles on the VM.)
- The 4-second preview behavior carries over from the existing `playWindow` — including the recently-added "stop in-flight player before starting new" guard. **The helper moves into the new file** (since the spec retires `FillerListPanel`): copied verbatim into a `private func playWindow(around: ClosedRange<TimeInterval>)` on `FillerOccurrenceSheet`. State (`@State previewPlayer: AVAudioPlayer?`, `@State previewingId: String?`) is local to the sheet view. The `previewingId` drives the ▶/■ icon swap.
- "Disable all" / "Enable all" trailing link: dispatches a single `viewModel.setCategory(category, enabled: false)` (or `true`). Caveat: this clobbers any per-occurrence overrides the user may have made — same behavior the current category checkbox has today (`FillerListPanel.categoryRow`). Acceptable; matches existing model.
- Footer (within sheet, not detent-pinned): empty.
- Dismissal: standard sheet dismiss; if a preview is mid-play, `onDisappear` stops it (existing pattern from `FillerListPanel:25-32`).

### 4.7 Pause slider

The slider is **bound to a local `@State` variable** in `PauseControlRow` (not directly to `viewModel.pauseThreshold`), so the rolling-digit text can animate smoothly while drag is in progress. On each drag step, the local state writes back to the VM via `viewModel.setPauseThreshold(_:)`, which triggers the recompute. `PauseControlRow` reads `pauseSavings` (computed inline from `viewModel.editList.pauses`) for the trailing chip.

```swift
struct PauseControlRow: View {
    @Bindable var viewModel: SmartCutViewModel
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draftThreshold: TimeInterval

    init(viewModel: SmartCutViewModel) {
        self._viewModel = Bindable(viewModel)
        self._draftThreshold = State(initialValue: viewModel.pauseThreshold)
    }

    private var pauseSavings: TimeInterval {
        viewModel.editList.pauses.filter(\.isEnabled).reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Long Pauses").font(.caption2).fontWeight(.semibold).textCase(.uppercase)
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                    Spacer()
                    Text(SmartCutFormatting.formatThreshold(draftThreshold))
                        .font(.headline.monospacedDigit())
                        .contentTransition(reduceMotion ? .identity : .numericText())
                }
                Slider(value: $draftThreshold, in: 1.0...3.0, step: 0.25)
                    .tint(Color(uiColor: semantic.accentAction))
                    .onChange(of: draftThreshold) { _, new in
                        viewModel.setPauseThreshold(new)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            }
            SavesChip(seconds: pauseSavings)
                .contentTransition(reduceMotion ? .identity : .numericText())
        }
    }
}
```

Notes:
- `SmartCutFormatting.formatThreshold` and `SmartCutFormatting.formatTimestamp` are extracted into a new `Studio/SmartCutFormatting.swift` (see §4.1). Both helpers already exist as private members of `FillerListPanel` today.
- The `.onChange` fires on every `step` change of the slider, providing the haptic and the live recompute.
- The card-level `.contentTransition` modifier on the trailing `SavesChip` produces the rolling-digit animation visible from outside the card (the summary card's saves badge re-rolls in parallel because `editList.enabledSavings` is also re-derived once `setPauseThreshold` mutates `editList.pauses`).

### 4.8 Edit Filler List unified pool

`EditFillerListStudioSheet`:
- Wrap layout via `StudioFlowLayout` (SwiftUI `Layout` protocol implementation, ~50 LoC).
- Iterates `library.allWords` (existing computed property: `(defaultOnWords + defaultOffWords - removedDefaults) + customWords`). Each word renders as a `WordCapsule(word:)` view.
- `WordCapsule`: same frosted-glass chrome for every capsule (default OR custom — no UI tier distinction). Trailing Deep Indigo ✕ icon (subtle, ~10pt SF Symbol "xmark", `accentAction.opacity(0.6)`). Tap on ✕ → `library.remove(word)` (the existing single mutating method handles both default → `removedDefaults` and custom → permanently delete).
- Capsule animations:
  - Removal: the affected `WordCapsule` matches a `.transition(.scale.combined(with: .opacity))` and the wrap is wrapped in `withAnimation(.spring(response: 0.30, dampingFraction: 0.8))`.
  - Insertion: same transition, animated via `.spring(response: 0.35, dampingFraction: 0.7)` on add.
- "Restore default words (N)" link (where N = `library.removedDefaults.count`): rendered below the wrap pool, left-aligned, Deep Indigo @ 50%. Visible only when N > 0. Tap → `library.restoreAllDefaults()` (new single-line method; see §4.2).
- Add input: a capsule-shaped `TextField` at the bottom of the sheet, just above the keyboard safe area. Chrome same as `WordCapsule` but with a leading "plus" SF Symbol (Deep Indigo) and placeholder "Add a word…".
  - `.submitLabel(.done)`, `.onSubmit { library.addCustom(text); text = "" }`.
  - Validation already enforced by `library.addCustom` (trim + dedupe).
- No new `wordOrigin(_:)` helper — the UI doesn't need to distinguish default vs custom (every capsule renders the same way).

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
| Removing `SmartCutCardView` breaks deep-link `handlePendingSmartCutOpenIfNeeded()` | Low | Low | False alarm: that handler is a private method on `CleaningLabView` (`CleaningLabView.swift:294`) that mutates `selectedTab` based on `PendingSmartCutOpen.shared.hash` matching `viewModel.inputURL`. It does NOT call into `SmartCutCardView`. Replacing `SmartCutCardView` with `SmartCutStudioContainer` at the call-site (`CleaningLabView.swift:210-213`) is a one-line view swap; deep-link logic is unaffected. |
| Pulse animation on saves badge feels distracting | Medium | Low (subjective) | Configurable via single constant in `StudioPulseSavesBadge`. Easy revert. |

## 11. Open questions / future work

- **Should the pauses card open a detail sheet to per-pause toggle?** The model supports it (`PauseEdit.isEnabled`, `viewModel.setEdit(id:enabled:)`), but the current FillerListPanel ships a single all-pauses checkbox + threshold-only control. **Spec decision:** keep the pauses card behavior limited to threshold + all-on/all-off (not per-pause sheet) for v1; future work item.
- **Should custom word capsules be sortable / reorderable?** No (out of scope). Insertion order = creation order, as today.
- **Persist last-used pause threshold across launches?** No (out of scope). The threshold resets to 1.5s on each `analyze()` call, matching today's behavior.

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
