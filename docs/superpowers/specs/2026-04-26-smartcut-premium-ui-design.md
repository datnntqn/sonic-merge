# Smart Cut Premium UI Refactor — Design Spec

**Status:** Approved (brainstorming phase complete)
**Date:** 2026-04-26
**Owner:** DATNNT
**Implements:** Polish pass on Smart Cut: split the single Smart Cut card into a Summary card + Filler list card, add a pulsing saves badge with counting-text animation, replace the A/B pill pair with the existing `SegmentedPill`, give filler groups a "bento" border + soft shadow, flip the disabled-row visual treatment to strikethrough + 50% opacity on rows selected for removal, replace the pause-threshold stepper with a snap-to-0.1s slider that triggers haptic feedback and live-recompute of pauses.

---

## 1. Overview

The Smart Cut tool that shipped in the Cleaning Lab Tabs refactor (commit `fbdf722`) renders all of its UI inside one large `SquircleCard`: header → counts + saves badge → A/B pill → filler categories → pause row → "+ Edit filler list" link. It works, but the visual hierarchy is flat — the summary information competes for attention with the curation list, and there's no surface separation between "tell me what you found" and "let me change what gets cut."

This refactor splits that one card into **two stacked cards** inside the Smart Cut tab's scroll view:

- **Summary Card** at the top — title, counts, prominently-pulsing saves badge, and a compact `SegmentedPill` for the Original/Cleaned A/B toggle.
- **Filler List Card** below — each filler category in its own bento card (rounded background + thin border + very soft shadow), per-occurrence rows with a strikethrough + 50% opacity treatment when selected for removal, and a custom Slider replacing the pause-threshold Stepper. The "+ Edit filler list" link stays here as the trailing element.

Two non-presentation changes ride along to enable the slider's real-time behavior: `SmartCutService.Update.completed` carries the recognized segments + source duration, and `SmartCutViewModel` caches them so `setPauseThreshold(_:)` can re-run `PauseDetector` without a fresh recognition pass.

The floating Apply Cuts button and the parent SegmentedPill (Cleaning Lab Tabs) are unchanged.

## 2. Goals and non-goals

**Goals:**
- Two visually distinct cards inside the Smart Cut tab — Summary on top, Filler list below — separated by ~16pt vertical spacing, both visually quiet (low elevation, soft shadow).
- Subtle pulse animation on the saves badge (only when `enabledSavings > 0`; static when zero/grey).
- Counting animation on the savings number — `.contentTransition(.numericText())` so the value rolls smoothly when toggles change OR slider moves.
- Replace the 2-pill `HStack { "Original"; "Cleaned" }` with the existing `SegmentedPill` (clt-t1) bound to a new `enum ABSelection`.
- Bento card treatment for each filler category and the pause row — extend the existing `groupBackground` helper with a 1pt border (separator color, 50% opacity) and a very soft shadow (radius 4, opacity 0.05, y 2).
- **Semantic flip on the disabled-row visual:** strikethrough + opacity 0.5 on per-occurrence rows where `isEnabled == true` (i.e. the rows that will be cut). Reverses the current `clt-t4` direction (which dimmed the kept rows). Per-row scope only — category headers + checkboxes stay full opacity.
- Replace the pause-threshold `Stepper` with a SwiftUI `Slider`, range 0.5...3.0, snap to 0.1s, `.soft` haptic per snap, live-recompute the pauses array on each snap. **Note: range widens from current 1.0...3.0 to 0.5...3.0** — deliberate behavior change so users can opt in to trimming sub-second breaths (which 1.0s minimum forbade).
- Counting-text animation on the pause-row "saves" total too.
- Two new unit tests covering the `setPauseThreshold` behavior.

**Non-goals (deferred):**
- The 4 pre-ship Important items from the Smart Cut original review (slider debounce on intensity blend, `PendingSmartCutOpen` `.onChange`, `SmartCutSourceLocator` GC, A/B audio plumbing). Tracked separately.
- `AudioNormalizationService` mono-upmix sample-rate bug. Separate spec.
- Pulse animation on the floating Apply Cuts button. Brief did not request it; the badge is the focal point for "this is the win."
- Custom slider track styling beyond `.tint(.aiAccent)`. Native chassis is fine for v1.
- Persisting last-used pause threshold across app launches.
- Unit-testing the pulse / counting animations — visual, validated manually.

## 3. User journey

1. User runs Smart Cut Analyze (existing flow). State transitions Idle → Analyzing → Results.
2. The Smart Cut tab now shows two cards stacked vertically:
    - **Summary Card** (top): "Smart Cut" title + Reset button. Below: secondary "Found 7 fillers + 2 long pauses" text. Below that: a prominent lime-green capsule reading "saves ~31s" with a subtle pulse animation (~1.7s cycle, scaling 1.0↔1.04). Below that: a compact `SegmentedPill` with "Original" / "Cleaned" — the lime "Cleaned" side selected by default.
    - **Filler List Card** (below, ~16pt gap): each detected category sits in its own bento card with a rounded background, thin border, and barely-perceptible shadow lift. The first card is "um (23) ▾" — expanded by default? No — collapsed by default per current behavior, the chevron toggles. Below the categories, a separate bento card holds the pause row: checkbox + "Trim 2 long pauses (>1.5s)" + "saves 0:31" text on the right + a horizontal slider below. At the bottom, "+ Edit filler list" stays as the trailing link.
3. User taps the chevron on "um" → category expands. Each per-occurrence row shows: ▶ play button (full opacity) + context excerpt + timestamp + checkbox. The default-on rows have **strikethrough on text and timestamp + 0.5 opacity** because they are selected for removal. The checkbox stays full opacity for clear interaction.
4. User unchecks one of the "um" occurrences → that row's strikethrough lifts and opacity returns to 1.0. Light haptic fires. The summary badge's "saves ~31s" text counts down smoothly to "saves ~30s" via numeric content transition.
5. User drags the pause-threshold slider from 1.5s to 0.8s. As they drag, every 0.1s snap fires a `.soft` haptic; the pause row's "saves" text counts up in real-time as more pauses become detected; the summary card's saves badge also counts up; pulse continues throughout.
6. User taps Apply Cuts in the floating bar (unchanged). Card transitions to Applied state.

## 4. Architecture

### 4.1 Surface restructure

Inside `SmartCutCardView`'s `body`, the existing single `SquircleCard` is split into two stacked `SquircleCard`s, separated by a `VStack(spacing: 16)`. The split runs cleanly along these lines:

- **Summary Card** receives: header (Reset button stays in this card's top-right), counts text, SavesBadge, A/B SegmentedPill.
- **Filler List Card** receives: `FillerListPanel` (the existing component, with the polish changes from §6), then "+ Edit filler list" link at the bottom.

Both cards use the same `SquircleCard(glassEnabled: false, glowEnabled: false)` chassis. No new card primitive.

The 5 visual states (`.idle / .analyzing / .results / .applied / .stale / .error`) all continue to render their content inside the appropriate card structure:
- `idle` and `analyzing` keep their existing centered layouts inside a single Summary-styled card (no Filler List Card rendered — there's nothing to list yet).
- `results` and `applied` render BOTH cards.
- `stale` renders Summary card with the stale banner + Re-analyze button, plus the dimmed Filler List Card. The dimmed-list rule comes from the original Smart Cut design at `docs/superpowers/specs/2026-04-26-smart-cut-design.md` §6.5: "filler list is dimmed but visible (so user can see what was found before)" — implemented via the existing `fillerPanel(dimmed: Bool)` parameter on the panel, which applies `.opacity(0.4).disabled(true)` to the whole list. Reuse that helper.
- `error` renders Summary card with the error message + retry; no Filler List Card.

This keeps `SmartCutCardView`'s state-machine shape identical; only the card containers shift.

### 4.2 ViewModel + Service additions

Live-recompute on slider drag requires the cached transcription segments to be retained on the ViewModel after analyze completes:

**`SmartCutService.Update.completed`** — extend from `case completed(EditList)` to:

```swift
case completed(
    editList: EditList,
    segments: [TranscriptionState.RecognizedSegment],
    sourceDuration: TimeInterval
)
```

The existing `analyze(input:) -> AsyncThrowingStream<Update, Error>` method already has both pieces in scope (it computes `editList` from `state.recognizedSegments` and reads `state.sourceDuration` to call `PauseDetector.detect`). Extending the case is a one-line change in the orchestrator + the integration test's match site.

**`SmartCutViewModel`** (which is `@Observable @MainActor final class`, NOT a Swift `actor`) gains:

```swift
// Stored on the @MainActor view model for slider-driven recompute. Seeded in analyze() completion.
// Reset to empty / 0 in invalidate() and requestReanalyze() so a stale cache doesn't survive
// into a new source's editing session.
private var cachedRecognizedSegments: [TranscriptionState.RecognizedSegment] = []
private var cachedSourceDuration: TimeInterval = 0

// New method called from FillerListPanel's slider onChange.
func setPauseThreshold(_ newThreshold: TimeInterval) {
    pauseThreshold = newThreshold
    let recomputed = PauseDetector.detect(
        in: cachedRecognizedSegments,
        totalDuration: cachedSourceDuration,
        threshold: newThreshold
    )
    // Preserve user toggles across recompute: match by lowerBound; new pauses default-enabled.
    let oldByLower: [TimeInterval: Bool] = Dictionary(
        uniqueKeysWithValues: editList.pauses.map { ($0.timeRange.lowerBound, $0.isEnabled) }
    )
    editList.pauses = recomputed.map { pause in
        var p = pause
        if let oldEnabled = oldByLower[pause.timeRange.lowerBound] {
            p.isEnabled = oldEnabled
        }
        return p
    }
}
```

The analyze completion handler updates from:

```swift
case .completed(let list):
    editList = list
    state = .results
```

to:

```swift
case .completed(let list, let segments, let duration):
    cachedRecognizedSegments = segments
    cachedSourceDuration = duration
    editList = list
    state = .results
```

`hasDirtyEditsSinceApply` continues to compare `appliedEditListSnapshot` to `editList`. Threshold changes mutate `editList.pauses`, so they correctly mark the EditList as dirty post-Apply (Re-apply pill morphs in).

### 4.3 What does NOT change

- `CleaningLabView` — no changes. The Smart Cut tab content swaps in its restructured `SmartCutCardView`, but the parent's tab control, FloatingActionBar, deep-link handler, exportSource fallback, etc. are all untouched.
- `SegmentedPill`, `FloatingActionBar`, `PillButtonStyle`, `SquircleCard`, `AIOrbView`, `WaveformPathView`, `PremiumBackground`, semantic theme — no changes.
- `FillerEdit`, `PauseEdit`, `EditList`, `FillerLibrary`, `TranscriptionState`, `FillerDetector`, `PauseDetector`, `AudioCutter`, `SourceHasher`, `BackgroundTranscriptionTask`, `SmartCutAppDelegate` — no changes.
- The Service/VM signatures for `analyze()`, `apply()`, `setInput()`, `invalidate()`, `markDenoiseChanged()`, `cancelAnalyze()`, `requestReanalyze()`, `scheduleBackgroundTranscription()`, `setCategory()`, `setEdit()`, `toggleCleaned()`, `pauseAll()` — all unchanged. Only the `Update` enum's associated values grow, and `setPauseThreshold(_:)` is added.
- The 5-state state machine — unchanged.
- The floating action bar's CTA visibility logic and morph behavior — unchanged.

## 5. Data flow

```
User drags pause-threshold slider in FillerListPanel
        │
        ▼
Slider's binding setter snaps to 0.1s
        │
        ├──► UIImpactFeedbackGenerator(style: .soft).impactOccurred()  (only when snap value changed)
        │
        └──► onThresholdChange(snapped) — closure passed in from SmartCutCardView
                  │
                  ▼
        SmartCutCardView calls vm.setPauseThreshold(snapped)
                  │
                  ▼
        SmartCutViewModel.setPauseThreshold:
            - pauseThreshold = newThreshold
            - PauseDetector.detect(cachedSegments, cachedDuration, newThreshold)
            - editList.pauses = recomputed (preserving isEnabled by lowerBound match)
                  │
                  ▼
        editList mutated → @Observable invalidates dependents
                  │
                  ├──► Summary Card SavesBadge: enabledSavings recomputes → contentTransition rolls
                  ├──► Pause row "saves" text: filtered sum recomputes → contentTransition rolls
                  └──► Per-occurrence pause-list count text updates
```

For filler toggles, the existing flow is unchanged from clt-t4 — `setCategory` / `setEdit` mutate `editList.fillers` → `enabledSavings` recomputes → both savings texts roll via numeric content transition.

## 6. UI composition

### 6.1 Summary Card

```
┌──────────────────────────────────────────────┐
│  ✦ Smart Cut                          Reset  │
│                                              │
│  Found 7 fillers + 2 long pauses             │
│                                              │
│  ╭────────────────╮  ◉ pulsing animation    │
│  │  saves ~31s    │     1.7s cycle           │
│  ╰────────────────╯     scale 1.0 ↔ 1.04    │
│                                              │
│  ╭─────────────╮ ╭─────────────╮             │
│  │  Original   │ │  Cleaned    │             │
│  ╰─────────────╯ ╰─────────────╯             │
└──────────────────────────────────────────────┘
```

- Header row: existing title (sparkles icon + "Smart Cut" font.headline) + Reset button (top-right). Unchanged from current implementation.
- Counts text: existing secondary `Text("Found N fillers + M long pauses")` line.
- SavesBadge (the existing `private struct SavesBadge` from clt-t3) gets two additions:
    - **Pulse, conditional on savings > 0.** Implementation:
        ```swift
        @State private var pulseScale: CGFloat = 1.0
        // ... inside body:
        Capsule().fill(...)
            .scaleEffect(pulseScale)
            .onAppear { startPulseIfNeeded() }
            .onChange(of: savings) { _, _ in startPulseIfNeeded() }

        private func startPulseIfNeeded() {
            if savings > 0 {
                withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                    pulseScale = 1.04
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    pulseScale = 1.0  // explicitly stop the repeating animation by replacing it with a one-shot to 1.0
                }
            }
        }
        ```
        The boundary case (savings drops to 0) is handled by replacing the `.repeatForever` animation with a one-shot `.easeOut` that lands at 1.0. SwiftUI's animation runner treats the new `withAnimation` block as a fresh animation on the same property, cancelling the in-flight repeating one. Without this, a `.repeatForever` would visually freeze at whatever scale the in-flight cycle was at when the conditional removed it.
    - `Text` already has the contentTransition for counting; verified working in clt-t3.
- A/B SegmentedPill replaces the current 2-pill `HStack`:
    ```swift
    SegmentedPill(selection: $abSelection) { option in
        switch option {
        case .original: return "Original"
        case .cleaned:  return "Cleaned"
        }
    }
    ```
    where `abSelection` is a new computed binding that reads `vm.isPlayingCleaned` and writes via `vm.toggleCleaned()`. New private enum `enum ABSelection: Hashable, CaseIterable { case original, cleaned }`. SegmentedPill's built-in light haptic fires on switch (already in clt-t1).

    **Visibility:** the SegmentedPill renders only in `.results` and `.applied` states (no cleaned audio exists pre-Apply in `.idle` / `.analyzing` / `.error`; in `.stale` the prior cleaned output is invalidated). In `.idle` / `.analyzing` / `.stale` / `.error` the Summary card omits the pill entirely — header + counts + (if applicable) badge only.

The Reset button position (top-right of header row) is unchanged.

### 6.2 Filler List Card

```
┌──────────────────────────────────────────────┐
│  ╭ um (23) ▾ ───────────────────────────╮    │
│  │   ▶ "...so um, the thing is..."      │    │
│  │       0:34  ☑   ← all 23 default-on, │    │
│  │       text strikethrough + 50% op    │    │
│  ╰──────────────────────────────────────╯    │
│  ╭ uh (15) ▸ ───────────────────────────╮    │  ← thin border, soft shadow
│  ╰──────────────────────────────────────╯    │
│  ╭ Trim 2 long pauses (>1.5s) ─────────╮    │
│  │  saves 0:31  ← contentTransition    │    │
│  │  ━━━━━━●━━━━━━━━━━━━━━━━━━━━━━     │    │  ← native Slider, .ai tint
│  ╰──────────────────────────────────────╯    │
│                                              │
│  + Edit filler list                          │
└──────────────────────────────────────────────┘
```

- Each category-block (the existing `categoryGroup(category:)`) keeps its `groupBackground` wrapper, now with `.overlay { RoundedRectangle.strokeBorder(separator @ 0.5 opacity, 1pt) }` and `.shadow(color: .black.opacity(0.05), radius: 4, y: 2)` added in the helper.
- Per-occurrence row text + timestamp get `.strikethrough(edit.isEnabled)` + `.opacity(edit.isEnabled ? 0.5 : 1.0)`. Play button + checkbox stay full opacity (they remain interactive). **The existing `.opacity(edit.isEnabled ? 1.0 : 0.4)` lines from clt-t4 must be REMOVED — not stacked.** The new mapping fully replaces the old (the direction is flipped per Q1 = B in §10).
- Pause row gets the same border + shadow treatment via `groupBackground`.
- The `Stepper("", value:..., step: 0.5)` is replaced with a SwiftUI `Slider(value: snappedBinding, in: 0.5...3.0)` where `snappedBinding` rounds to 0.1s and fires `UIImpactFeedbackGenerator(style: .soft).impactOccurred()` only when the snap value actually changed (avoids haptic spam during drag jitter).
- The pause-row "saves X" text uses the same `.contentTransition(.numericText(value: savings)).animation(.snappy(duration: 0.3), value: savings)` pattern as the SavesBadge.
- `+ Edit filler list` link stays at the bottom as the trailing element of the Filler List Card.

**Closure routing — `onThresholdChange` updates required.** The current `SmartCutCardView` calls `FillerListPanel(..., onThresholdChange: { vm.pauseThreshold = $0 }, ...)`. With this refactor, the closure changes to `onThresholdChange: { vm.setPauseThreshold($0) }` — `setPauseThreshold` itself sets `pauseThreshold` AND triggers the recompute. Do not leave the old `vm.pauseThreshold = $0` direct write in place; that would cause a double write (once via the closure, once inside the new method).

### 6.3 What's preserved exactly

- Light haptic on individual filler toggle (`.light`).
- Medium haptic on category toggle (`.medium`).
- Heavy haptic on Apply Cuts (`.heavy`).
- The 4-second per-occurrence preview window logic (`.onDisappear` cleanup from final-review fix).
- The `+ Edit filler list` modal sheet — unchanged.
- The 5-state state machine in `SmartCutCardView` — same enum cases, same transitions.

## 7. Error handling

No new error paths. Existing error handling unchanged:

- `setPauseThreshold` cannot fail — it's a pure recomputation against in-memory data. If `cachedRecognizedSegments` is empty (unusual but possible if the user navigates back and forth in a degraded state), `PauseDetector.detect` returns an empty array, `editList.pauses = []`, the pause row shows "Trim 0 long pauses" with the slider still functional. No crash, no error state.
- The Service.Update enum extension is a source-only change; existing throw/error handling in `analyze()`'s AsyncThrowingStream continues to work identically.

## 8. Testing approach

### 8.1 New unit tests

Two tests in `SmartCutViewModelTests.swift`:

```swift
@Test func testSetPauseThresholdReplacesPausesAndPreservesEnabledState() {
    let vm = SmartCutViewModel(...)  // existing test fixture
    let segments: [TranscriptionState.RecognizedSegment] = [
        .init(text: "hello", startTime: 0, endTime: 1, confidence: 0.9),
        .init(text: "world", startTime: 5, endTime: 6, confidence: 0.9),
    ]
    vm._injectAnalyzeCompletionForTesting(
        segments: segments,
        duration: 8.0,
        editList: EditList(
            fillers: [],
            pauses: [PauseEdit(timeRange: 1...5, isEnabled: false)]  // user disabled this one
        )
    )
    vm.setPauseThreshold(0.5)  // lower threshold → existing pause survives, possibly more emerge
    let surviving = vm.editList.pauses.first(where: { $0.timeRange.lowerBound == 1.0 })
    #expect(surviving?.isEnabled == false)  // user toggle preserved
}

@Test func testSetPauseThresholdRecomputesEnabledSavings() {
    let vm = SmartCutViewModel(...)
    let segments: [TranscriptionState.RecognizedSegment] = [
        .init(text: "hello", startTime: 0, endTime: 1, confidence: 0.9),
        .init(text: "world", startTime: 3, endTime: 4, confidence: 0.9),
    ]
    vm._injectAnalyzeCompletionForTesting(segments: segments, duration: 5.0, editList: EditList())
    vm.setPauseThreshold(1.5)  // gap is 2s — above 1.5, becomes a pause
    #expect(vm.editList.pauses.count == 1)
    #expect(vm.editList.enabledSavings == 2.0)
    vm.setPauseThreshold(2.5)  // gap is 2s — below 2.5, no pause
    #expect(vm.editList.pauses.isEmpty)
    #expect(vm.editList.enabledSavings == 0.0)
}
```

Test seam needed: a new internal `_injectAnalyzeCompletionForTesting(segments:duration:editList:)` helper on `SmartCutViewModel` that sets the cached arrays and editList without going through the actual Service. Mirrors the existing `_injectResultsForTesting` and `_injectAppliedSnapshotForTesting` patterns.

### 8.2 Existing tests must continue passing unchanged

- All 50+ existing tests across all suites.
- `SmartCutServiceIntegrationTests.testAnalyzeFindsExpectedFillersAndPauses` — needs a one-line update at the `case .completed(let list)` match to `case .completed(let list, _, _)`. No assertion changes.

### 8.3 Manual QA — append to `docs/superpowers/qa/2026-04-26-smart-cut-manual-qa.md`

Add a "Premium UI Refactor" section verifying:

- Summary card visually distinct from Filler list card with ~16pt vertical gap.
- Saves badge pulses subtly (~1.7s cycle) when `enabledSavings > 0`; static when grey/zero.
- Saves text counts smoothly (no jump-cuts) when filler toggles change.
- A/B SegmentedPill replaces the old 2-pill HStack; haptic fires on switch.
- Each filler category card has visible thin border + barely-perceptible shadow lift.
- Selected-for-removal occurrence text shows strikethrough + 0.5 opacity; checkbox stays full opacity; play button stays full opacity.
- Pause threshold slider drags smoothly, snaps to 0.1s with `.soft` haptic per snap.
- Pause savings text rolls smoothly during slider drag (no flicker).
- Summary saves badge also updates as slider drags (single source of truth working).
- Floating Apply Cuts unchanged (still works, still glassmorphic, still respects state-based visibility).
- Re-apply morph still works after Apply: toggle a row, bar shows "Re-apply"; toggle back, bar collapses.

## 9. Open follow-ups (not in this spec)

- Pre-ship Important items still pending from Smart Cut original review (slider debounce on intensity blend, `PendingSmartCutOpen` `.onChange`, `SmartCutSourceLocator` GC, A/B audio plumbing).
- `AudioNormalizationService` mono-upmix sample-rate bug. Separate spec.
- Persisting last-used pause threshold across app launches.
- Pulse animation on the floating Apply Cuts button.
- Custom slider track styling beyond `.tint`.
- Preserving expanded-category state across tab switches (currently `@State` resets on dismount; documented as low-impact in the cleaning-lab-tabs final review).

## 10. Appendix — Design decisions summary

| ID | Question | Decision | Reason |
|---|---|---|---|
| Q1 | Strikethrough direction + scope? | B — flip direction (dim the cut, not the kept), per-row scope | Strikethrough = "this will disappear" matches the deletion-preview semantic. Per-row scope keeps category headers + checkboxes legible at full opacity. |
| Q2 | Summary card structure? | B — split into two cards | Brief literally says "Summary Card"; cleaner separation of concerns; each card has one job. |
| Q3 | Slider behavior? | B — snap to 0.1s, range 0.5–3.0 | Premium feel (smooth chassis) + clean values (snap) + meaningful precision for pause cuts + natural haptic ticks per snap. |
| — | Pulse-target on saves badge? | Capsule scale 1.0↔1.04 over 1.7s | Matches AIOrbView breathing pulse cadence for visual coherence. |
| — | Service.Update enum extension scope? | Option A — extend to 3-arity case | Explicit, self-contained, minimal call sites to update. Carries segments + duration the slider needs. |
| — | Bento border + shadow intensity? | 1pt separator @ 50% opacity, shadow radius 4 / opacity 0.05 / y 2 | "Whisper-thin" — adds card legibility without competing with the existing surface fill. |

---

*End of spec.*
