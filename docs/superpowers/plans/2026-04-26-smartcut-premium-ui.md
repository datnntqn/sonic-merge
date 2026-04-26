# Smart Cut Premium UI Refactor — Implementation Plan

> **For agentic workers:** REQUIRED: Use `superpowers:subagent-driven-development` (if subagents available) or `superpowers:executing-plans` to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor Smart Cut UI: split the single card into Summary + Filler list cards, add a pulsing saves badge with counting-text animation, replace the A/B pill pair with `SegmentedPill`, give filler groups a bento border + soft shadow, flip the disabled-row visual treatment to strikethrough + 50% opacity on rows selected for removal, and replace the pause-threshold stepper with a snap-to-0.1s slider that triggers haptic feedback and live-recompute of pauses.

**Architecture:** Mostly presentation-layer. Two non-presentation changes ride along to enable the slider's real-time behavior: `SmartCutService.Update.completed` carries the recognized segments + source duration, and `SmartCutViewModel` caches them so `setPauseThreshold(_:)` can re-run `PauseDetector` without a fresh recognition pass.

**Tech Stack:** Swift 6, SwiftUI, `@Observable`, existing `SegmentedPill` (clt-t1), `FloatingActionBar` (clt-t2), `PillButtonStyle`, `SquircleCard`, `SonicMergeSemantic` design tokens, **Swift Testing** (`import Testing`, `@Test`, `#expect`) — NOT XCTest.

**Spec reference:** `docs/superpowers/specs/2026-04-26-smartcut-premium-ui-design.md`

**Commit convention:** `feat(scp-tN): <desc>` for tasks (scp = "smart cut premium"); `test(scp-tN): ...` for test-only commits.

**Testing skill:** Apply @superpowers:test-driven-development for Tasks 1 and 2 (genuine logic changes with TDD). Tasks 3-5 are presentation/docs and rely on the existing test suites continuing to pass plus manual QA.

---

## File Structure

### Modified files (no new files)

```
SonicMerge/Features/SmartCut/
├── Services/SmartCutService.swift          [Task 1]  Update enum extended with segments + duration
├── SmartCutViewModel.swift                 [Task 2]  cachedRecognizedSegments + cachedSourceDuration
│                                                     + setPauseThreshold(_:) + clear-on-invalidate
│                                                     + _injectAnalyzeCompletionForTesting seam
├── SmartCutCardView.swift                  [Task 3]  split into Summary + Filler cards;
│                                                     SegmentedPill A/B (visible only in .results/.applied);
│                                                     SavesBadge gets pulse animation
└── Views/FillerListPanel.swift             [Task 4]  bento border+shadow on groupBackground;
                                                      strikethrough + 0.5 opacity on isEnabled rows
                                                      (REPLACES old 0.4-on-disabled treatment);
                                                      Slider replaces Stepper; haptic on snap;
                                                      contentTransition on pause-row savings;
                                                      onThresholdChange callback wires to setPauseThreshold

SonicMergeTests/Features/SmartCut/
├── SmartCutServiceIntegrationTests.swift   [Task 1]  update .completed match arity
└── SmartCutViewModelTests.swift            [Task 2]  + 2 new tests for setPauseThreshold

docs/superpowers/qa/2026-04-26-smart-cut-manual-qa.md  [Task 5]  append "Premium UI Refactor" QA section
```

### Task ordering (build-green at every commit)

1. **`SmartCutService.Update`** extension — needed first because Task 2 references the new arity.
2. **`SmartCutViewModel`** — adds cachedSegments + setPauseThreshold + clear-on-invalidate + test seam + 2 new tests.
3. **`SmartCutCardView`** — UI restructure (split into Summary + Filler cards, SegmentedPill A/B, pulse badge). Independent of Task 4.
4. **`FillerListPanel`** — bento border+shadow + strikethrough flip + Slider + onThresholdChange wiring. Independent of Task 3.
5. **Manual QA append** — checklist additions for the new behaviors.

---

## Chunk 1: All tasks

(Single chunk — entire plan well under 1000 lines, all tasks tightly related to the same refactor.)

---

### Task 1: SmartCutService.Update — extend `.completed` with segments + duration

**Why:** The slider in Task 4 needs to live-recompute pauses against the cached transcript segments. The ViewModel (Task 2) caches them on completion. The Service is the source of truth and already has both pieces in scope inside `analyze(input:)`.

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Services/SmartCutService.swift`
- Modify: `SonicMergeTests/Features/SmartCut/SmartCutServiceIntegrationTests.swift`

This task uses TDD via the existing integration test — change the test to expect the new arity, watch it fail to compile, fix the source.

- [ ] **Step 1: Read both files first**

```
cat SonicMerge/Features/SmartCut/Services/SmartCutService.swift
cat SonicMergeTests/Features/SmartCut/SmartCutServiceIntegrationTests.swift
```

Locate:
- The `enum Update` declaration in `SmartCutService.swift` (currently `case progress(Double); case completed(EditList)`).
- Where `analyze()` yields `.completed(...)` near the end of the AsyncThrowingStream Task body. The `state.recognizedSegments` and `state.sourceDuration` are both already in scope at the yield site.
- The `case .completed(let list)` match site in the integration test.

- [ ] **Step 2: Update the integration test to expect the new arity**

In `SmartCutServiceIntegrationTests.swift`, find the loop:

```swift
for try await update in service.analyze(input: url) {
    if case .completed(let list) = update {
        finalEditList = list
    }
}
```

Replace with:

```swift
for try await update in service.analyze(input: url) {
    if case .completed(let list, _, _) = update {
        finalEditList = list
    }
}
```

The two `_` ignore the new `segments` and `sourceDuration` associated values — the integration test doesn't assert on them; it only verifies the EditList content.

- [ ] **Step 3: Run the test to verify the BUILD fails**

Run: `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SonicMergeTests/SmartCutServiceIntegrationTests 2>&1 | tail -10`

Expected: compile error like `'completed' can only be used with two associated values` or similar — the test now expects 3-arity but the source still has 1-arity.

- [ ] **Step 4: Update the Update enum case**

In `SmartCutService.swift`, change:

```swift
enum Update: Sendable {
    case progress(Double)
    case completed(EditList)
}
```

to:

```swift
enum Update: Sendable {
    case progress(Double)
    case completed(EditList, segments: [TranscriptionState.RecognizedSegment], sourceDuration: TimeInterval)
}
```

Then find the `continuation.yield(.completed(editList))` line near the end of `analyze()`'s Task body. Update it to:

```swift
continuation.yield(.completed(editList, segments: state.recognizedSegments, sourceDuration: state.sourceDuration))
```

(`state` is the `TranscriptionState` variable already in scope — same place that built `editList` from `state.recognizedSegments`.)

- [ ] **Step 5: Verify build + integration test passes (or skips)**

Run: `xcodebuild build -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "(BUILD|error:)" | tail -5`

Expected: `** BUILD SUCCEEDED **`. The integration test gracefully skips when fixture is missing (per current behavior); does not regress.

If the build still fails, the most likely culprit is `SmartCutViewModel.swift` which has `case .completed(let list)` in its analyze handler. That's fixed in Task 2 — for now, you can either temporarily add `, _, _` to the VM's match site (and then properly handle the new args in Task 2), OR commit the failing build IF it's only the VM that fails (the integration test compiled successfully). Recommend: temporarily patch the VM with `case .completed(let list, _, _)` so the build is green, then fully wire it in Task 2.

- [ ] **Step 6: Commit**

```bash
git add SonicMerge/Features/SmartCut/Services/SmartCutService.swift \
        SonicMergeTests/Features/SmartCut/SmartCutServiceIntegrationTests.swift \
        SonicMerge/Features/SmartCut/SmartCutViewModel.swift
git commit -m "feat(scp-t1): extend SmartCutService.Update.completed with segments + duration"
```

(Include the temporary VM patch in this commit so the build is fully green.)

---

### Task 2: SmartCutViewModel — cached segments + setPauseThreshold + tests

**Why:** Slider drag (Task 4) calls `vm.setPauseThreshold($0)`. That method needs the cached recognized segments + source duration to re-run `PauseDetector` without a fresh recognition pass. Cached data is seeded in the analyze completion handler; cleared on `invalidate()` / `requestReanalyze()` to prevent stale cache surviving into a new source's editing session.

**Files:**
- Modify: `SonicMerge/Features/SmartCut/SmartCutViewModel.swift`
- Modify: `SonicMergeTests/Features/SmartCut/SmartCutViewModelTests.swift`

- [ ] **Step 1: Read the ViewModel and existing tests**

```
cat SonicMerge/Features/SmartCut/SmartCutViewModel.swift
cat SonicMergeTests/Features/SmartCut/SmartCutViewModelTests.swift
```

Locate:
- Storage section near the top of the class — where `appliedEditListSnapshot` is declared. The new cache properties go nearby.
- The `analyze()` method body — the `.completed` case match. Currently has the temporary `case .completed(let list, _, _)` patch from Task 1.
- The `invalidate()` method — needs to also clear the cache.
- The `requestReanalyze()` method — currently just calls `invalidate()`; if so the clear happens automatically.
- The `_injectResultsForTesting(_:)` and `_injectAppliedSnapshotForTesting(_:)` test seams — pattern to follow for the new seam.

- [ ] **Step 2: Write the two new failing tests**

Append to `SonicMergeTests/Features/SmartCut/SmartCutViewModelTests.swift` (inside the existing `struct SmartCutViewModelTests`):

```swift
@Test func testSetPauseThresholdReplacesPausesAndPreservesEnabledState() {
    let vm = SmartCutViewModel(coordinator: PlaybackCoordinator(),
                               library: FillerLibrary(defaults: UserDefaults(suiteName: "vm-\(UUID())")!))
    let segments: [TranscriptionState.RecognizedSegment] = [
        .init(text: "hello", startTime: 0, endTime: 1, confidence: 0.9),
        .init(text: "world", startTime: 5, endTime: 6, confidence: 0.9),
    ]
    // Seed the VM as if analyze() had completed with one detected pause that the user disabled.
    vm._injectAnalyzeCompletionForTesting(
        segments: segments,
        duration: 8.0,
        editList: EditList(
            fillers: [],
            pauses: [PauseEdit(timeRange: 1...5, isEnabled: false)]  // user disabled this one
        )
    )
    vm.setPauseThreshold(0.5)  // lower threshold → existing 4s pause survives, possibly trailing-silence too
    let surviving = vm.editList.pauses.first(where: { $0.timeRange.lowerBound == 1.0 })
    #expect(surviving?.isEnabled == false, "user toggle preserved across recompute")
}

@Test func testSetPauseThresholdRecomputesEnabledSavings() {
    let vm = SmartCutViewModel(coordinator: PlaybackCoordinator(),
                               library: FillerLibrary(defaults: UserDefaults(suiteName: "vm-\(UUID())")!))
    let segments: [TranscriptionState.RecognizedSegment] = [
        .init(text: "hello", startTime: 0, endTime: 1, confidence: 0.9),
        .init(text: "world", startTime: 3, endTime: 4, confidence: 0.9),
    ]
    vm._injectAnalyzeCompletionForTesting(segments: segments, duration: 5.0, editList: EditList())
    vm.setPauseThreshold(1.5)  // gap is 2s — above 1.5 → becomes a pause, default-enabled
    #expect(vm.editList.pauses.count == 1)
    #expect(abs(vm.editList.enabledSavings - 2.0) < 0.0001)
    vm.setPauseThreshold(2.5)  // gap is 2s — at-or-below 2.5 → no pause (PauseDetector uses strict >)
    #expect(vm.editList.pauses.isEmpty)
    #expect(vm.editList.enabledSavings == 0.0)
}
```

- [ ] **Step 3: Run tests to verify FAIL**

Run: `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SonicMergeTests/SmartCutViewModelTests 2>&1 | tail -15`

Expected: compile errors — `vm._injectAnalyzeCompletionForTesting` does not exist, `vm.setPauseThreshold` does not exist.

- [ ] **Step 4: Add cached storage + setPauseThreshold + clear-on-invalidate + test seam**

In `SmartCutViewModel.swift`, near the existing `private var appliedEditListSnapshot: EditList?` declaration, add:

```swift
// Cached transcription data for slider-driven pause recompute.
// Seeded in analyze() completion. Cleared in invalidate() / requestReanalyze() so a
// stale cache doesn't survive into a new source's editing session.
private var cachedRecognizedSegments: [TranscriptionState.RecognizedSegment] = []
private var cachedSourceDuration: TimeInterval = 0
```

Replace the existing analyze completion handler. The current code (with the Task 1 patch) looks like:

```swift
case .completed(let list, _, _):
    editList = list
    state = .results
```

Change to:

```swift
case .completed(let list, let segments, let duration):
    cachedRecognizedSegments = segments
    cachedSourceDuration = duration
    editList = list
    state = .results
```

In `invalidate()`, after the existing clears (`editList = EditList()`, etc.), add:

```swift
cachedRecognizedSegments = []
cachedSourceDuration = 0
```

(`requestReanalyze()` already calls `invalidate()`, so it inherits the clear automatically.)

Add the new method (place it near the existing `setEdit(id:enabled:)` method):

```swift
/// Re-run PauseDetector against cached segments and replace editList.pauses.
/// Preserves user toggles for ranges that survive the new threshold (matched by lowerBound).
/// New ranges default to enabled per PauseDetector's default behavior.
/// Pure recomputation — cannot fail; if cachedRecognizedSegments is empty, returns []
/// and editList.pauses becomes empty.
func setPauseThreshold(_ newThreshold: TimeInterval) {
    pauseThreshold = newThreshold
    let recomputed = PauseDetector.detect(
        in: cachedRecognizedSegments,
        totalDuration: cachedSourceDuration,
        threshold: newThreshold
    )
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

Add the new test seam (place it next to the existing `_injectResultsForTesting` and `_injectAppliedSnapshotForTesting`):

```swift
func _injectAnalyzeCompletionForTesting(
    segments: [TranscriptionState.RecognizedSegment],
    duration: TimeInterval,
    editList: EditList
) {
    cachedRecognizedSegments = segments
    cachedSourceDuration = duration
    self.editList = editList
    state = .results
}
```

- [ ] **Step 5: Verify the new tests pass**

Run: `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SonicMergeTests/SmartCutViewModelTests 2>&1 | grep -E "(SUCCEEDED|FAILED|passed|failed)" | tail -15`

Expected: 9/9 PASS (existing 7 + 2 new).

If the runner hangs, reset simulator: `xcrun simctl shutdown all && xcrun simctl erase all`, retry.

- [ ] **Step 6: Commit**

```bash
git add SonicMerge/Features/SmartCut/SmartCutViewModel.swift \
        SonicMergeTests/Features/SmartCut/SmartCutViewModelTests.swift
git commit -m "feat(scp-t2): SmartCutViewModel cached segments + setPauseThreshold + 2 tests"
```

---

### Task 3: SmartCutCardView — split into Summary + Filler cards, SegmentedPill A/B, pulse badge

**Why:** The brief asks for a Summary Card at the top and a separate Filler list card below. The A/B pill becomes a compact `SegmentedPill`. The saves badge gets a subtle pulse animation that's only active when there's something to save.

**Files:**
- Modify: `SonicMerge/Features/SmartCut/SmartCutCardView.swift`

This task does NOT modify `SmartCutViewModel` — it consumes existing `vm.editList`, `vm.isPlayingCleaned`, `vm.toggleCleaned()`. Per spec §6.1, the SegmentedPill is rendered ONLY in `.results` and `.applied` states.

- [ ] **Step 1: Read the existing card to identify the split point**

Read `SonicMerge/Features/SmartCut/SmartCutCardView.swift`. Identify:
- The outer body — currently a single `SquircleCard { VStack { header; content } }`.
- The `statsLine` private property — owns the counts text + SavesBadge (from clt-t3).
- The `abPill` private property — currently `HStack { PillButton("Original"); PillButton("Cleaned") }`.
- The `resultsContent` and `appliedContent` properties — both render `statsLine` + `abPill` + `fillerPanel(dimmed:false)` + `+ Edit filler list` link.
- The `staleContent` property — renders the stale banner + Re-analyze + dimmed `fillerPanel(dimmed: true)`.
- The `idleContent`, `analyzingContent`, `errorContent` properties.

- [ ] **Step 2: Add the new ABSelection enum and binding helper inside SmartCutCardView**

At file scope (NOT inside the struct), or as a private nested enum inside `SmartCutCardView`, add:

```swift
private enum ABSelection: Hashable, CaseIterable {
    case original, cleaned
}
```

Add a private computed binding inside `SmartCutCardView`:

```swift
private var abSelectionBinding: Binding<ABSelection> {
    Binding<ABSelection>(
        get: { vm.isPlayingCleaned ? .cleaned : .original },
        set: { newValue in
            let shouldBeCleaned = (newValue == .cleaned)
            if shouldBeCleaned != vm.isPlayingCleaned {
                vm.toggleCleaned()  // toggles isPlayingCleaned + fires coordinator.notifyPlaying
            }
        }
    )
}
```

- [ ] **Step 3: Replace `abPill` with a SegmentedPill-based view**

Replace the existing `abPill` computed property:

```swift
private var abPill: some View {
    HStack(spacing: 0) {
        Button("Original") { vm.isPlayingCleaned = false; vm.toggleCleaned() }
            .buttonStyle(PillButtonStyle(
                variant: vm.isPlayingCleaned ? .outline : .filled,
                size: .compact, tint: .accent))
        Button("Cleaned") { vm.isPlayingCleaned = true; vm.toggleCleaned() }
            .buttonStyle(PillButtonStyle(
                variant: vm.isPlayingCleaned ? .filled : .outline,
                size: .compact, tint: .accent))
    }
}
```

with:

```swift
private var abPill: some View {
    SegmentedPill(selection: abSelectionBinding) { option in
        switch option {
        case .original: return "Original"
        case .cleaned:  return "Cleaned"
        }
    }
}
```

(Same property name; just a different inner implementation. All call sites that already use `abPill` continue to work.)

- [ ] **Step 4: Add pulse animation to SavesBadge**

Locate the `private struct SavesBadge: View` (added in clt-t3). Replace it with:

```swift
private struct SavesBadge: View {
    let savings: TimeInterval
    @Environment(\.sonicMergeSemantic) private var semantic
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        let isActive = savings > 0
        Text("saves ~\(formatDuration(savings))")
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isActive ? Color(uiColor: semantic.accentAI) : Color.secondary.opacity(0.15))
            )
            .foregroundStyle(isActive ? Color(uiColor: semantic.textPrimary) : .secondary)
            .shadow(color: Color(uiColor: semantic.accentAI).opacity(isActive ? 0.4 : 0), radius: 8)
            .contentTransition(.numericText(value: savings))
            .animation(.snappy(duration: 0.3), value: savings)
            .scaleEffect(pulseScale)
            .onAppear { startPulseIfNeeded(active: isActive) }
            .onChange(of: savings) { _, newValue in
                startPulseIfNeeded(active: newValue > 0)
            }
    }

    private func startPulseIfNeeded(active: Bool) {
        if active {
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                pulseScale = 1.04
            }
        } else {
            // One-shot easeOut to 1.0 cancels any in-flight .repeatForever cleanly.
            withAnimation(.easeOut(duration: 0.2)) {
                pulseScale = 1.0
            }
        }
    }

    private func formatDuration(_ s: TimeInterval) -> String {
        let m = Int(s) / 60
        let sec = Int(s) % 60
        return m > 0 ? "\(m)m \(sec)s" : "\(sec)s"
    }
}
```

If your project's actual semantic-token names differ from `accentAI` / `textPrimary`, use whatever names clt-t3 ended up with — the SavesBadge from that task is the authoritative reference.

- [ ] **Step 5: Restructure the body to two cards**

Currently the body is roughly:

```swift
var body: some View {
    SquircleCard(glassEnabled: false, glowEnabled: false) {
        VStack(alignment: .leading, spacing: 16) {
            header
            content   // switches between idle/analyzing/results/applied/stale/error
        }
    }
    .sheet(isPresented: $showsEditFillerSheet) {
        EditFillerListSheet(library: $library)
    }
}
```

Restructure to:

```swift
var body: some View {
    VStack(spacing: 16) {
        summaryCard
        if shouldShowFillerCard {
            fillerCard
        }
    }
    .sheet(isPresented: $showsEditFillerSheet) {
        EditFillerListSheet(library: $library)
    }
}

private var summaryCard: some View {
    SquircleCard(glassEnabled: false, glowEnabled: false) {
        VStack(alignment: .leading, spacing: 16) {
            header
            summaryContent
        }
    }
}

@ViewBuilder
private var fillerCard: some View {
    SquircleCard(glassEnabled: false, glowEnabled: false) {
        VStack(alignment: .leading, spacing: 16) {
            fillerCardContent
        }
    }
}

private var shouldShowFillerCard: Bool {
    switch vm.state {
    case .results, .applied, .stale: return true
    case .idle, .analyzing, .error:  return false
    }
}
```

Define `summaryContent` and `fillerCardContent` as the two halves of the existing per-state content:

```swift
@ViewBuilder
private var summaryContent: some View {
    switch vm.state {
    case .idle: idleContent
    case .analyzing(let progress): analyzingContent(progress: progress)
    case .results:
        VStack(alignment: .leading, spacing: 12) {
            statsLine                                    // counts + SavesBadge (now pulsing)
            abPill                                       // now SegmentedPill (visible only here)
        }
    case .applied(let saved):
        VStack(alignment: .leading, spacing: 12) {
            statsLine
            Label("Applied · \(formatDuration(saved)) saved", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            abPill
        }
    case .stale: staleSummaryContent                     // banner + re-analyze button (no abPill)
    case .error(let message): errorContent(message: message)
    }
}

@ViewBuilder
private var fillerCardContent: some View {
    switch vm.state {
    case .results:
        VStack(alignment: .leading, spacing: 12) {
            fillerPanel(dimmed: false)
            Button("+ Edit filler list") { showsEditFillerSheet = true }
                .buttonStyle(.borderless)
        }
    case .applied:
        VStack(alignment: .leading, spacing: 12) {
            fillerPanel(dimmed: false)
            Button("+ Edit filler list") { showsEditFillerSheet = true }
                .buttonStyle(.borderless)
        }
    case .stale:
        fillerPanel(dimmed: true)                        // dimmed list per spec §6.5 of original Smart Cut design
    case .idle, .analyzing, .error:
        EmptyView()                                       // shouldShowFillerCard returns false in these states
    }
}

@ViewBuilder
private var staleSummaryContent: some View {
    VStack(alignment: .leading, spacing: 12) {
        Label("Denoise was re-applied", systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
        Text("Smart Cut analysis is stale.")
            .foregroundStyle(.secondary)
        Button("Re-analyze") { vm.requestReanalyze(); vm.analyze() }
            .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
    }
}
```

The previous inline `appliedContent` and `resultsContent` properties can be removed (their logic now lives split across `summaryContent` + `fillerCardContent` per the switch above — `.applied(let saved)` is its own case with the "✓ Applied · Xs saved" label preserved). Keep `idleContent`, `analyzingContent`, `staleContent` (or rename to `staleSummaryContent`), and `errorContent` — they're referenced only from `summaryContent`.

The previous `content` switch can be removed (it's been replaced by `summaryContent` + `fillerCardContent`).

- [ ] **Step 6: Build to verify**

Run: `xcodebuild build -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "(BUILD|error:)" | tail -5`

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Run existing tests to verify no regression**

Run: `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SonicMergeTests/SmartCutViewModelTests 2>&1 | grep -E "(SUCCEEDED|FAILED|passed)" | tail -10`

Expected: 9/9 PASS (the 7 original + the 2 from Task 2). View-layer changes don't touch the VM tests.

- [ ] **Step 8: Commit**

```bash
git add SonicMerge/Features/SmartCut/SmartCutCardView.swift
git commit -m "feat(scp-t3): split SmartCutCardView into Summary + Filler cards; SegmentedPill A/B; pulse badge"
```

---

### Task 4: FillerListPanel — bento border+shadow, strikethrough flip, Slider, onThresholdChange wiring

**Why:** The brief asks for visible bento cards (border + soft shadow), strikethrough + 50% opacity on selected-for-removal occurrences, and a slider with snap-to-0.1s + haptic + counting savings text.

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/FillerListPanel.swift`
- Modify: `SonicMerge/Features/SmartCut/SmartCutCardView.swift` (one-line wiring change for `onThresholdChange` callback)

- [ ] **Step 1: Read FillerListPanel to locate edit points**

Read `SonicMerge/Features/SmartCut/Views/FillerListPanel.swift`. Find:
- The `groupBackground<Content>` helper (added in clt-t4) — needs `.overlay { strokeBorder }` and `.shadow` additions.
- `occurrenceRow(edit:)` — currently has `.opacity(edit.isEnabled ? 1.0 : 0.4)` on text + timestamp. **REMOVE these two `.opacity` lines** and replace with `.strikethrough(edit.isEnabled)` + `.opacity(edit.isEnabled ? 0.5 : 1.0)` (the FLIPPED direction per spec Q1=B).
- `pauseRow` — currently has a `Stepper("", value:..., step: 0.5)`. Replace with a `Slider`.

- [ ] **Step 2: Extend groupBackground with border + soft shadow**

Replace the existing `groupBackground` helper with:

```swift
@ViewBuilder
private func groupBackground<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content()
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
}
```

The diff is the new `.overlay { strokeBorder }` and `.shadow` modifiers — three lines added below the existing `.background`. The `Color(.systemGray6)` and `Color(.separator)` are UIKit semantic colors that adapt to light/dark mode automatically.

- [ ] **Step 3: Flip the opacity direction + add strikethrough in occurrenceRow**

Locate the existing `occurrenceRow(edit:)` body. The current text and timestamp lines look like:

```swift
Text(edit.contextExcerpt)
    .lineLimit(1)
    .opacity(edit.isEnabled ? 1.0 : 0.4)   // CURRENT — DELETE THIS
// ...
Text(formatTimestamp(edit.timeRange.lowerBound))
    .foregroundStyle(.secondary)
    .opacity(edit.isEnabled ? 1.0 : 0.4)   // CURRENT — DELETE THIS
```

Replace with:

```swift
Text(edit.contextExcerpt)
    .lineLimit(1)
    .strikethrough(edit.isEnabled)
    .opacity(edit.isEnabled ? 0.5 : 1.0)
// ...
Text(formatTimestamp(edit.timeRange.lowerBound))
    .foregroundStyle(.secondary)
    .strikethrough(edit.isEnabled)
    .opacity(edit.isEnabled ? 0.5 : 1.0)
```

**Critical:** the old `.opacity(... ? 1.0 : 0.4)` lines must be REMOVED, not stacked — the new mapping fully replaces the old. (Per spec §2 + §6.2.) The play button and checkbox stay full opacity (they remain interactive).

- [ ] **Step 4: Replace the Stepper in pauseRow with a Slider**

Locate `pauseRow`. The current "Threshold: ... Stepper" block looks roughly like:

```swift
HStack {
    Text("Threshold: \(formatThreshold(pauseThreshold))").foregroundStyle(.secondary)
    Stepper("", value: Binding(
        get: { pauseThreshold },
        set: { onThresholdChange($0); pauseThreshold = $0 }
    ), in: 1.0...3.0, step: 0.5)
    .labelsHidden()
}
```

Replace with:

```swift
Slider(
    value: Binding<TimeInterval>(
        get: { pauseThreshold },
        set: { newValue in
            // Snap to 0.1s. Only fire downstream if the snap value actually changed
            // (avoids haptic spam during sub-snap drag jitter).
            let snapped = (newValue * 10).rounded() / 10
            if snapped != pauseThreshold {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                onThresholdChange(snapped)
                pauseThreshold = snapped
            }
        }
    ),
    in: 0.5...3.0
)
.tint(Color(uiColor: semantic.accentAI))  // primary: project's lime green semantic token
// Fallback if semantic palette isn't accessible from this view: .tint(.green) — but the @Environment(\.sonicMergeSemantic) accessor IS available here (see SavesBadge in clt-t3 for the pattern). Use the semantic token first.
```

Two notes:
- The "Threshold: 1.5s" label that previously sat left of the stepper — keep it OR fold the value into the row above (`Trim N long pauses (>1.5s)`). The spec leaves this as an implementation detail; recommend keeping the label below the slider in a small `.caption` foregroundStyle(.secondary) row for clarity:

  ```swift
  Text("Threshold: \(formatThreshold(pauseThreshold))")
      .font(.caption)
      .foregroundStyle(.secondary)
  ```

- The `.tint` color: if `Color(uiColor: semantic.accentAI)` is available in this view's environment (it should be, since clt-t3's SavesBadge uses it via `@Environment(\.sonicMergeSemantic)`), use that. Otherwise `.tint(.green)` is the fallback — the lime green native Color is close enough to the project's accentAI.

- [ ] **Step 5: Add contentTransition + animation to the pause-row "saves" text**

In `pauseRow`, find the existing `Text("saves \(formatTimestamp(savings)))")` (or equivalent). Add:

```swift
Text("saves \(formatTimestamp(savings))")
    .foregroundStyle(.secondary)
    .contentTransition(.numericText(value: savings))
    .animation(.snappy(duration: 0.3), value: savings)
```

The `.contentTransition(.numericText(value:))` modifier rolls the digits smoothly when `savings` changes. The `.animation(.snappy(duration: 0.3), value: savings)` triggers the transition on `savings` mutations. This is the same pattern as the SavesBadge from clt-t3.

- [ ] **Step 6: Wire onThresholdChange to vm.setPauseThreshold in SmartCutCardView**

In `SmartCutCardView.swift`, find the `fillerPanel(dimmed:)` helper that constructs the `FillerListPanel(...)`. The current `onThresholdChange` callback is:

```swift
onThresholdChange: { vm.pauseThreshold = $0 },
```

Change to:

```swift
onThresholdChange: { vm.setPauseThreshold($0) },
```

(The new `vm.setPauseThreshold($0)` sets `pauseThreshold` AND re-runs `PauseDetector` and updates `editList.pauses`. Do NOT leave the old `vm.pauseThreshold = $0` direct write in place — it would cause a double write per spec §6.2 callout.)

- [ ] **Step 7: Build to verify**

Run: `xcodebuild build -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "(BUILD|error:)" | tail -5`

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Run existing tests to verify no regression**

Run: `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SonicMergeTests/SmartCutViewModelTests 2>&1 | grep -E "(SUCCEEDED|FAILED|passed)" | tail -10`

Expected: 9/9 PASS.

- [ ] **Step 9: Commit**

```bash
git add SonicMerge/Features/SmartCut/Views/FillerListPanel.swift \
        SonicMerge/Features/SmartCut/SmartCutCardView.swift
git commit -m "feat(scp-t4): bento border+shadow, strikethrough flip, Slider with snap+haptic+counting savings"
```

---

### Task 5: Manual QA append

**Why:** Manual checklist is the only validation for visual/animation behavior. Append the new section to the existing QA file so the next QA pass exercises the refactor.

**Files:**
- Modify: `docs/superpowers/qa/2026-04-26-smart-cut-manual-qa.md`

- [ ] **Step 1: Append the Premium UI Refactor section**

Append (or create with — file already exists from sc-t20 + clt-t6, so append):

```markdown


---

## Smart Cut Premium UI Refactor (scp-t1..t4)

Run after the Premium UI refactor lands.

### Two-card structure
- [ ] Smart Cut tab shows TWO stacked cards: Summary on top, Filler list below, with ~16pt vertical gap between them.
- [ ] Idle / Analyzing / Error states show ONLY the Summary card (no Filler list card rendered).
- [ ] Stale state shows the Summary card with the stale banner + Re-analyze button, plus the Filler list card with all categories at ~40% opacity.

### Pulsing saves badge
- [ ] In Results / Applied state with `enabledSavings > 0`: the badge subtly pulses (~1.7s cycle, scale ~4%).
- [ ] When the user toggles all rows off and `enabledSavings` drops to 0: badge dims to grey AND the pulse stops cleanly (no frozen mid-cycle scale).
- [ ] Re-enabling rows resumes the pulse smoothly.

### Counting savings animation
- [ ] Toggling individual filler rows causes the badge "saves ~Xs" text to roll smoothly to the new value (no jump-cut).
- [ ] Same rolling animation visible on the pause-row "saves" text below the slider.
- [ ] Toggling category checkboxes (multi-row flip) animates the badge correctly without flicker.

### A/B SegmentedPill
- [ ] In Results / Applied state: A/B compact SegmentedPill replaces the old 2-pill HStack — Original / Cleaned, lime selected, indigo outline unselected.
- [ ] Tapping the pill fires a light haptic.
- [ ] In Idle / Analyzing / Stale / Error: SegmentedPill is NOT visible (no cleaned audio to A/B against in those states).

### Bento card visual treatment
- [ ] Each filler category-block has a visible thin border (1pt, 50% opacity).
- [ ] Each card has a barely-perceptible soft shadow lift (radius 4, opacity 0.05, y 2).
- [ ] The pause row also has the same bento treatment.
- [ ] Cards remain visually quiet — border and shadow do NOT compete with the surface fill.

### Strikethrough + 50% opacity on selected rows
- [ ] Per-occurrence rows where `isEnabled == true` (will be removed) show strikethrough on context excerpt and timestamp + 50% opacity.
- [ ] Per-occurrence rows where `isEnabled == false` (kept) are full opacity, no strikethrough.
- [ ] Play button (▶) stays full opacity in both states (interactive cue intact).
- [ ] Checkbox stays full opacity in both states.
- [ ] Default state (um/uh/ah/er checked): when expanded, all those occurrences show strikethrough + 50%.

### Pause-threshold Slider
- [ ] Slider chassis replaces the old `[-] [+]` Stepper.
- [ ] Range is 0.5s to 3.0s.
- [ ] Drag snaps to 0.1s increments.
- [ ] `.soft` haptic fires on every snap change — and ONLY on snap change (drag staying within the same 0.1s bucket does NOT fire haptic spam).
- [ ] Pause count + savings text updates live as user drags.
- [ ] Summary saves badge ALSO updates live (single source of truth confirmed).

### No regressions
- [ ] Floating Apply Cuts button still works, still glassmorphic, still respects state-based visibility.
- [ ] Re-apply morph after Apply still works (toggle a row → bar shows "Re-apply"; toggle back → bar collapses).
- [ ] Existing haptics unchanged: light on filler toggle, medium on category toggle, heavy on Apply.
- [ ] EditFillerListSheet opens and dismisses cleanly.
- [ ] Per-occurrence ▶ preview still plays a 4s window of original audio.
- [ ] Switching to Denoise tab and back preserves all Smart Cut state (including selected pause-threshold value).
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/qa/2026-04-26-smart-cut-manual-qa.md
git commit -m "docs(scp-t5): append Premium UI Refactor section to manual QA checklist"
```

---

## Wrap-up checklist

- [ ] All 5 tasks committed
- [ ] All existing test suites pass (`xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17'`)
- [ ] SmartCutViewModelTests: 9/9 PASS (7 original + 2 new for setPauseThreshold)
- [ ] SmartCutServiceIntegrationTests: passes (or skips gracefully when fixture missing) — confirms the Update enum arity change didn't break the integration path
- [ ] Manual QA executed against the new "Smart Cut Premium UI Refactor" checklist
- [ ] No new TODO markers in committed code
- [ ] Spec referenced in commit messages: `docs/superpowers/specs/2026-04-26-smartcut-premium-ui-design.md`
