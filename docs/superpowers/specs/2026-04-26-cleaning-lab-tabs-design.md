# Cleaning Lab Tabs — Design Spec

**Status:** Approved (brainstorming phase complete)
**Date:** 2026-04-26
**Owner:** DATNNT
**Implements:** Refactor Cleaning Lab into a dual-purpose AI suite — segmented control with two tabs (AI Denoise + Smart Cut), floating glassmorphic CTAs, and Smart Cut visual polish.

---

## 1. Overview

Today the Cleaning Lab screen stacks two AI tool cards vertically: the existing Denoise card on top, the recently-shipped Smart Cut card below it. Together they exceed the screen height on iPhone, so users have to scroll to access Smart Cut, and the visual weight of two simultaneously-rendered cards dilutes the focus on the active task.

This refactor turns Cleaning Lab into a **tabbed AI suite**. A 2-option segmented pill near the top of the screen lets the user pick one tool at a time; the corresponding card fills the available space below; a glassmorphic floating action bar at the bottom of the screen always exposes the tab's primary CTA ("Denoise Audio" or "Apply Cuts"). The change is presentation-only — both tools' state lives in their existing view models and persists across tab switches; the export pipeline is unchanged.

A handful of Smart Cut visual polish items ride along: a prominent lime-green "saves ~31s" badge in the header, opacity-based muting of disabled filler rows, rounded backgrounds around each filler-category block, and slightly more breathing room.

## 2. Goals and non-goals

**Goals:**
- Replace the two-card vertical stack in `CleaningLabView` with a single-tab-at-a-time presentation, gated by a custom 2-option segmented pill.
- Default to the **Denoise** tab on first entry to preserve the current user mental model.
- Preserve both tools' state across tab switches (running denoise then switching to Smart Cut and back must NOT reset the orb to the idle state).
- Promote the primary CTA in each tab into a floating glassmorphic bar at the bottom of the screen — always accessible while the tab content scrolls.
- Polish the Smart Cut card per the brief: prominent saves-badge, opacity-based disabled-row treatment, rounded category-group backgrounds, larger inter-row spacing.
- Build the segmented control and the floating bar as **two reusable design-system components** (`SegmentedPill`, `FloatingActionBar`) so future features can adopt the same chassis.

**Non-goals (explicitly deferred):**
- Tab-aware export logic. The toolbar share button continues to use the existing `exportSource` fallback chain (`smartCutOutputURL ?? denoisedTempURL ?? mergedFileURL`); the active tab does not influence which audio gets exported.
- Persisting the last-used tab across app launches. First entry is always Denoise.
- Reordering or restructuring the existing Denoise card content beyond moving its CTA into the floating bar.
- Animations between tab switches beyond SwiftUI's default cross-fade.
- Any of the 5 pre-ship Important items from the Smart Cut final code review (slider debounce, `PendingSmartCutOpen` `.onChange` consumption, `SmartCutSourceLocator` GC, A/B audio plumbing, `AudioNormalizationService` mono-upmix sample-rate bug) — tracked separately.
- Replacing strike-through with opacity for marked-for-removal fillers — this spec deliberately picks **opacity only** (see §6.4).

## 3. User journey

1. User merges clips in Mixing Station and lands in Cleaning Lab.
2. The screen presents the existing toolbar (back arrow, "Cleaning Lab" title, share icon) followed by a new `SegmentedPill` with two options — "AI Denoise" (selected) and "Smart Cut" — followed by a scroll view containing the active tab's card content.
3. A glassmorphic floating action bar at the bottom of the screen shows the active tab's primary CTA: "Denoise Audio" while in the Denoise tab, or "Apply Cuts" / "Re-apply" / nothing while in the Smart Cut tab depending on `SmartCutViewModel.state` and `hasDirtyEditsSinceApply`.
4. User taps "Denoise Audio". The orb activates; the floating bar's button label remains stable while processing. On completion, the orb settles into its denoised state.
5. User taps the "Smart Cut" pill. The screen smoothly cross-fades to the Smart Cut card. The denoise state is preserved; switching back later shows the orb still denoised. The Smart Cut card is in its `.idle` state with the "Analyze" affordance available.
6. User taps Analyze (in the Smart Cut card body, NOT the floating bar — Analyze is a "kick off long work" button, not a "commit changes" CTA). Card transitions Idle → Analyzing → Results. The floating bar shows the "Apply Cuts" button.
7. User curates the filler list. Disabled rows visibly mute via opacity (0.4); the saves-badge updates live as toggles change. The badge dims to grey when `enabledSavings == 0`.
8. User taps Apply Cuts in the floating bar. State transitions to `.applied`; if the user toggles further rows, the bar's button morphs to "Re-apply".
9. Throughout the session, the toolbar share icon remains active (with the `.disabled(viewModel.exportSource == nil)` guard already in place from sc-t19).

## 4. Architecture

### 4.1 New components — design system

**`SegmentedPill`** at `SonicMerge/DesignSystem/SegmentedPill.swift`. Generic over a `Hashable` selection type so future callers can use it with their own enum cases. Renders an `HStack(spacing: 0)` of two pill-style buttons using the existing `PillButtonStyle`. The selected option uses `(.filled, .compact, .ai)`; the unselected option uses `(.outline, .compact, .accent)`. Tapping a pill calls a binding setter and fires a light `UIImpactFeedbackGenerator`.

```swift
struct SegmentedPill<Option: Hashable & CaseIterable>: View
    where Option.AllCases: RandomAccessCollection
{
    @Binding var selection: Option
    let label: (Option) -> String
    var body: some View { /* HStack of pills */ }
}
```

Two-option only by current need; the implementation iterates `Option.allCases` so adding a third case in the future works without a struct change. Three or more options would visually crowd at iPhone widths but are not blocked.

**`FloatingActionBar`** at `SonicMerge/DesignSystem/FloatingActionBar.swift`. A wrapper view that renders its content (typically a `PillButton`) inside a `Capsule().fill(.ultraThinMaterial)` chassis with a soft drop shadow, intended for use in `.overlay(alignment: .bottom)` or inside a `ZStack`'s bottom alignment. Padding around the chassis: 16pt horizontal, 16pt bottom (to clear the home indicator on devices that have one).

```swift
struct FloatingActionBar<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View { /* Capsule + shadow + safe area handling */ }
}
```

The bar takes a `@ViewBuilder` so callers can render a single button OR a button + accessory (e.g. a small status icon next to "Re-apply"); v1 only uses the single-button variant.

### 4.2 Modified components

**`CleaningLabView.swift`**: gains a `@State private var selectedTab: ToolTab` (defaulting to `.denoise`), an enum `ToolTab: CaseIterable { case denoise, smartCut }`, and restructures its body as a `ZStack(alignment: .bottom)` of `(VStack { SegmentedPill; ScrollView { activeContent } } + FloatingActionBar { activeCTA })`. The existing Denoise content (orb, slider, "Ready to denoise" label) stays inside its own card-shaped view but with the inline "Denoise Audio" button removed; the SmartCutCardView keeps its existing structure but with the "Apply Cuts" button removed. Both buttons are reconstructed inside the `FloatingActionBar`'s content closure, gated on `selectedTab` and the relevant view-model state.

**`SmartCutCardView.swift`**: header restyled per §6 (badge), inline Apply / Re-apply blocks deleted (now in floating bar), Reset button placement unchanged. The card itself becomes shorter as a result, leaving more room for the filler list.

**`FillerListPanel.swift`**: per-occurrence rows gain `.opacity(edit.isEnabled ? 1.0 : 0.4)` on the context excerpt and timestamp (NOT the checkbox or play button — those stay full opacity since they remain interactive). Each category-block (header + expanded children) and the pause row are wrapped in a rounded background using the project's `surfaceBase` semantic token; vertical inter-block spacing increases from 12pt to 16pt.

### 4.3 What does NOT change

- `CleaningLabViewModel` — no new properties, no new methods, no signature changes. The new tab state lives in the view, not the view model, because it's purely presentation.
- `SmartCutViewModel` — no changes. The Re-apply morph already uses `hasDirtyEditsSinceApply`; the floating bar simply reads it from the parent.
- `PlaybackCoordinator` — no changes. Cross-tab playback exclusivity is already handled by the coordinator regardless of which view is rendered.
- Export pipeline (`exportSource` fallback chain, share button placement, `ExportFormatSheet`) — fully unchanged.
- `AudioNormalizationService`, `TranscriptionService`, `AudioCutter`, `BackgroundTranscriptionTask`, all SmartCut models — fully unchanged.

## 5. Data flow

There is no new data flow; all changes are layout. For completeness, the existing flow stays:

```
Mixing Station merges → mergedFileURL → CleaningLabView opens (Denoise tab default)
                                          │
                                          ├── tab = .denoise:
                                          │     User taps floating "Denoise Audio"
                                          │       → CleaningLabViewModel.startDenoising
                                          │       → denoisedTempURL set
                                          │       → notifySmartCutOfDenoiseChange()
                                          │
                                          ├── tab = .smartCut:
                                          │     User taps in-card "Analyze"
                                          │       → SmartCutViewModel.analyze
                                          │     User taps floating "Apply Cuts"
                                          │       → SmartCutViewModel.apply()
                                          │       → outputURL set
                                          │
                                          └── (any tab) Export toolbar:
                                                exportSource = smartCutOutputURL
                                                            ?? denoisedTempURL
                                                            ?? mergedFileURL
```

Tab switches do NOT trigger any model mutation; they only swap which view tree is rendered. Both view models continue to hold their state.

## 6. UI composition

### 6.1 Screen layout

```
┌─────────────────────────────────────────────┐
│  ◀  Cleaning Lab                       ⤴   │  Existing toolbar
├─────────────────────────────────────────────┤
│         (16pt vertical breathing room)      │
│  ╭─────────────╮ ╭─────────────╮            │
│  │ AI Denoise  │ │ Smart Cut   │            │  SegmentedPill
│  ╰─────────────╯ ╰─────────────╯            │
│         (12pt vertical breathing room)      │
├─────────────────────────────────────────────┤
│   ScrollView {                              │
│       activeTabContent                      │
│           padding bottom = 96pt to clear    │
│           the floating bar                  │
│   }                                         │
│                                             │
│                                             │
│                                             │
├─────────────────────────────────────────────┤
│  ╭───────────────────────────────────────╮ │
│  │     ✦  Active CTA label              │ │  FloatingActionBar
│  ╰───────────────────────────────────────╯ │
│         (16pt bottom safe area)             │
└─────────────────────────────────────────────┘
```

The `ScrollView` content gets `.padding(.bottom, 96)` so the last row in the filler list isn't permanently obscured by the floating bar. 96pt is the bar height (~56pt) plus its safe-area padding.

### 6.2 SegmentedPill

```swift
SegmentedPill(selection: $selectedTab) { option in
    switch option {
    case .denoise:  return "AI Denoise"
    case .smartCut: return "Smart Cut"
    }
}
.padding(.horizontal, 16)
```

Rendered as two `Button(label) { selection = option }` instances styled with `PillButtonStyle`. The selected pill uses `.filled .compact .ai`; the unselected uses `.outline .compact .accent`. The pills sit in an `HStack(spacing: 8)`.

Tapping a pill fires `UIImpactFeedbackGenerator(style: .light).impactOccurred()` for tactile confirmation.

### 6.3 Saves-badge in Smart Cut header

Replaces the current single-line stats text. New layout:

```
✦ Smart Cut                                Reset
Found 7 fillers + 2 long pauses
╭──────────────╮
│  saves ~31s  │   ← Capsule, .ai tint, 8pt outer green-glow shadow
╰──────────────╯
```

Implementation:

```swift
HStack(alignment: .firstTextBaseline) {
    Text("Found \(fillerCount) fillers + \(pauseCount) long pauses")
        .font(.subheadline)
        .foregroundStyle(.secondary)
}
HStack {
    SavesBadge(savings: vm.editList.enabledSavings)
    Spacer()
}
```

Where `SavesBadge` is a small private view:

```swift
private struct SavesBadge: View {
    let savings: TimeInterval
    @Environment(\.sonicMergeSemantic) private var semantic
    var body: some View {
        let isActive = savings > 0
        Text("saves ~\(formatDuration(savings))")
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isActive ? semantic.aiAccent : semantic.surfaceMuted)
            )
            .foregroundStyle(isActive ? semantic.onAiAccent : .secondary)
            .shadow(color: semantic.aiAccent.opacity(isActive ? 0.4 : 0), radius: 8)
    }
}
```

Uses the project's `@Environment(\.sonicMergeSemantic)` tokens (`aiAccent` = lime green, `surfaceMuted` = neutral grey) rather than raw `Color.green`/`Color.gray`. If these specific token names don't exist yet, the implementation pass should use the closest equivalents (or extend the semantic palette by 1-2 tokens — small additive change, document in the plan).

When `savings == 0` the badge dims to grey rather than disappearing — preserves layout stability as the user toggles rows.

### 6.4 Disabled-row treatment

Each per-occurrence row in `FillerListPanel.occurrenceRow(edit:)`:

```swift
HStack {
    Button { playWindow(around: edit.timeRange) } label: {
        Image(systemName: "play.fill")  // FULL opacity — interactive
    }
    Text(edit.contextExcerpt)
        .lineLimit(1)
        .opacity(edit.isEnabled ? 1.0 : 0.4)   // muted when disabled
    Spacer()
    Text(formatTimestamp(edit.timeRange.lowerBound))
        .foregroundStyle(.secondary)
        .opacity(edit.isEnabled ? 1.0 : 0.4)   // muted when disabled
    Image(systemName: edit.isEnabled ? "checkmark.square.fill" : "square")
        .onTapGesture {                      // FULL opacity — interactive
            onIndividualToggle(edit.id, !edit.isEnabled)
        }
}
.padding(.leading, 24)
```

**Strike-through is explicitly NOT used.** Reasoning: strike-through reads as "this content is wrong/cancelled," but a disabled filler isn't wrong — it's just being kept in the cut. Opacity reads as "muted/inactive," matches actual semantics, and matches iOS conventions for disabled controls.

### 6.5 Rounded category-group background

Wrap each category-block (the header row plus, when expanded, its child rows) and the pause row in:

```swift
.padding(12)
.background(
    RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color(.systemGray6))   // or surfaceBase semantic token
)
```

Inter-block spacing in the `VStack`: 16pt (up from 12pt).

### 6.6 FloatingActionBar content per tab

```swift
FloatingActionBar {
    switch selectedTab {
    case .denoise:
        Button {
            viewModel.startDenoising(mergedFileURL: viewModel.mergedFileURL!)
        } label: {
            Label(viewModel.hasDenoisedResult ? "Re-denoise" : "Denoise Audio",
                  systemImage: "wand.and.stars")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
        .disabled(viewModel.isProcessing || viewModel.mergedFileURL == nil)

    case .smartCut:
        smartCutPrimaryButton  // returns Apply / Re-apply / EmptyView per state
    }
}
```

`smartCutPrimaryButton` (on the parent `CleaningLabView`):

```swift
@ViewBuilder
private var smartCutPrimaryButton: some View {
    let vm = viewModel.smartCutVM
    switch vm.state {
    case .results:
        Button { Task { await vm.apply() } } label: {
            Label("Apply Cuts", systemImage: "sparkles")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
    case .applied:
        if vm.hasDirtyEditsSinceApply {
            Button { Task { await vm.apply() } } label: {
                Label("Re-apply", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
        } else {
            EmptyView()  // floating bar collapses
        }
    case .idle, .analyzing, .stale, .error:
        EmptyView()
    }
}
```

When the floating bar would have no actionable content, the **caller** wraps the entire `FloatingActionBar` in an `if`. SwiftUI cannot reliably detect "empty content" inside a `@ViewBuilder` (the workarounds rely on fragile `_ConditionalContent` introspection), so empty-state handling lives at the call site, not inside `FloatingActionBar`. Concretely, in `CleaningLabView`:

```swift
if shouldShowFloatingBar {
    FloatingActionBar { /* tab-specific button */ }
}

private var shouldShowFloatingBar: Bool {
    switch selectedTab {
    case .denoise: return true  // always show
    case .smartCut:
        switch viewModel.smartCutVM.state {
        case .results: return true
        case .applied: return viewModel.smartCutVM.hasDirtyEditsSinceApply
        case .idle, .analyzing, .stale, .error: return false
        }
    }
}
```

### 6.7 What stays unchanged on Smart Cut card

- A/B pill (Original / Cleaned) at top of card — unchanged.
- Reset link in header top-right — unchanged.
- "+ Edit filler list" link — unchanged.
- Per-occurrence play button (▶) — unchanged.
- Pause row threshold stepper — unchanged.
- The 5 visual states (idle/analyzing/results/applied/stale/error) — unchanged (apart from where the primary CTA lives).
- Existing haptic patterns (`.medium` on category toggle, `.light` on individual toggle, `.heavy` on apply) — unchanged.

## 7. Error handling

No new error paths. All existing error states already render correctly inside the SmartCut card body; the floating bar simply collapses to nothing while in `.error` state (the in-card error banner with its "Try again" button stays the source of recovery).

If the floating bar is rendered while `mergedFileURL == nil` (transient state during initial Cleaning Lab open), the Denoise button stays visible but disabled. Tap is a no-op. Once the merge handoff completes (`viewModel.setMergedFileURL(_:)` called from `.onAppear` per sc-t19), the button re-enables.

## 8. Testing approach

### 8.1 Unit tests

No new logic to unit-test. The existing test suites (50+ tests across `EditListTests`, `FillerLibraryTests`, `FillerDetectorTests`, `PauseDetectorTests`, `AudioCutterTests`, `SmartCutViewModelTests`, `PlaybackCoordinatorTests`, etc.) must continue to pass unchanged.

### 8.2 Component sanity tests

For `SegmentedPill` and `FloatingActionBar`, add minimal Swift Testing tests that simply construct the view with sample inputs and verify the body builds without crashing. These are smoke tests, not behavioral tests:

```swift
@MainActor
struct SegmentedPillTests {
    @Test func testBuildsWithTwoOptions() {
        enum E: Hashable, CaseIterable { case a, b }
        let view = SegmentedPill(selection: .constant(.a)) { _ in "" }
        _ = view.body  // smoke test; no assertion needed
    }
}
```

### 8.3 Manual QA — appended to existing checklist

Append to `docs/superpowers/qa/2026-04-26-smart-cut-manual-qa.md` under a new "Cleaning Lab Tabs" section. The implementer should verify the file exists first (it shipped with sc-t20); if not present, create it with this section as the initial content.

- Default tab on first entry is **AI Denoise**.
- Tapping the **Smart Cut** pill smoothly switches the visible card; tapping back to **AI Denoise** restores the orb in whatever state it was last in (denoised state preserved).
- Running denoise from the floating bar updates the orb; the floating bar label changes from "Denoise Audio" to "Re-denoise".
- Switching to Smart Cut after denoise: the Analyze button (in the card body) reads from the denoised audio (subtitle still says "Reads from: denoised audio").
- After Apply Cuts in Smart Cut, switching back to Denoise tab and changing intensity then re-denoising puts the Smart Cut tab into Stale state on next visit.
- Disabled filler rows visually muted to ~40% opacity but tappable to re-enable.
- "Saves ~31s" badge has visible lime glow when savings > 0; dims to grey when all rows disabled.
- Floating bar reads cleanly over scrolled list content (glassmorphic blur, not opaque).
- Floating bar collapses (no chassis visible) when in idle/analyzing/stale/error states on the Smart Cut tab.
- The toolbar share icon remains tappable from either tab and exports the most-processed audio (`smartCutOutputURL ?? denoisedTempURL ?? mergedFileURL`).

### 8.4 Regression risk

Low. Changes are presentation-layer; both view models are unchanged; no service-layer touches. Main risk surfaces:

- **Layout overflow on smaller iPhones (e.g. iPhone SE)**: the SegmentedPill + scroll content + floating bar must all fit. Manual check on the smallest supported device after build.
- **Keyboard avoidance with `EditFillerListSheet`**: the sheet is modal and dismisses cleanly, but verify the floating bar doesn't visually conflict during sheet presentation (typically the sheet should fully cover the bar; if not, hide the bar while `showsEditFillerSheet == true`).
- **Existing snapshot of `CleaningLabView` in CI** (if any): not present today, no snapshot tests exist.

## 9. Open follow-ups (not in this spec)

- The 5 pre-ship Important items from the Smart Cut final review (slider debounce, `PendingSmartCutOpen` `.onChange`, locator GC, A/B audio plumbing, `AudioNormalizationService` mono-upmix bug) — separate spec.
- Animations between tab switches — the SwiftUI default is fine for v1; if users find it jarring, revisit with a custom `AnyTransition`.
- Persisting the last-used tab across app launches — not requested; revisit if usage data shows users always go straight to one tab.
- Support for 3+ tabs in `SegmentedPill` — implementation already iterates `Option.allCases`, but rendering will need horizontal scroll or layout adjustment when count > 2. Revisit when a third tool lands.

## 10. Appendix — Design decisions summary

| ID | Question | Decision | Reason |
|---|---|---|---|
| Q1 | Default tab on entry? | Denoise | Preserves existing user mental model; least jarring on the refactor build. |
| — | Segmented control style? | Custom (PillButtonStyle) | Visual coherence with existing A/B pill and the rest of the design system. UIKit's `UISegmentedControl` would clash. |
| — | Floating CTA scope? | Both tabs | Symmetry; "always accessible" rationale applies to Denoise too. Same chassis component, parameterized. |
| — | Tab-aware export? | No | Toolbar share button already uses the smart `exportSource` fallback. Tab is purely presentation. |
| — | Strike-through vs opacity for disabled rows? | Opacity (0.4) | Strike-through implies "wrong"; opacity implies "muted/inactive". Matches iOS conventions and actual semantics. |
| — | Saves badge when savings == 0? | Dim to grey | Preserves layout stability as user toggles. Better than vanishing. |

---

*End of spec.*
