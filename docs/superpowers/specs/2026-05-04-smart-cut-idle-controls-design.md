# Smart Cut Idle Controls — Design

**Date:** 2026-05-04
**Status:** Approved (awaiting user review of written spec)
**Branch target:** `main`

---

## 1. Goals

1. Surface the **filler list** and the **long-pause threshold** on the Smart Cut session screen *before* the user taps Analyze, so they can tune both without first running an analyze pass that may use undesired defaults.
2. Eliminate the wasted vertical space below the orb on the idle screen — replace it with actionable controls.
3. Make the user feel they have control over what gets cut: directly addresses the prior complaint that "the App is not good for um/oh words" — letting them remove unreliable tokens from the list pre-analyze.
4. Keep the diff small: reuse the existing `EditFillerListStudioSheet` for editing; reuse the existing `PauseControlRow` slider mechanic.

## 2. Non-goals

- Redesigning the post-analyze studio layout (its `PauseControlRow` and "Edit list" link stay)
- New design tokens (uses existing `accentAction`/`accentAI`/`surfaceCard`/`textSecondary`)
- A separate Settings screen — the controls live inline on the idle scaffold only
- Onboarding screen modification — onboarding already shows the lime CTA without these controls; out of scope
- Changing default filler list contents, default pause threshold (`1.5s`), or `FillerLibrary` persistence shape
- Per-chip ✕ remove on the idle screen — editing is done via the existing sheet

## 3. Architecture overview

A new private view `IdleSettingsCards` (in `SonicMerge/Features/SmartCut/Views/Studio/IdleSettingsCards.swift`) hosts two cards (`IdlePauseCard` + `IdleFillerCard`) and is embedded inside `SmartCutStudioContainer.idleScaffold`. The orb shrinks from 80×80 to 56×56 to make vertical room. The whole `idleScaffold` body becomes scrollable to handle Dynamic Type XL.

`SmartCutService.analyze(input:)` is extended with an explicit `pauseThreshold:` parameter so the threshold the user picks pre-analyze actually flows through to `PauseDetector`. The current shape captures `pauseThreshold` at the actor's `init` and never reads it again — that's a real wiring gap, not just a "verify" item. Spec §6 details the API change.

The filler list comes from the existing `@Binding<FillerLibrary>` already plumbed through `SmartCutStudioContainer`. The "Edit list" tap reuses the existing `@State showEditFillerList` flag; the new `IdleFillerCard` flips it via a closure pass-down.

The pause threshold reads/writes `viewModel.pauseThreshold` (already a public `var` on `SmartCutViewModel`).

## 4. Layout

The idle scaffold becomes a vertical stack inside a `ScrollView`:

```
┌─────────────────────────────────────────────────┐
│  Remove fillers and trim long silences          │ ← tagline (unchanged)
│                                                 │
│           ✨ orb 56pt (was 80pt)                 │
│                                                 │
│  ┌─ ⏱ LONG PAUSES                       1.5s ┐ │
│  │  ───────●─────────                          │ │ ← IdlePauseCard
│  │  Cuts silences longer than 1.5s.            │ │
│  └────────────────────────────────────────────┘ │
│                                                 │
│  ┌─ 💬 FILLER WORDS               12 words   ┐ │
│  │  [um] [uh] [you know] [like] [so] [ah] …    │ │ ← IdleFillerCard
│  │  ✏ Edit list ›                              │ │
│  └────────────────────────────────────────────┘ │
│                                                 │
│  [ ✨ Analyze ~1 min ]                          │ ← lime CTA (unchanged)
│  Reads from: denoised audio                     │ ← footer (unchanged)
└─────────────────────────────────────────────────┘
```

Spacing: 12pt between the orb and the first card, 12pt between the two cards, 16pt between the second card and the Analyze CTA.

## 5. Component specs

### 5.1 `IdlePauseCard`

**Behavior:**
- Slider 1.0–3.0s, step 0.25
- `@State draftThreshold` initialized from `viewModel.pauseThreshold` on first appear
- On change: write directly to `viewModel.pauseThreshold` and fire `UIImpactFeedbackGenerator(style: .light).impactOccurred()` (matches `PauseControlRow` haptic)
- Rolling-digit threshold readout via `SmartCutFormatting.formatThreshold(draftThreshold)` with `.contentTransition(reduceMotion ? .identity : .numericText())`

**Visual:**
- `StudioBentoCard` shape (matches the post-analyze pause card, minus the savings chip on the right)
- Leading: `clock.badge.exclamationmark` icon + "LONG PAUSES" caption + threshold readout
- Slider tinted with `accentAction` (indigo)
- Subtitle below slider: `"Cuts silences longer than \(threshold)s."` — interpolated with current value, updates live as user drags

**Why no savings chip:** there are no detected pauses pre-analyze; rendering "saves 0s" reads as broken. The post-analyze `PauseControlRow` keeps the chip.

### 5.2 `IdleFillerCard`

**Behavior:**
- Reads `library.allWords` (existing accessor on `FillerLibrary`)
- Tapping the "Edit list" footer link calls a closure (passed down from `SmartCutStudioContainer`) that flips the existing `showEditFillerList` `@State`, presenting `EditFillerListStudioSheet` — identical sheet, identical editing experience as the post-analyze studio

**Visual:**
- `StudioBentoCard` shape
- Leading: `text.bubble` icon + "FILLER WORDS" caption + right-aligned word count chip (`"\(library.allWords.count) words"` in `accentAction` indigo at 14% alpha)
- Body: wrapped capsule flow, one capsule per word. Capsule style matches `EditFillerListStudioSheet`'s frosted-glass treatment but **without** the trailing `✕`. Read-only summary.
- Footer: `"✏ Edit list"` with chevron, indigo `accentAction`, tappable

**Empty state** (user removed every word, `allWords.isEmpty`): replace the chip wrap with a single line `"No filler words. Tap Edit list to add some."` in `textSecondary`. The Edit link still works.

### 5.3 `SmartCutFormatting.formatThreshold(_:)`

Already exists (used by `PauseControlRow`). Reused verbatim — produces strings like `"1.5s"`, `"2.25s"`.

## 6. `SmartCutService.analyze` API change

Current signature (`SmartCutService.swift:23`):
```swift
func analyze(input: URL) -> AsyncThrowingStream<Update, Error>
```

The threshold is captured at `init` time (`pauseThreshold: TimeInterval = 1.5`, line 16) and never updated. For the user's pre-analyze tuning to take effect, the threshold must be read at analyze time.

**New signature:**
```swift
func analyze(input: URL, pauseThreshold: TimeInterval) -> AsyncThrowingStream<Update, Error>
```

The init-time `pauseThreshold` parameter is **removed** (no callers benefit from a default-at-construction value once the new flow ships). Inside `analyze`, the new parameter replaces the actor's `self.pauseThreshold` reference at line 44.

**Two call sites need updates:**

1. `SmartCutViewModel.analyze()` (`SmartCutViewModel.swift:140`):
   ```swift
   for try await update in await service.analyze(input: inputURL) { … }
   ```
   becomes:
   ```swift
   for try await update in await service.analyze(input: inputURL, pauseThreshold: pauseThreshold) { … }
   ```

2. `OnboardingFlow.swift` `SampleStep.runAnalyze()`:
   ```swift
   for try await update in await service.analyze(input: url) { … }
   ```
   becomes:
   ```swift
   for try await update in await service.analyze(input: url, pauseThreshold: 1.5) { … }
   ```
   Onboarding has no slider, so the literal default `1.5` is correct and explicit. (We could also add a constant `SmartCutService.defaultPauseThreshold` and use that — the implementation plan picks one.)

The `SmartCutService.init`'s `pauseThreshold:` parameter and the stored property are deleted in the same diff.

## 7. State plumbing

`SmartCutStudioContainer` already exposes:
- `@Bindable var vm: SmartCutViewModel` — `IdlePauseCard` reads/writes `vm.pauseThreshold`
- `@Binding var library: FillerLibrary` — `IdleFillerCard` reads `library.allWords`
- `@State private var showEditFillerList: Bool` — already used by the post-analyze "Edit filler list" Button

The `idleScaffold` calls:
```swift
IdleSettingsCards(
    viewModel: vm,
    library: $library,
    onEditFillerList: { showEditFillerList = true }
)
```

Sheet presentation (`.sheet(isPresented: $showEditFillerList) { EditFillerListStudioSheet(library: $library) }`) is already attached to the body via the existing studio chain — works for both the post-analyze "Edit list" trigger and the new idle "Edit list" trigger because the same `@State` flag drives both.

## 8. Files to change

| File | Change | Approx LoC |
|---|---|---|
| `SonicMerge/Features/SmartCut/Views/Studio/IdleSettingsCards.swift` | **NEW** — `IdleSettingsCards` (root) + `IdlePauseCard` + `IdleFillerCard` (private nested) | ~170 |
| `SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift` | Modify `idleScaffold`: shrink orb 80→56, embed `IdleSettingsCards`, wrap in `ScrollView` | ~12 |
| `SonicMerge/Features/SmartCut/Services/SmartCutService.swift` | API change: drop init-time `pauseThreshold`, add `pauseThreshold:` to `analyze(input:)` | ~6 |
| `SonicMerge/Features/SmartCut/SmartCutViewModel.swift` | Pass `pauseThreshold:` to `service.analyze(...)` call site | 1 |
| `SonicMerge/Features/Onboarding/OnboardingFlow.swift` | Pass `pauseThreshold: 1.5` to `service.analyze(...)` call site | 1 |

No project.pbxproj edits (PBXFileSystemSynchronizedRootGroup auto-includes the new file).

## 9. Accessibility

- **VoiceOver labels:**
  - Pause card root: `"Pause threshold: \(threshold) seconds"` + standard slider trait
  - Pause card slider: SwiftUI's default slider VoiceOver behavior (range, step, value)
  - Filler card root: `"Filler words. \(N) words. Tap Edit list to modify."` (combined element)
  - Filler chips: hidden individually (`.accessibilityHidden(true)` on the chip wrap) — the count + Edit link surface the actionable info
- **Reduce Motion:** rolling-digit threshold display falls back to `.identity` content transition (matches `PauseControlRow` precedent at line 42)
- **Reduce Transparency:** filler chip frosted-glass falls back to solid `surfaceCard` (matches `EditFillerListStudioSheet` precedent)
- **Dynamic Type XL:** `ScrollView` wrapper handles overflow; chip wrap reflows naturally; slider is touch-target compliant at all sizes

## 10. Edge cases

- **Empty filler library:** §5.2 covers this — text fallback in place of chip wrap.
- **Threshold persistence across analyze:** `viewModel.pauseThreshold` is `var TimeInterval = 1.5`. Pre-analyze edits stick because nothing resets it during analyze. The post-analyze `PauseControlRow` continues to use `setPauseThreshold(_:)` (which re-runs `PauseDetector` against `cachedSegments`) — that path is unchanged. Pre-analyze direct-write to `pauseThreshold` is correct because no `cachedSegments` exist yet.
- **Stale state**: `staleScaffold` (post-denoise re-trigger) does NOT show these controls. User has to tap "Re-analyze" first. Existing behavior preserved.
- **Analyzing state**: orb pulsing, user committed. Controls hidden. Existing behavior.
- **Deep-link arrival on idle**: a background-transcription deep link can land the user mid-analyze; the analyzing scaffold hides the idle controls automatically. No conflict.

## 11. Testing

### 11.1 Unit tests

Two tests in a new `SmartCutServicePauseThresholdTests.swift`:

```swift
@Test func analyzeRespectsExplicitPauseThreshold() async throws {
    // Use a stub TranscriptionService that yields predetermined segments
    // with one 2.0s gap. Assert that analyze(input:, pauseThreshold: 1.5)
    // produces a pause edit, and analyze(input:, pauseThreshold: 2.5)
    // produces zero pause edits.
}

@Test func analyzeWithCustomThresholdMatchesPauseDetectorDirectly() async throws {
    // Snapshot test: PauseDetector.detect(..., threshold: 2.0) and
    // SmartCutService.analyze(input:, pauseThreshold: 2.0) produce the same
    // pauses for the same input segments.
}
```

These guard against future regressions where someone removes the `pauseThreshold:` parameter and the service silently falls back to a default.

### 11.2 No new view tests

Consistent with the project's idle-screen pattern. Manual QA covers visual.

### 11.3 Manual QA

1. **Pause threshold persistence**: open a Smart Cut session → idle screen → drag slider to 2.5s → tap Analyze → result page shows pauses ≥ 2.5s only (none in the 1.5–2.5s range that the default would have caught).
2. **Filler list editing**: idle screen → tap "Edit list" → sheet opens → remove "um" → close sheet → idle screen chip wrap reflects the removed word + count is N–1.
3. **Empty filler library**: in the Edit sheet remove every word → close → idle screen shows "No filler words. Tap Edit list to add some." → tap Edit → add "however" → close → chip wrap shows `[however]` and count is 1.
4. **Reduce Motion**: Settings → Accessibility → Reduce Motion → idle slider drag still works; threshold readout updates without animation.
5. **Reduce Transparency**: idle chips render with solid `surfaceCard` background.
6. **Dynamic Type XL**: idle scaffold scrolls; nothing clips off-screen.
7. **VoiceOver**: pause card and filler card both reachable; labels read as specified.
8. **Onboarding sample**: run onboarding's Smart Cut sample → confirm it still works (this is the second `service.analyze` call site that gets the wiring change).

## 12. Migration / rollout

- **No persistence migration**: `pauseThreshold` is in-memory only on the VM (recovered to default on each new session). Filler library persistence is unchanged.
- **No feature flag**: visual change only. Single PR off `main`.
- **Backward compat**: the `SmartCutService.analyze(input:)` API change is breaking but only has 2 internal callers — both updated atomically in the same chunk. No external consumers.

## 13. Open questions

None at design time. The `SmartCutService.defaultPauseThreshold` constant vs. literal `1.5` decision in onboarding is left as an implementation-plan detail (small enough to pick at code-write time).

## 14. References

- `docs/superpowers/specs/2026-05-03-three-tab-ui-unification-design.md` — visual identity (color tokens onboarding inherits)
- `docs/superpowers/specs/2026-05-03-cleancut-onboarding-design.md` — onboarding's `analyze` call site that gets the wiring update
- `SonicMerge/Features/SmartCut/Views/Studio/PauseControlRow.swift` — the post-analyze pause card whose slider mechanic is reused by `IdlePauseCard`
- `SonicMerge/Features/SmartCut/Views/Studio/EditFillerListStudioSheet.swift` — the existing sheet `IdleFillerCard` triggers
- `SonicMerge/Features/SmartCut/Services/SmartCutService.swift` — API contract being changed
