# Cleaning Lab Tabs Implementation Plan

> **For agentic workers:** REQUIRED: Use `superpowers:subagent-driven-development` (if subagents available) or `superpowers:executing-plans` to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor `CleaningLabView` into a tabbed AI suite — segmented pill at top (AI Denoise / Smart Cut), one card visible at a time, glassmorphic floating action bar at the bottom for the active tab's primary CTA, plus Smart Cut visual polish (saves badge, opacity-muted disabled rows, rounded category groups).

**Architecture:** Pure presentation-layer refactor. Two new reusable design-system components (`SegmentedPill`, `FloatingActionBar`). `CleaningLabView` gains a `@State` tab selection, restructures its body. `SmartCutCardView` and `FillerListPanel` get visual polish. **No view-model changes.** Both tools' state already lives in their existing VMs and persists across tab switches by construction.

**Tech Stack:** Swift 6, SwiftUI, `@Observable`, existing `PillButtonStyle` / `SquircleCard` / `SonicMergeSemantic` design tokens, **Swift Testing** (`import Testing`, `@Test`, `#expect`) — NOT XCTest.

**Spec reference:** `docs/superpowers/specs/2026-04-26-cleaning-lab-tabs-design.md`

**Commit convention:** `feat(clt-tN): <desc>` for tasks (clt = "cleaning lab tabs"); `test(clt-tN): ...` for test-only commits.

**Testing skill reference:** Apply @superpowers:test-driven-development for the two component tasks. The `CleaningLabView` / `SmartCutCardView` / `FillerListPanel` tasks are presentation-only and rely on the existing VM tests staying green plus manual QA — TDD doesn't naturally apply.

---

## File Structure

### New files

```
SonicMerge/DesignSystem/
├── SegmentedPill.swift           [Task 1]  — generic 2-option pill segmented control
└── FloatingActionBar.swift       [Task 2]  — glassmorphic floating CTA chassis

SonicMergeTests/DesignSystem/
├── SegmentedPillTests.swift      [Task 1]  — smoke build test
└── FloatingActionBarTests.swift  [Task 2]  — smoke build test
```

### Modified files

```
SonicMerge/Features/Denoising/CleaningLabView.swift           [Task 5]
SonicMerge/Features/SmartCut/SmartCutCardView.swift           [Task 3, Task 5]
SonicMerge/Features/SmartCut/Views/FillerListPanel.swift      [Task 4]
docs/superpowers/qa/2026-04-26-smart-cut-manual-qa.md         [Task 6]
```

### Task ordering

The order below keeps the build green at every commit and avoids the "Apply Cuts is briefly missing" trap:

1. **`SegmentedPill`** — independent, isolated. TDD smoke test.
2. **`FloatingActionBar`** — independent, isolated. TDD smoke test.
3. **`SmartCutCardView` header restyle** — adds the saves badge. Does NOT yet remove the inline Apply button (so the build stays green even if Task 5 isn't yet done).
4. **`FillerListPanel` polish** — opacity + rounded groups. Independent.
5. **`CleaningLabView` tabs refactor** — adds tabs, wires floating bar, AND removes the now-redundant inline Apply button from `SmartCutCardView` in the same commit. After this task, the floating bar owns the CTA.
6. **Manual QA append** — adds the Cleaning Lab Tabs section to the existing QA checklist.

---

## Chunk 1: All tasks

(Single chunk — entire plan ≤1000 lines, all tasks are tightly related to the same refactor.)

---

### Task 1: SegmentedPill — generic 2-option pill segmented control

**Why:** Reusable design-system component for the new tab switcher; matches the existing `PillButtonStyle` aesthetic so the tab control feels cohesive with the rest of the app.

**Files:**
- Create: `SonicMerge/DesignSystem/SegmentedPill.swift`
- Test: `SonicMergeTests/DesignSystem/SegmentedPillTests.swift`

- [ ] **Step 1: Write failing smoke test**

```swift
// SonicMergeTests/DesignSystem/SegmentedPillTests.swift
import Testing
import SwiftUI
@testable import SonicMerge

@MainActor
struct SegmentedPillTests {

    private enum TwoOption: Hashable, CaseIterable {
        case first, second
    }

    @Test func testBuildsWithTwoOptions() {
        let view = SegmentedPill<TwoOption>(
            selection: .constant(.first),
            label: { option in
                switch option {
                case .first:  return "First"
                case .second: return "Second"
                }
            }
        )
        // Smoke test — body must build without crashing.
        _ = view.body
    }

    @Test func testSelectionBindingIsReadable() {
        var captured: TwoOption = .first
        let binding = Binding<TwoOption>(
            get: { captured },
            set: { captured = $0 }
        )
        let view = SegmentedPill<TwoOption>(
            selection: binding,
            label: { _ in "" }
        )
        _ = view.body
        // Verify the binding wiring compiles — actual interaction is manual QA.
        #expect(captured == .first)
    }
}
```

- [ ] **Step 2: Verify test fails (`SegmentedPill` undefined)**

Run: `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SonicMergeTests/SegmentedPillTests 2>&1 | tail -10`

Expected: `Cannot find 'SegmentedPill' in scope`.

- [ ] **Step 3: Implement SegmentedPill**

```swift
// SonicMerge/DesignSystem/SegmentedPill.swift
import SwiftUI
import UIKit

/// Generic pill segmented control matching the project's PillButtonStyle aesthetic.
/// Sized for 2 options at iPhone widths; supports N≥2 via Option.allCases iteration.
///
/// Usage:
///     enum Tab: Hashable, CaseIterable { case foo, bar }
///     @State private var tab: Tab = .foo
///     SegmentedPill(selection: $tab) { option in
///         option == .foo ? "Foo" : "Bar"
///     }
///
/// The selected option uses (.filled, .compact, .ai); unselected uses (.outline, .compact, .accent).
/// Tapping fires a light UIImpactFeedbackGenerator for tactile confirmation.
struct SegmentedPill<Option: Hashable & CaseIterable>: View
    where Option.AllCases: RandomAccessCollection
{
    @Binding var selection: Option
    let label: (Option) -> String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(Option.allCases), id: \.self) { option in
                let isSelected = (option == selection)
                Button {
                    if option != selection {
                        selection = option
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } label: {
                    Text(label(option))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle(
                    variant: isSelected ? .filled : .outline,
                    size: .compact,
                    tint: isSelected ? .ai : .accent
                ))
            }
        }
    }
}
```

- [ ] **Step 4: Verify 2/2 PASS**

Same xcodebuild command. If the runner hangs, reset the simulator: `xcrun simctl shutdown all && xcrun simctl erase all`, then re-launch the app and re-run.

- [ ] **Step 5: Commit**

```bash
git add SonicMerge/DesignSystem/SegmentedPill.swift SonicMergeTests/DesignSystem/SegmentedPillTests.swift
git commit -m "feat(clt-t1): add SegmentedPill generic 2-option pill segmented control"
```

---

### Task 2: FloatingActionBar — glassmorphic floating CTA chassis

**Why:** Reusable wrapper for floating bottom action buttons. Used by Cleaning Lab in Task 5 for both tabs' primary CTAs.

**Files:**
- Create: `SonicMerge/DesignSystem/FloatingActionBar.swift`
- Test: `SonicMergeTests/DesignSystem/FloatingActionBarTests.swift`

- [ ] **Step 1: Write failing smoke test**

```swift
// SonicMergeTests/DesignSystem/FloatingActionBarTests.swift
import Testing
import SwiftUI
@testable import SonicMerge

@MainActor
struct FloatingActionBarTests {

    @Test func testBuildsWithButtonContent() {
        let view = FloatingActionBar {
            Button("Test") { }
                .buttonStyle(.borderless)
        }
        _ = view.body
    }

    @Test func testBuildsWithLabelContent() {
        let view = FloatingActionBar {
            Label("Apply", systemImage: "sparkles")
        }
        _ = view.body
    }
}
```

- [ ] **Step 2: Verify test fails (`FloatingActionBar` undefined)**

Run: `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SonicMergeTests/FloatingActionBarTests 2>&1 | tail -10`

Expected: `Cannot find 'FloatingActionBar' in scope`.

- [ ] **Step 3: Implement FloatingActionBar**

```swift
// SonicMerge/DesignSystem/FloatingActionBar.swift
import SwiftUI

/// A glassmorphic chassis for a floating bottom action bar.
///
/// Renders its content inside a Capsule().fill(.ultraThinMaterial) with a soft drop shadow,
/// padded for safe-area clearance. Intended to be placed inside an `.overlay(alignment: .bottom)`
/// or in a ZStack's bottom alignment.
///
/// Empty-state handling: callers that want the bar to disappear in some states should wrap the
/// entire `FloatingActionBar` in an `if`. SwiftUI cannot reliably detect "empty content" inside
/// a @ViewBuilder, so this view does NOT attempt to hide itself when content is empty.
struct FloatingActionBar<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
    }
}
```

- [ ] **Step 4: Verify 2/2 PASS**

- [ ] **Step 5: Commit**

```bash
git add SonicMerge/DesignSystem/FloatingActionBar.swift SonicMergeTests/DesignSystem/FloatingActionBarTests.swift
git commit -m "feat(clt-t2): add FloatingActionBar glassmorphic floating CTA chassis"
```

---

### Task 3: SmartCutCardView header — saves-badge restyle

**Why:** Replace the single-line stats text with a two-element header — secondary descriptive text plus a prominent lime-green capsule badge for the savings number. Per spec §6.3.

**Files:**
- Modify: `SonicMerge/Features/SmartCut/SmartCutCardView.swift`

This task does NOT remove the inline `Apply Cuts` button — that happens in Task 5 once the floating bar replacement is in place.

- [ ] **Step 1: Read existing card to find the statsLine**

Read `SonicMerge/Features/SmartCut/SmartCutCardView.swift`. Locate the existing `statsLine` computed property (returns a single `Text("Found N fillers + M long pauses · saves ~Xs")`).

- [ ] **Step 1.5: Verify semantic theme tokens exist before writing the badge**

Run: `grep -rn "aiAccent\|surfaceMuted\|onAiAccent\|surfaceBase" SonicMerge/DesignSystem/ 2>&1 | head -20`

For each of the three tokens used in `SavesBadge` below (`semantic.aiAccent`, `semantic.surfaceMuted`, `semantic.onAiAccent`), confirm one of:
- The exact token name exists → use as-is.
- A close-enough alternative exists (e.g. project uses `accentAI` instead of `aiAccent`, or `surfaceSubdued` instead of `surfaceMuted`) → substitute the actual name throughout the SavesBadge code.
- None of the above → extend the semantic palette with the missing tokens (small additive change to the theme file; document in the commit message body).

Lock in the chosen token names BEFORE writing Step 2's code. Don't rely on names that may not compile.

- [ ] **Step 2: Replace `statsLine` with a two-line header + badge**

Replace the existing `statsLine` computed property with these two members:

```swift
private var statsLine: some View {
    let fillerCount = vm.editList.fillers.count
    let pauseCount = vm.editList.pauses.count
    return VStack(alignment: .leading, spacing: 8) {
        Text("Found \(fillerCount) fillers + \(pauseCount) long pauses")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        HStack {
            SavesBadge(savings: vm.editList.enabledSavings)
            Spacer()
        }
    }
}

/// Lime-green capsule with a soft glow, dimming to grey when savings == 0
/// (preserves layout stability as the user toggles rows).
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

    private func formatDuration(_ s: TimeInterval) -> String {
        let m = Int(s) / 60
        let sec = Int(s) % 60
        return m > 0 ? "\(m)m \(sec)s" : "\(sec)s"
    }
}
```

NOTE: `semantic.aiAccent`, `semantic.surfaceMuted`, and `semantic.onAiAccent` are token names assumed to exist on the project's `SonicMergeSemantic` environment value. If any of these specific names don't exist, BEFORE writing the code, open `SonicMerge/DesignSystem/SonicMergeTheme*.swift` (or wherever the semantic palette is defined) and use the closest equivalents (e.g. `aiAccent` ≈ the lime green used by `PillButtonStyle.ai`; `surfaceMuted` ≈ `Color(.systemGray5)` or whatever neutral mid-grey the project uses; `onAiAccent` ≈ the foreground color paired with `aiAccent`, typically white or the project's `surfaceBase`). If extending the palette by 1-2 tokens is needed, do so — small additive change, document in the commit message.

- [ ] **Step 3: Build to verify**

Run: `xcodebuild build -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "(BUILD|error:)" | tail -5`

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run existing SmartCutViewModelTests to verify no regression**

Run: `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SonicMergeTests/SmartCutViewModelTests 2>&1 | grep -E "(SUCCEEDED|FAILED|passed|failed)" | tail -10`

Expected: 7/7 PASS.

- [ ] **Step 5: Commit**

```bash
git add SonicMerge/Features/SmartCut/SmartCutCardView.swift
git commit -m "feat(clt-t3): replace Smart Cut stats line with saves badge"
```

If the implementation needed to extend the semantic palette (Step 2 fallback), include the modified theme file in the same commit and mention it in the commit message body.

---

### Task 4: FillerListPanel polish — opacity + rounded category groups

**Why:** Per spec §6.4 + §6.5. Disabled per-occurrence rows visually mute via opacity; each category-block (header + expanded children) and the pause row sit on a rounded surface background; vertical inter-block spacing increases for breathing room.

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/FillerListPanel.swift`

- [ ] **Step 1: Read existing panel to locate edit points**

Read `SonicMerge/Features/SmartCut/Views/FillerListPanel.swift`. Find:
- The outermost `VStack(alignment: .leading, spacing: 12)` in `body` — change `spacing: 12` → `spacing: 16`.
- `occurrenceRow(edit:)` — add opacity to the muted text + timestamp.
- `categoryRow(category:)` — its caller (`body`'s `ForEach`) needs to wrap each category-block (header + expanded children) in a rounded background.
- `pauseRow` — wrap in the same rounded background.
- The `Divider()` between the filler list `ForEach` and the pause-row block — locate it (likely inside the outer `VStack`'s body, between the categories `ForEach` and the `if !editList.pauses.isEmpty {` block). Step 4 removes it.

- [ ] **Step 2: Update outer VStack spacing**

Inside `body`, change:

```swift
VStack(alignment: .leading, spacing: 12) {
```

to:

```swift
VStack(alignment: .leading, spacing: 16) {
```

- [ ] **Step 3: Add opacity to disabled rows in `occurrenceRow(edit:)`**

Replace the existing `occurrenceRow(edit:)` body with:

```swift
private func occurrenceRow(edit: FillerEdit) -> some View {
    HStack {
        Button {
            playWindow(around: edit.timeRange)
        } label: {
            Image(systemName: "play.fill")
        }
        Text(edit.contextExcerpt)
            .lineLimit(1)
            .opacity(edit.isEnabled ? 1.0 : 0.4)
        Spacer()
        Text(formatTimestamp(edit.timeRange.lowerBound))
            .foregroundStyle(.secondary)
            .opacity(edit.isEnabled ? 1.0 : 0.4)
        Image(systemName: edit.isEnabled ? "checkmark.square.fill" : "square")
            .onTapGesture {
                onIndividualToggle(edit.id, !edit.isEnabled)
            }
    }
    .padding(.leading, 24)
}
```

(The diff is just `.opacity(...)` on the context excerpt and timestamp. Play button + checkbox stay full opacity since they remain interactive.)

- [ ] **Step 4: Wrap each category-block + pause row in a rounded surface background**

Refactor `body` to wrap each category's `(header + expanded children)` and the pause row in a rounded background. Replace the body with:

```swift
var body: some View {
    VStack(alignment: .leading, spacing: 16) {
        ForEach(editList.categories, id: \.self) { category in
            categoryGroup(category: category)
        }
        if !editList.pauses.isEmpty {
            groupBackground { pauseRow }
        }
    }
}

@ViewBuilder
private func categoryGroup(category: String) -> some View {
    groupBackground {
        VStack(alignment: .leading, spacing: 8) {
            categoryRow(category: category)
            if expandedCategories.contains(category) {
                ForEach(editList.fillers.filter { $0.matchedText == category }) { edit in
                    occurrenceRow(edit: edit)
                }
            }
        }
    }
}

@ViewBuilder
private func groupBackground<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content()
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray6))
        )
}
```

If the project's semantic palette has a `surfaceBase` or `surfaceMuted` token, substitute it for `Color(.systemGray6)` to stay on-theme. Read `SonicMerge/DesignSystem/SonicMergeTheme*.swift` to find the right token.

The `Divider()` previously sitting between the filler list and the pause row is no longer needed (each block is now visually separated by its own card-shaped background). Remove it from the body.

- [ ] **Step 5: Build to verify**

Run: `xcodebuild build -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "(BUILD|error:)" | tail -5`

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add SonicMerge/Features/SmartCut/Views/FillerListPanel.swift
git commit -m "feat(clt-t4): polish FillerListPanel — opacity-muted disabled rows + rounded group backgrounds"
```

---

### Task 5: CleaningLabView tabs refactor + remove inline Apply Cuts button

**Why:** Spec §6.1, §6.6. Add the SegmentedPill at top, conditionally render one tab's content at a time, and float the active tab's primary CTA in a `FloatingActionBar` overlaid at the bottom. Same commit removes the now-redundant inline Apply Cuts button from `SmartCutCardView` (so the build never has two Apply buttons visible simultaneously).

**Files:**
- Modify: `SonicMerge/Features/Denoising/CleaningLabView.swift`
- Modify: `SonicMerge/Features/SmartCut/SmartCutCardView.swift`

This is the biggest task in the plan. It touches two files and both must change in the same commit.

- [ ] **Step 1: Read `CleaningLabView.swift` to understand current body structure**

Read `SonicMerge/Features/Denoising/CleaningLabView.swift`. Note:
- The existing toolbar (back button, title, share button).
- The existing `ScrollView` containing the Denoise card and the Smart Cut card.
- Where `SmartCutCardView(vm:..., library:...)` is rendered.
- The `.onAppear` that calls `viewModel.setMergedFileURL(...)` and the `PendingSmartCutOpen` deep-link block.
- Where the existing inline "Denoise Audio" button lives inside the Denoise card content.

- [ ] **Step 2: Define the tab enum at file scope**

Inside `CleaningLabView.swift`, BEFORE the `struct CleaningLabView: View {` declaration, add:

```swift
/// Tabs for Cleaning Lab's dual AI suite. File-scope enum (not nested) so the generic
/// SegmentedPill<Tab: Hashable & CaseIterable> can reference it cleanly.
fileprivate enum CleaningLabTab: Hashable, CaseIterable {
    case denoise, smartCut
}
```

- [ ] **Step 3: Restructure CleaningLabView body**

Add `@State private var selectedTab: CleaningLabTab = .denoise` to the view's properties.

Replace the existing body with this new structure. The exact code for the existing Denoise card content is the chunk that previously held the orb + intensity slider + waveform inside the existing `ScrollView`. Extract it into a private `denoiseContent` computed property; do the same for `smartCutContent`. Then compose:

```swift
var body: some View {
    ZStack(alignment: .bottom) {
        VStack(spacing: 0) {
            SegmentedPill(selection: $selectedTab) { option in
                switch option {
                case .denoise:  return "AI Denoise"
                case .smartCut: return "Smart Cut"
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView {
                Group {
                    switch selectedTab {
                    case .denoise:  denoiseContent
                    case .smartCut: smartCutContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 96)  // leave room for the floating bar
            }
        }

        if shouldShowFloatingBar {
            FloatingActionBar { floatingBarContent }
        }
    }
    .navigationTitle("Cleaning Lab")
    // ... preserve all existing modifiers (toolbar, .onAppear with setMergedFileURL, etc.)
}
```

Define the helpers (`denoiseContent`, `smartCutContent`, `shouldShowFloatingBar`, `floatingBarContent`) as private computed properties on the view:

```swift
@ViewBuilder
private var denoiseContent: some View {
    // CONCRETE EXTRACTION INSTRUCTION:
    // 1. In the existing CleaningLabView.swift body, find the SquircleCard (or VStack)
    //    that contains the AIOrbView, the "Ready to denoise" / "Denoised" label, the
    //    LimeGreenSlider for intensity, and the "Denoise Audio" Button.
    //    Search anchor: `AIOrbView(viewModel:` is the unique reference inside that block.
    // 2. Copy that entire SwiftUI subtree verbatim into this property.
    // 3. From the copy ONLY, delete the `Button { ... } label: { ... "Denoise Audio" ... }`
    //    block (the inline CTA). The orb, label, slider, and waveform stay.
    // 4. Leave the original block in body untouched until Step 3 of the parent body
    //    rewrite removes it entirely.
}

@ViewBuilder
private var smartCutContent: some View {
    SmartCutCardView(vm: viewModel.smartCutVM,
                     library: $viewModel.fillerLibrary)
}

/// Per spec §6.6: Denoise tab ALWAYS shows the floating bar (button visible-but-disabled
/// when there's nothing to denoise). Smart Cut tab shows only when there's a meaningful CTA.
private var shouldShowFloatingBar: Bool {
    switch selectedTab {
    case .denoise:
        return true  // always-show; button itself is .disabled when not actionable
    case .smartCut:
        let s = viewModel.smartCutVM.state
        switch s {
        case .results: return true
        case .applied: return viewModel.smartCutVM.hasDirtyEditsSinceApply
        case .idle, .analyzing, .stale, .error: return false
        }
    }
}

@ViewBuilder
private var floatingBarContent: some View {
    switch selectedTab {
    case .denoise:
        denoiseFloatingButton
    case .smartCut:
        smartCutFloatingButton
    }
}

@ViewBuilder
private var denoiseFloatingButton: some View {
    Button {
        guard let url = viewModel.mergedFileURL else { return }
        viewModel.startDenoising(mergedFileURL: url)
    } label: {
        Label(viewModel.hasDenoisedResult ? "Re-denoise" : "Denoise Audio",
              systemImage: "wand.and.stars")
            .frame(maxWidth: .infinity)
    }
    .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
    .disabled(viewModel.isProcessing || viewModel.mergedFileURL == nil)
}

@ViewBuilder
private var smartCutFloatingButton: some View {
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
            EmptyView()
        }
    case .idle, .analyzing, .stale, .error:
        EmptyView()
    }
}

/// Deep-link handler — must live on the OUTER `.onAppear` of the parent view so it fires
/// regardless of which tab is active on first entry. The pre-tabs build attached this to
/// SmartCutCardView.onAppear because both cards rendered simultaneously; in the tabbed
/// world, only the active tab's card mounts, so a pending deep-link arriving with Denoise
/// active would be silently dropped if the handler lived on smartCutContent.
///
/// Behavior: if a pending hash matches the current Smart Cut input, auto-switch to the
/// Smart Cut tab AND kick off analyze (which is near-instant since chunked TranscriptionState
/// is on disk).
private func handlePendingSmartCutOpenIfNeeded() {
    if let pending = PendingSmartCutOpen.shared.hash,
       let inputURL = viewModel.smartCutVM.inputURL {
        Task {
            let currentHash = try? await SourceHasher.sha256Hex(of: inputURL)
            if currentHash == pending {
                await MainActor.run {
                    selectedTab = .smartCut       // auto-switch tab
                    viewModel.smartCutVM.analyze()
                    PendingSmartCutOpen.shared.hash = nil
                }
            }
        }
    }
}
```

**IMPORTANT:** The outer body's existing `.onAppear` (the one that calls `viewModel.setMergedFileURL(...)`) must ALSO call `handlePendingSmartCutOpenIfNeeded()` — append it after the existing setMergedFileURL call. This ensures the deep-link is consumed on first entry regardless of which tab is active. The `.onAppear` modifier sits on the outer ZStack or chained off `.navigationTitle("Cleaning Lab")` per the existing structure.

Preserve all existing toolbar items, the `.sheet(isPresented:)` for export, the `.onAppear` that sets `mergedFileURL` from the handoff, and any other modifiers — they live on the outer `ZStack` or on the `.navigationTitle("Cleaning Lab")` chain.

- [ ] **Step 4: Remove the inline "Apply Cuts" button from `SmartCutCardView.swift`**

Open `SonicMerge/Features/SmartCut/SmartCutCardView.swift`. Find the `resultsContent` and `appliedContent` computed properties.

In `resultsContent`, REMOVE the trailing `Button { Task { await vm.apply() } } ... Label("Apply Cuts", ...)` block. The `+ Edit filler list` link stays as the last element in the VStack.

In `appliedContent`, REMOVE the trailing conditional `if vm.hasDirtyEditsSinceApply { Button(...) }` block. The card ends with the FillerListPanel.

These buttons now live exclusively in `CleaningLabView`'s `FloatingActionBar`. Confirmed by reading the spec §6.6 and §4.2.

- [ ] **Step 5: Build to verify**

Run: `xcodebuild build -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "(BUILD|error:)" | tail -10`

Expected: `** BUILD SUCCEEDED **`.

If you get errors about `viewModel.mergedFileURL`, `viewModel.hasDenoisedResult`, `viewModel.isProcessing`, or `viewModel.startDenoising(mergedFileURL:)` — those are existing properties/methods on `CleaningLabViewModel` (introduced in sc-t19). Confirm by reading `SonicMerge/Features/Denoising/CleaningLabViewModel.swift`.

- [ ] **Step 6: Run existing tests to verify no regression**

Run: `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SonicMergeTests/SmartCutViewModelTests -only-testing:SonicMergeTests/PlaybackCoordinatorTests 2>&1 | grep -E "(SUCCEEDED|FAILED|passed)" | tail -10`

Expected: SmartCutViewModelTests 7/7 PASS, PlaybackCoordinatorTests 3/3 PASS.

- [ ] **Step 7: Manual smoke test in simulator**

Build + install + launch. Verify:
- Default tab is **AI Denoise**
- Tapping the Smart Cut pill swaps the visible card
- The floating bar appears at the bottom of the Denoise tab with "Denoise Audio" / "Re-denoise" CTA (visible-but-disabled when `mergedFileURL` is nil)
- The floating bar appears for Smart Cut only in `.results` and `.applied`-with-dirty-edits states
- **Denoise-side state preservation**: tap Denoise → run denoise → tap Smart Cut → tap back → orb still in denoised state
- **Smart Cut-side state preservation**: on Smart Cut tab, run Analyze → toggle a filler row off → tap Denoise → tap back to Smart Cut → the toggled state is preserved (still off)
- **Re-apply morph**: on Smart Cut tab, after Apply Cuts, toggle a filler row → bar morphs to "Re-apply"; toggle back to original state → bar collapses

- [ ] **Step 8: Commit**

```bash
git add SonicMerge/Features/Denoising/CleaningLabView.swift SonicMerge/Features/SmartCut/SmartCutCardView.swift
git commit -m "feat(clt-t5): refactor CleaningLabView into tabbed AI suite with floating CTA"
```

---

### Task 6: Manual QA append

**Why:** Append the new "Cleaning Lab Tabs" verification section to the existing manual QA checklist so the next QA pass exercises the refactor.

**Files:**
- Modify: `docs/superpowers/qa/2026-04-26-smart-cut-manual-qa.md` (create with the new content if not present — it should be from sc-t20)

- [ ] **Step 1: Verify the file exists**

Check: `ls docs/superpowers/qa/2026-04-26-smart-cut-manual-qa.md`

If missing, create it with this top-level title:

```markdown
# Smart Cut & Cleaning Lab Manual QA Checklist
```

…then append the Cleaning Lab Tabs section below. If present, append the section at the end of the existing file.

- [ ] **Step 2: Append the Cleaning Lab Tabs section**

Append (or create with):

```markdown

---

## Cleaning Lab Tabs (clt-t1..t5)

Run after the Cleaning Lab tabs refactor lands.

### Default + state preservation
- [ ] First entry to Cleaning Lab lands on the **AI Denoise** tab.
- [ ] Tapping the **Smart Cut** pill smoothly switches the visible card.
- [ ] Tapping back to **AI Denoise** restores the orb in whatever state it was last in (denoised state preserved).
- [ ] After Apply Cuts in Smart Cut, switching to Denoise tab → changing intensity → re-denoising → switching back to Smart Cut transitions the card to the Stale state on next visit.

### Floating action bar
- [ ] Bar visible on AI Denoise tab whenever a merged file is loaded; label is "Denoise Audio" before first denoise, "Re-denoise" after.
- [ ] Bar visible on Smart Cut tab in **Results** state with "Apply Cuts" label.
- [ ] Bar visible on Smart Cut tab in **Applied** state ONLY when `hasDirtyEditsSinceApply` is true ("Re-apply" label).
- [ ] Bar collapses (no chassis visible) on Smart Cut tab in idle / analyzing / stale / error states.
- [ ] Bar reads cleanly over scrolled list content (glassmorphic blur, not opaque).
- [ ] Bar respects safe-area on devices with home indicator (no clipping).

### Smart Cut visual polish
- [ ] "saves ~Xs" badge has visible lime glow when savings > 0.
- [ ] Badge dims to grey when all rows are toggled off (savings == 0); does NOT disappear (layout stays stable).
- [ ] Disabled per-occurrence filler rows visually muted to ~40% opacity but still tappable to re-enable.
- [ ] Each category-block (header + expanded children) sits on its own rounded surface background.
- [ ] Pause row also sits on a rounded surface background.

### No regressions
- [ ] The toolbar share icon remains tappable from either tab.
- [ ] Export from either tab uses `smartCutOutputURL ?? denoisedTempURL ?? mergedFileURL` (the most-processed audio).
- [ ] Light haptic still fires on individual filler toggle.
- [ ] Medium haptic still fires on category toggle.
- [ ] Heavy haptic still fires on Apply Cuts.
- [ ] EditFillerListSheet opens and dismisses cleanly; floating bar does NOT visually overlap the sheet.

### Smaller-device check
- [ ] On iPhone SE (smallest supported): SegmentedPill + scroll content + floating bar all fit without clipping.
```

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/qa/2026-04-26-smart-cut-manual-qa.md
git commit -m "docs(clt-t6): append Cleaning Lab Tabs section to manual QA checklist"
```

---

## Wrap-up checklist

- [ ] All 6 tasks committed
- [ ] All existing test suites pass (`xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17'`)
- [ ] Manual QA executed against the new "Cleaning Lab Tabs" checklist
- [ ] No new TODO markers in committed code
- [ ] Spec referenced in commit messages: `docs/superpowers/specs/2026-04-26-cleaning-lab-tabs-design.md`
