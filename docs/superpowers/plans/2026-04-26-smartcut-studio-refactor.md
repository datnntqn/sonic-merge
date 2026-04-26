---
plan: smartcut-studio-refactor
date: 2026-04-26
branch: phase-12-smartcut-studio-refactor
spec: docs/superpowers/specs/2026-04-26-smartcut-studio-refactor-design.md
---

# Smart Cut Studio Refactor Implementation Plan

> **For agentic workers:** REQUIRED: Use `superpowers:subagent-driven-development` (if subagents available) or `superpowers:executing-plans` to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Smart Cut tab's view layer with a "Modern Spatial AI Studio" aesthetic — glassmorphic summary card with pulsing saves badge, single-column wide bento cards (filler groups + pauses), tap-to-detail-sheet for occurrences, unified tag-capsule pool for the filler library editor — backed by foundational ViewModel/service additions for live-recompute pause threshold and a non-breaking SegmentedPill tint enhancement.

**Architecture:** Eight independent chunks, each producing one atomic commit. Chunk 1 ships the foundational behavior (cached recognized segments, `setPauseThreshold(_:)` recompute, `Update.completed` payload extension) with TDD. Chunks 2–7 build new visual primitives in isolation under `SonicMerge/Features/SmartCut/Views/Studio/`. Chunk 8 integrates everything into `CleaningLabView`, audits color on existing entry-point links, and retires the three old view files. Old files retire only in the final chunk so partial reverts during review remain possible.

**Tech Stack:** SwiftUI (iOS 17+), `@Observable` model, `TimelineView` for pulsing badge animation, `Layout` protocol for tag wrap-flow, `MeshGradient`/`Material` (iOS 17 baseline; iOS 18 features behind `#available` guards per Phase 11 pattern), `AVAudioPlayer` for the 4s preview, `UIImpactFeedbackGenerator` for haptics, Swift Testing for the 4 new VM tests in Chunk 1.

**Reference skills:** @superpowers:test-driven-development (Chunk 1 only — view chunks have no unit tests by design, see spec §8), @superpowers:verification-before-completion (build + regression + human device pass before claiming complete), @superpowers:systematic-debugging (if any chunk fails build).

**Test strategy:** Same baseline as Phase 11. Build verify per chunk. **Chunk 1 adds 4 unit tests** for `setPauseThreshold` covering: no-op when cached segments empty, threshold update, pause rebuild, and toggle preservation. Other chunks are visual-only — covered by manual device pass on iPhone 17 Sim (iOS 26.2). Regression baseline: 53 passes / 5 pre-existing failures (3× ShareExtension, 1× ABPlayback, 1× AudioMergerService crossfade). After Chunk 1, baseline becomes 57 passes / 5 fails. After all 8 chunks, expect 57/5.

---

## File Structure

| File | Action | Chunk | Reason |
|------|--------|-------|--------|
| `SonicMerge/Features/SmartCut/Services/SmartCutService.swift` | Modify | 1 | Extend `Update.completed` payload to carry segments + duration |
| `SonicMerge/Features/SmartCut/SmartCutViewModel.swift` | Modify | 1 | Cache segments+duration; add `setPauseThreshold(_:)` |
| `SonicMergeTests/Features/SmartCut/SmartCutServiceIntegrationTests.swift` | Modify | 1 | Update one switch case for new payload |
| `SonicMergeTests/Features/SmartCut/SmartCutViewModelTests.swift` | Modify | 1 | Add 4 `setPauseThreshold` tests (TDD red→green) |
| `SonicMerge/DesignSystem/SegmentedPill.swift` | Modify | 2 | Add optional `selectedTint` / `unselectedTint` parameters |
| `SonicMerge/Features/SmartCut/Views/Studio/SmartCutFormatting.swift` | Create | 3 | Free helpers: `formatTimestamp`, `formatThreshold` (lifted from `FillerListPanel`) |
| `SonicMerge/Features/SmartCut/Views/Studio/StudioGlassChrome.swift` | Create | 3 | View modifiers `studioGlassCard()`, `studioFrostedCapsule()` |
| `SonicMerge/Features/SmartCut/Views/Studio/StudioFlowLayout.swift` | Create | 3 | SwiftUI `Layout` for capsule wrap-flow (RTL-aware) |
| `SonicMerge/Features/SmartCut/Views/Studio/StudioSummaryCard.swift` | Create | 4 | Glassmorphic card: eyebrow + stats + pulse badge + Reset link |
| `SonicMerge/Features/SmartCut/Views/Studio/StudioPulseSavesBadge.swift` | Create | 4 | TimelineView-driven scale + glow saves badge |
| `SonicMerge/Features/SmartCut/Views/Studio/StudioBentoCard.swift` | Create | 5 | Generic 28pt squircle bento chassis with disabled state |
| `SonicMerge/Features/SmartCut/Views/Studio/FillerCategoryRow.swift` | Create | 5 | Filler bento card content (count + word + saves chip + group toggle + tap-to-sheet) |
| `SonicMerge/Features/SmartCut/Views/Studio/PauseControlRow.swift` | Create | 5 | Pauses bento card content (slider + rolling-digit + saves chip) |
| `SonicMerge/Features/SmartCut/Views/Studio/FillerOccurrenceSheet.swift` | Create | 6 | Detail sheet (header + capsule occurrence rows + ▶ preview + Disable-all link) |
| `SonicMerge/Features/SmartCut/Models/FillerLibrary.swift` | Modify | 7 | Add `restoreAllDefaults()` (one line) |
| `SonicMerge/Features/SmartCut/Views/Studio/EditFillerListStudioSheet.swift` | Create | 7 | Unified-pool tag editor with add input |
| `SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift` | Create | 8 | Top-level state-machine view replacing `SmartCutCardView` body |
| `SonicMerge/Features/Denoising/CleaningLabView.swift` | Modify | 8 | Swap callsite at line ~211; color audit on `+ Edit filler list` link |
| `SonicMerge/Features/SmartCut/SmartCutCardView.swift` | Delete | 8 | Retired |
| `SonicMerge/Features/SmartCut/Views/FillerListPanel.swift` | Delete | 8 | Retired |
| `SonicMerge/Features/SmartCut/Views/EditFillerListSheet.swift` | Delete | 8 | Retired |

**No new SwiftData models. No new Swift package dependencies.**

---

## Pre-flight

- [ ] **P0: Verify on `main` and clean of Phase-12-relevant changes.**

  Run: `git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge branch --show-current`
  Expected: `main`. The standing `.xcuserstate` modification is fine to leave.

- [ ] **P1: Create branch from main.**

  Run: `git checkout -b phase-12-smartcut-studio-refactor main`
  Expected: `Switched to a new branch 'phase-12-smartcut-studio-refactor'`

- [ ] **P2: Baseline build + test.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/sm-p12-baseline.log | tail -8
  echo "PASS=$(grep -cE '✔ Test .* passed' /tmp/sm-p12-baseline.log | sort -u | wc -l)"
  echo "FAIL=$(grep -E '✘ Test .* failed' /tmp/sm-p12-baseline.log | sort -u | wc -l)"
  ```
  Expected: `** TEST FAILED **` with exactly **5 unique** failures (3× ShareExtension `testFileCopyToClipsDirectory` / `testLargeFileCopyDoesNotCrash` / `testPendingKeyWrittenAndCleared`; 1× `testPositionPreservedOnSwitch`; 1× `compositionWithCrossfadeHasNonNilAudioMix`) and the rest passing. Anything else means main has drifted — investigate before proceeding.

---

## Chunk 1: Foundational service + ViewModel — `Update.completed` payload + `setPauseThreshold(_:)`

Spec refs: §1 (point 1), §2 first two goal bullets, §4.2 "ViewModel additions" + "SmartCutService.Update enum addition".

This chunk ships the foundational behavior in three steps: (1) extend `SmartCutService.Update.completed` payload to carry segments + duration; (2) update the only consumer (`SmartCutViewModel.analyze` switch) and the integration test; (3) cache the new state in the ViewModel + add `setPauseThreshold(_:)` with TDD covering 4 cases. One atomic commit at the end.

**Files (in order of edits):**
- Modify: `SonicMerge/Features/SmartCut/Services/SmartCutService.swift`
- Modify: `SonicMerge/Features/SmartCut/SmartCutViewModel.swift`
- Modify: `SonicMergeTests/Features/SmartCut/SmartCutServiceIntegrationTests.swift`
- Modify: `SonicMergeTests/Features/SmartCut/SmartCutViewModelTests.swift`

### Task 1.1: Extend `SmartCutService.Update.completed` payload

- [ ] **Step 1: Read SmartCutService.swift to confirm landmarks.**

  Use Read on `SonicMerge/Features/SmartCut/Services/SmartCutService.swift`. Expected: an `enum Update` (around lines 5–10) with two cases `progress(Double)` and `completed(EditList)`. The `analyze(input:)` method emits these via an `AsyncThrowingStream`. The internal flow already calls `PauseDetector.detect(in: state.recognizedSegments, totalDuration: <duration>, threshold: ...)` (visible at lines 37 and 42 per the prior grep), so segments + duration are already in scope inside the analyze function — just need to plumb them into the `.completed` value.

- [ ] **Step 2: Modify the `Update` enum to add segments + duration to `.completed`.**

  Use Edit. Old string:
  ```swift
  case completed(EditList)
  ```
  New string:
  ```swift
  case completed(EditList, segments: [TranscriptionState.RecognizedSegment], duration: TimeInterval)
  ```

- [ ] **Step 3: Update the emit-site inside `analyze(input:)` to include the new payload.**

  The emit-site is at `SmartCutService.swift:47`. The duration identifier is `state.sourceDuration` (verified — same identifier passed to `PauseDetector.detect` at line 43).

  Use Edit. Old string:
  ```swift
                      continuation.yield(.completed(editList))
  ```
  New string:
  ```swift
                      continuation.yield(.completed(editList, segments: state.recognizedSegments, duration: state.sourceDuration))
  ```

- [ ] **Step 4: Verify build (will fail at the consumer site — that's expected).**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -10; echo "EXIT=$?"
  ```
  Expected: build FAILS at `SmartCutViewModel.swift:130` (the switch case `.completed(let list)`) with a "missing argument" or "tuple shape mismatch" error. If it builds clean, the consumer is somehow already adapted — investigate before proceeding.

### Task 1.2: Update the only consumer — `SmartCutViewModel.analyze` switch

- [ ] **Step 1: Read `SmartCutViewModel.swift` lines 124–142 to confirm the switch shape.**

  Confirm exactly:
  ```swift
  for try await update in await service.analyze(input: inputURL) {
      if Task.isCancelled { return }
      switch update {
      case .progress(let p):
          state = .analyzing(progress: p)
      case .completed(let list):
          editList = list
          state = .results
      }
  }
  ```

- [ ] **Step 2: Replace the `.completed` case to capture segments + duration into new ViewModel storage.**

  Use Edit. Old string:
  ```swift
          case .completed(let list):
              editList = list
              state = .results
  ```
  New string:
  ```swift
          case .completed(let list, let segments, let duration):
              editList = list
              cachedSegments = segments
              cachedDuration = duration
              state = .results
  ```

- [ ] **Step 3: Add the two cached storage properties to the ViewModel.**

  Use Edit. Find the property declaration block near the top of the class (around lines 22–34, after `private(set) var editList = EditList()`). Add the two new properties.

  Old string:
  ```swift
      private(set) var editList = EditList()
      private(set) var inputURL: URL?
  ```
  New string:
  ```swift
      private(set) var editList = EditList()
      private(set) var cachedSegments: [TranscriptionState.RecognizedSegment] = []
      private(set) var cachedDuration: TimeInterval = 0
      private(set) var inputURL: URL?
  ```

- [ ] **Step 4: Verify build now succeeds for the main target.**

  Run the same xcodebuild command as Task 1.1 Step 4. Expected: `** BUILD SUCCEEDED **` and `EXIT=0`.

- [ ] **Step 5: Read `SmartCutServiceIntegrationTests.swift` line 23 area to find the consumer.**

  Use Read on `SonicMergeTests/Features/SmartCut/SmartCutServiceIntegrationTests.swift`. Find the test that consumes the `Update.completed` case. Likely shape:
  ```swift
  for try await update in stream {
      if case .completed(let list) = update { resultList = list }
  }
  ```

- [ ] **Step 6: Update the test's pattern match to accept the new payload.**

  Use Edit (specific old/new strings depend on what Step 5 found; the change is purely a pattern match update). If the test only cares about the `EditList` portion:
  ```swift
  // Old
  if case .completed(let list) = update { resultList = list }
  // New
  if case .completed(let list, _, _) = update { resultList = list }
  ```

- [ ] **Step 7: Verify the test target builds.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build-for-testing 2>&1 | tail -5; echo "EXIT=$?"
  ```
  Expected: `** TEST BUILD SUCCEEDED **` and `EXIT=0`.

### Task 1.3: TDD `setPauseThreshold(_:)` — write 4 failing tests

@superpowers:test-driven-development applies for this entire task. Each test is written, run (must FAIL), then the implementation step covers them all in one go (since they exercise the same method).

- [ ] **Step 1: Read `SmartCutViewModelTests.swift` to find a good insertion point for new tests.**

  Use Read on `SonicMergeTests/Features/SmartCut/SmartCutViewModelTests.swift`. Note the test framework (Swift Testing — `@Test`, `#expect`) and how the existing tests construct the VM (likely via the `_injectResultsForTesting(_:)` test seam).

- [ ] **Step 2: Add a test fixture helper for cached state injection.**

  The `cachedSegments` and `cachedDuration` properties added in Task 1.2 are `private(set)`. To exercise `setPauseThreshold` without running a real `analyze()`, add a one-line test seam to the ViewModel that mirrors `_injectResultsForTesting`.

  Use Edit on `SonicMerge/Features/SmartCut/SmartCutViewModel.swift`. Old string (the existing test seams near the bottom):
  ```swift
      func _injectResultsForTesting(_ list: EditList) {
          editList = list
          state = .results
      }

      func _injectAppliedSnapshotForTesting(_ list: EditList) {
          appliedEditListSnapshot = list
      }
  ```
  New string:
  ```swift
      func _injectResultsForTesting(_ list: EditList) {
          editList = list
          state = .results
      }

      func _injectAppliedSnapshotForTesting(_ list: EditList) {
          appliedEditListSnapshot = list
      }

      func _injectCachedTranscriptionForTesting(
          segments: [TranscriptionState.RecognizedSegment],
          duration: TimeInterval
      ) {
          cachedSegments = segments
          cachedDuration = duration
      }
  ```

- [ ] **Step 3: Add the 4 new tests as a fresh `@Suite` block at the bottom of `SmartCutViewModelTests.swift`.**

  Use Edit (or Write the full new content if simpler). The 4 tests:

  ```swift
  @Suite("SmartCutViewModel.setPauseThreshold")
  @MainActor
  struct SmartCutViewModelSetPauseThresholdTests {

      // Build a fixture VM with cached segments simulating a real recognition result.
      // Two speech segments separated by a 2.0s gap and bordered by 1.0s pre/post silence
      // over a 10.0s source. With threshold 1.5s we expect ONLY the inter-segment 2.0s gap
      // to be detected. With threshold 0.8s we'd additionally detect the 1.0s pre/post gaps.
      private func makeVM() -> SmartCutViewModel {
          let coordinator = PlaybackCoordinator()
          let library = FillerLibrary(defaults: UserDefaults(suiteName: "TestSuite-\(UUID())")!)
          let vm = SmartCutViewModel(coordinator: coordinator, library: library)
          let segments: [TranscriptionState.RecognizedSegment] = [
              .init(text: "hello", startTime: 1.0, endTime: 4.0, confidence: 0.9),
              .init(text: "world", startTime: 6.0, endTime: 9.0, confidence: 0.9)
          ]
          vm._injectCachedTranscriptionForTesting(segments: segments, duration: 10.0)
          return vm
      }

      @Test("Returns no-op when cached segments are empty (per spec: full no-op, including threshold)")
      func setPauseThreshold_noCache_isNoop() {
          let coordinator = PlaybackCoordinator()
          let library = FillerLibrary(defaults: UserDefaults(suiteName: "TestSuite-\(UUID())")!)
          let vm = SmartCutViewModel(coordinator: coordinator, library: library)
          // No cached injection.
          let priorPauses = vm.editList.pauses
          let priorThreshold = vm.pauseThreshold
          vm.setPauseThreshold(2.5)
          #expect(vm.editList.pauses == priorPauses)
          #expect(vm.pauseThreshold == priorThreshold)  // Spec: full no-op when no cache.
      }

      @Test("Updates pauseThreshold and rebuilds editList.pauses from cached segments")
      func setPauseThreshold_rebuildsPauses() {
          let vm = makeVM()
          vm.setPauseThreshold(1.5)
          #expect(vm.pauseThreshold == 1.5)
          // With 1.5s threshold: gap from 4.0→6.0 (2.0s) is detected; 1.0s pre/post are below.
          #expect(vm.editList.pauses.count == 1)
          #expect(vm.editList.pauses.first?.timeRange == 4.0...6.0)
      }

      @Test("Rebuild detects more pauses when threshold lowers")
      func setPauseThreshold_lowerThresholdDetectsMore() {
          let vm = makeVM()
          vm.setPauseThreshold(1.5)  // 1 pause: 4.0...6.0
          vm.setPauseThreshold(0.8)  // Should detect the 1.0s pre + 1.0s post too
          #expect(vm.editList.pauses.count == 3)
      }

      @Test("Preserves user's isEnabled flags on surviving pauses across recompute")
      func setPauseThreshold_preservesUserToggles() {
          let vm = makeVM()
          vm.setPauseThreshold(1.5)  // 1 pause: 4.0...6.0, isEnabled=true (detector default)
          // User disables the detected pause.
          vm.setEdit(id: vm.editList.pauses[0].id, enabled: false)
          #expect(vm.editList.pauses[0].isEnabled == false)
          // User drags slider: same 4.0...6.0 pause survives at threshold 1.7s
          // (still > 1.7s); should retain isEnabled=false.
          vm.setPauseThreshold(1.7)
          #expect(vm.editList.pauses.count == 1)
          #expect(vm.editList.pauses.first?.timeRange == 4.0...6.0)
          #expect(vm.editList.pauses.first?.isEnabled == false)
      }
  }
  ```

  **Note on `RecognizedSegment` initializer signature:** verified against `SonicMerge/Features/SmartCut/Models/TranscriptionState.swift:35-40` — the struct has `let text: String, startTime: TimeInterval, endTime: TimeInterval, confidence: Float`. The snippet above uses `confidence: 0.9` (any non-zero placeholder works since the test doesn't exercise confidence). Also note: `EditList.setEdit(id:enabled:)` (`Models/EditList.swift:54-62`) handles BOTH filler IDs AND pause IDs, so the toggle-preservation test (`setPauseThreshold_preservesUserToggles`) correctly mutates a pause via the existing `vm.setEdit` API.

- [ ] **Step 4: Run the new tests to verify they FAIL with "no such method" / unresolved-symbol on `setPauseThreshold`.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:SonicMergeTests/SmartCutViewModelSetPauseThresholdTests \
    -parallel-testing-enabled NO test 2>&1 | tail -15
  ```
  Expected: compilation FAILS at `vm.setPauseThreshold(...)` with "value of type 'SmartCutViewModel' has no member 'setPauseThreshold'". If somehow it compiles, the symbol must already exist — confirm before proceeding.

### Task 1.4: Implement `setPauseThreshold(_:)` to make the tests pass

- [ ] **Step 1: Add `setPauseThreshold(_:)` to the ViewModel.**

  Use Edit. Find the `// MARK: User curation` block (line 167–177 in the read earlier — `setCategory` and `setEdit` live there). Add `setPauseThreshold` immediately after `setEdit`.

  Old string:
  ```swift
      func setEdit(id: String, enabled: Bool) {
          editList.setEdit(id: id, enabled: enabled)
          UIImpactFeedbackGenerator(style: .light).impactOccurred()
      }
  ```
  New string:
  ```swift
      func setEdit(id: String, enabled: Bool) {
          editList.setEdit(id: id, enabled: enabled)
          UIImpactFeedbackGenerator(style: .light).impactOccurred()
      }

      /// Phase 12 (Studio): live-recompute the pause set when the user drags the
      /// threshold slider. Clamps to the slider's range, updates the public
      /// pauseThreshold, then re-runs PauseDetector against the cached segments
      /// captured at .completed. Preserves user isEnabled toggles by exact id-string
      /// match (PauseEdit.id is "pause@\(lowerBound)" and PauseDetector is
      /// deterministic for the same cached segments — surviving pauses keep the
      /// identical id). Does NOT fire a haptic itself; haptic responsibility lives
      /// in the caller (PauseControlRow.onChange).
      func setPauseThreshold(_ seconds: TimeInterval) {
          // Per spec: full no-op when there are no cached segments yet (i.e., before
          // first .completed). Both threshold AND pauses stay untouched in that case.
          guard !cachedSegments.isEmpty else { return }
          let clamped = min(max(seconds, 1.0), 3.0)
          pauseThreshold = clamped
          let priorIsEnabledById: [String: Bool] = Dictionary(
              uniqueKeysWithValues: editList.pauses.map { ($0.id, $0.isEnabled) }
          )
          let detected = PauseDetector.detect(
              in: cachedSegments,
              totalDuration: cachedDuration,
              threshold: clamped
          )
          editList.pauses = detected.map { p in
              if let prior = priorIsEnabledById[p.id], prior != p.isEnabled {
                  return PauseEdit(timeRange: p.timeRange, isEnabled: prior)
              }
              return p
          }
      }
  ```

- [ ] **Step 2: Run the 4 new tests; verify all PASS.**

  Run the same `-only-testing` xcodebuild command as Task 1.3 Step 4. Expected: 4 passes, 0 failures.

  If any test fails, read its assertion vs the actual output to debug. Common failure modes: (a) `RecognizedSegment` initializer signature mismatch (fix Task 1.3 fixture); (b) `PauseDetector.detect` returns empty when expected — confirm threshold-vs-gap-size math (the detector uses strict `>` comparison; gap of 2.0 with threshold 1.5 → 2.0 > 1.5 → detected ✓; gap of 1.0 with threshold 0.8 → 1.0 > 0.8 → detected ✓).

- [ ] **Step 3: Run the FULL test suite to confirm no regression.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/sm-p12-c1.log | tail -8
  echo "PASS=$(grep -E '✔ Test .* passed' /tmp/sm-p12-c1.log | sort -u | wc -l)"
  echo "FAIL=$(grep -E '✘ Test .* failed' /tmp/sm-p12-c1.log | sort -u | wc -l)"
  ```
  Expected: `PASS=57` (53 baseline + 4 new), `FAIL=5` (same baseline failures). Anything else means regression — bisect by removing the new tests / new method.

### Task 1.5: Commit Chunk 1

- [ ] **Step 1: Commit.**

  ```bash
  git add SonicMerge/Features/SmartCut/Services/SmartCutService.swift \
          SonicMerge/Features/SmartCut/SmartCutViewModel.swift \
          SonicMergeTests/Features/SmartCut/SmartCutServiceIntegrationTests.swift \
          SonicMergeTests/Features/SmartCut/SmartCutViewModelTests.swift
  git commit -m "$(cat <<'EOF'
  feat(12-w1): cached segments + setPauseThreshold for live pause recompute

  Foundational behavior addition for the Studio refactor's live-recompute
  pause slider UX. Three pieces:

  1. SmartCutService.Update.completed now carries the recognized segments
     and source duration alongside the EditList. The service already had
     both internally — this just propagates them outward. Sole consumer
     (SmartCutViewModel.analyze switch) and one integration test updated
     for the new pattern shape.
  2. SmartCutViewModel caches the new payload as private(set) state
     (cachedSegments, cachedDuration) on .completed.
  3. New SmartCutViewModel.setPauseThreshold(_:) clamps to 1.0...3.0,
     updates pauseThreshold, runs PauseDetector against the cached
     segments, and replaces editList.pauses while preserving user's
     isEnabled toggles by exact id-string match (PauseEdit.id is
     "pause@\(lowerBound)" and PauseDetector is deterministic for the
     same cached input — surviving pauses keep the same id). VM does
     NOT fire haptic; haptic is the caller's responsibility (lives in
     PauseControlRow once Chunk 5 ships).

  Plus 4 new Swift Testing tests for setPauseThreshold covering: no-op
  when cache empty (still updates threshold itself), pause rebuild on
  recompute, lower-threshold-detects-more, and toggle preservation
  across recompute.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Chunk 2: `SegmentedPill` tint enhancement

Spec refs: §1 (last paragraph), §4.2 "SegmentedPill enhancement".

Add two **optional** parameters to `SegmentedPill` (`selectedTint` / `unselectedTint`) with defaults that preserve current behavior. Studio call-sites (Chunk 8) will pass `.accent` / `.accent` for Deep Indigo selected. Existing call-sites (Cleaning Lab tabs, AI Denoise/Smart Cut switcher) inherit unchanged behavior.

**Files:**
- Modify: `SonicMerge/DesignSystem/SegmentedPill.swift`

### Task 2.1: Add tint parameters

- [ ] **Step 1: Read `SegmentedPill.swift` to confirm landmarks.**

  Use Read on `SonicMerge/DesignSystem/SegmentedPill.swift`. Confirm: struct generic over `Option: Hashable & CaseIterable`, declared `@Binding var selection: Option`, `let label: (Option) -> String`. The tint application is at line 44: `tint: isSelected ? .ai : .accent`. `PillButtonStyle.Tint` enum has `.accent` and `.ai` cases.

- [ ] **Step 2: Add the two optional parameters with defaults matching today's hardcoded behavior.**

  Use Edit. Old string:
  ```swift
  struct SegmentedPill<Option: Hashable & CaseIterable>: View
      where Option.AllCases: RandomAccessCollection
  {
      @Binding var selection: Option
      let label: (Option) -> String
  ```
  New string:
  ```swift
  struct SegmentedPill<Option: Hashable & CaseIterable>: View
      where Option.AllCases: RandomAccessCollection
  {
      @Binding var selection: Option
      let label: (Option) -> String
      /// Tint for the selected segment. Defaults to `.ai` (Lime Green) — matches
      /// pre-Phase-12 behavior; existing call-sites inherit unchanged.
      var selectedTint: PillButtonStyle.Tint = .ai
      /// Tint for unselected segments. Defaults to `.accent` (Deep Indigo).
      var unselectedTint: PillButtonStyle.Tint = .accent
  ```

- [ ] **Step 3: Wire the parameters through to the `PillButtonStyle` instantiation.**

  Use Edit. Old string:
  ```swift
              .buttonStyle(PillButtonStyle(
                  variant: isSelected ? .filled : .outline,
                  size: .compact,
                  tint: isSelected ? .ai : .accent
              ))
  ```
  New string:
  ```swift
              .buttonStyle(PillButtonStyle(
                  variant: isSelected ? .filled : .outline,
                  size: .compact,
                  tint: isSelected ? selectedTint : unselectedTint
              ))
  ```

- [ ] **Step 4: Verify build.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -3; echo "EXIT=$?"
  ```
  Expected: `** BUILD SUCCEEDED **` and `EXIT=0`. Existing call-sites in Cleaning Lab compile unchanged because the new params have defaults.

### Task 2.2: Commit Chunk 2

- [ ] **Step 1: Commit.**

  ```bash
  git add SonicMerge/DesignSystem/SegmentedPill.swift
  git commit -m "$(cat <<'EOF'
  feat(12-w2): SegmentedPill optional tint parameters (non-breaking)

  Adds two optional parameters — selectedTint and unselectedTint — to
  SegmentedPill, both defaulting to the previously-hardcoded values
  (.ai for selected, .accent for unselected). Existing call-sites
  (Cleaning Lab tabs, AI Denoise/Smart Cut switcher) inherit unchanged
  behavior since defaults match the prior code.

  This unblocks Chunk 8's Original/Cleaned A/B picker, which will pass
  selectedTint: .accent, unselectedTint: .accent so the selected segment
  reads filled Deep Indigo per the brief ("selected segment is Deep
  Indigo").

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Chunk 3: Studio chrome primitives — formatting, glass card/capsule, flow layout

Spec refs: §4.1 file table (last 3 rows of Studio/), §4.3 "Glass chrome primitives".

Three new files in `SonicMerge/Features/SmartCut/Views/Studio/`. Each has a single responsibility; consumed by chunks 4–7. No call-site integration in this chunk — the new types are used only by later chunks. Files are added via `fileSystemSynchronizedGroups` (no `project.pbxproj` edit needed; pattern verified in Phase 10/11).

**Files:**
- Create: `SonicMerge/Features/SmartCut/Views/Studio/SmartCutFormatting.swift`
- Create: `SonicMerge/Features/SmartCut/Views/Studio/StudioGlassChrome.swift`
- Create: `SonicMerge/Features/SmartCut/Views/Studio/StudioFlowLayout.swift`

### Task 3.1: Create `SmartCutFormatting.swift`

- [ ] **Step 1: Write the file.**

  Use Write to create `SonicMerge/Features/SmartCut/Views/Studio/SmartCutFormatting.swift`:

  ```swift
  // SmartCutFormatting.swift
  // SonicMerge
  //
  // Phase 12 (Smart Cut Studio Refactor): formatting helpers shared by the
  // new Studio views. Lifted verbatim from FillerListPanel's private helpers
  // (lines 136-144 of the now-retired file) so they don't get orphaned when
  // FillerListPanel is deleted in Chunk 8.

  import Foundation

  enum SmartCutFormatting {

      /// "0:20" / "12:34" minute:second timestamp.
      static func formatTimestamp(_ seconds: TimeInterval) -> String {
          let m = Int(seconds) / 60
          let s = Int(seconds) % 60
          return String(format: "%d:%02d", m, s)
      }

      /// "1.5s" threshold readout.
      static func formatThreshold(_ seconds: TimeInterval) -> String {
          String(format: "%.1fs", seconds)
      }
  }
  ```

- [ ] **Step 2: Verify build.**

  Run the build command. Expected: `** BUILD SUCCEEDED **`.

### Task 3.2: Create `StudioGlassChrome.swift`

- [ ] **Step 1: Write the file.**

  Use Write to create `SonicMerge/Features/SmartCut/Views/Studio/StudioGlassChrome.swift`:

  ```swift
  // StudioGlassChrome.swift
  // SonicMerge
  //
  // Phase 12 (Smart Cut Studio Refactor): two reusable view modifiers that
  // produce the layered-glass surfaces called out in the design spec
  // (§4.3): a glassmorphic outer card chassis and a frosted capsule for
  // tag-style chips. Both honor accessibilityReduceTransparency by swapping
  // the material for an opaque surface — same pattern as Phase 10/11.

  import SwiftUI
  import UIKit

  // MARK: - Modifiers

  private struct StudioGlassCardModifier: ViewModifier {
      let cornerRadius: CGFloat
      @Environment(\.sonicMergeSemantic) private var semantic
      @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

      func body(content: Content) -> some View {
          content
              .background(
                  RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                      .fill(reduceTransparency
                          ? AnyShapeStyle(Color(uiColor: semantic.surfaceCard))
                          : AnyShapeStyle(.ultraThinMaterial))
              )
              .overlay(
                  RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                      .stroke(
                          Color(uiColor: semantic.accentGlow)
                              .opacity(reduceTransparency ? 0.30 : 0.18),
                          lineWidth: 1
                      )
              )
              .shadow(
                  color: Color(uiColor: semantic.accentGlow).opacity(0.10),
                  radius: 16, x: 0, y: 6
              )
      }
  }

  private struct StudioFrostedCapsuleModifier: ViewModifier {
      let cornerRadius: CGFloat
      @Environment(\.sonicMergeSemantic) private var semantic
      @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

      func body(content: Content) -> some View {
          content
              .background(
                  RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                      .fill(reduceTransparency
                          ? AnyShapeStyle(Color(uiColor: semantic.surfaceCard))
                          : AnyShapeStyle(.ultraThinMaterial))
              )
              .overlay(
                  RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                      .stroke(
                          Color(uiColor: semantic.accentAction)
                              .opacity(reduceTransparency ? 0.35 : 0.20),
                          lineWidth: 1
                      )
              )
      }
  }

  // MARK: - View extensions

  extension View {
      /// Phase 12: glass card chassis used by StudioSummaryCard and StudioBentoCard.
      /// 24pt corner radius default; bento card overrides to 28pt.
      func studioGlassCard(cornerRadius: CGFloat = 24) -> some View {
          modifier(StudioGlassCardModifier(cornerRadius: cornerRadius))
      }

      /// Phase 12: frosted capsule used by tag chips, occurrence sheet rows,
      /// and the saves chip.
      func studioFrostedCapsule(cornerRadius: CGFloat = 14) -> some View {
          modifier(StudioFrostedCapsuleModifier(cornerRadius: cornerRadius))
      }
  }
  ```

- [ ] **Step 2: Verify build.**

  Run the build command. Expected: `** BUILD SUCCEEDED **`.

### Task 3.3: Create `StudioFlowLayout.swift`

- [ ] **Step 1: Write the file.**

  Use Write to create `SonicMerge/Features/SmartCut/Views/Studio/StudioFlowLayout.swift`:

  ```swift
  // StudioFlowLayout.swift
  // SonicMerge
  //
  // Phase 12 (Smart Cut Studio Refactor): wrap-flow Layout for the unified
  // tag-capsule pool in EditFillerListStudioSheet. Each row left-aligns
  // (or right-aligns under RTL) and wraps to a new row when the next item
  // would exceed the proposed width. ~50 LoC; pure presentation, no behavior.

  import SwiftUI

  struct StudioFlowLayout: Layout {
      var spacing: CGFloat = 8

      func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
          let width = proposal.width ?? .infinity
          var rows: [[CGSize]] = [[]]
          var currentX: CGFloat = 0

          for subview in subviews {
              let size = subview.sizeThatFits(.unspecified)
              if currentX + size.width > width && !rows[rows.count - 1].isEmpty {
                  rows.append([size])
                  currentX = size.width + spacing
              } else {
                  rows[rows.count - 1].append(size)
                  currentX += size.width + spacing
              }
          }

          let totalHeight: CGFloat = rows.reduce(0) { acc, row in
              let rowHeight = row.map(\.height).max() ?? 0
              return acc + rowHeight + (acc > 0 ? spacing : 0)
          }
          let widestRow: CGFloat = rows.map { row in
              row.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(0, row.count - 1))
          }.max() ?? 0

          return CGSize(width: min(widestRow, width), height: totalHeight)
      }

      func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
          // RTL is handled by the SwiftUI parent applying
          // .environment(\.layoutDirection, .rightToLeft) — bounds.minX
          // becomes the visual leading edge and SwiftUI mirrors placement
          // automatically. No direct RTL handling needed here.
          var rowItems: [(index: Int, size: CGSize)] = []
          var rowY: CGFloat = bounds.minY
          var currentX: CGFloat = 0

          func placeRow() {
              let rowHeight = rowItems.map(\.size.height).max() ?? 0
              var x: CGFloat = bounds.minX
              for entry in rowItems {
                  subviews[entry.index].place(
                      at: CGPoint(x: x, y: rowY + (rowHeight - entry.size.height) / 2),
                      proposal: ProposedViewSize(entry.size)
                  )
                  x += entry.size.width + spacing
              }
              rowY += rowHeight + spacing
              rowItems.removeAll()
              currentX = 0
          }

          for (index, subview) in subviews.enumerated() {
              let size = subview.sizeThatFits(.unspecified)
              if currentX + size.width > bounds.width && !rowItems.isEmpty {
                  placeRow()
              }
              rowItems.append((index, size))
              currentX += size.width + spacing
          }
          if !rowItems.isEmpty { placeRow() }
      }
  }
  ```

  Note on RTL: SwiftUI's `Layout` protocol does not directly receive `layoutDirection`. The standard idiom is for the *caller* to apply `.environment(\.layoutDirection, .rightToLeft)` and trust that `place(at:proposal:)` honors the `bounds.minX` origin. The implementation above places via `bounds.minX` as the leading edge — which SwiftUI mirrors correctly when the parent's layout direction is RTL.

- [ ] **Step 2: Verify build.**

  Run the build command. Expected: `** BUILD SUCCEEDED **`.

### Task 3.4: Commit Chunk 3

- [ ] **Step 1: Commit.**

  ```bash
  git add SonicMerge/Features/SmartCut/Views/Studio/SmartCutFormatting.swift \
          SonicMerge/Features/SmartCut/Views/Studio/StudioGlassChrome.swift \
          SonicMerge/Features/SmartCut/Views/Studio/StudioFlowLayout.swift
  git commit -m "$(cat <<'EOF'
  feat(12-w3): Studio chrome primitives — formatting, glass card/capsule, flow layout

  Three new presentation-only files under SmartCut/Views/Studio/, each
  with a single responsibility:

  - SmartCutFormatting: enum with two static helpers (formatTimestamp,
    formatThreshold) lifted verbatim from FillerListPanel's private
    helpers so they survive the FillerListPanel deletion in Chunk 8.
  - StudioGlassChrome: two ViewModifiers — studioGlassCard (24pt
    rounded glass with Deep Indigo border + soft glow shadow) and
    studioFrostedCapsule (14pt frosted capsule with thin Indigo
    border). Both fall back to opaque surface on
    accessibilityReduceTransparency.
  - StudioFlowLayout: SwiftUI Layout protocol implementation that
    wraps capsules into rows. Uses bounds.minX as leading edge so the
    SwiftUI parent's layoutDirection environment flips the visual
    order correctly under RTL.

  No call-site integration yet — these primitives are consumed by
  Chunks 4-7. New files included via fileSystemSynchronizedGroups
  (no project.pbxproj edit needed; Phase 10/11 pattern verified).

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Chunk 4: Glassmorphic Summary Card + pulsating saves badge

Spec refs: §1 (point 2), §2 goals (Summary Card + saves badge bullets), §4.4 "Pulse animation primitive".

Two new files. The pulse badge is its own component (TimelineView-driven; reusable elsewhere if ever needed). The summary card composes it alongside the eyebrow / stats / Reset link.

**Files:**
- Create: `SonicMerge/Features/SmartCut/Views/Studio/StudioPulseSavesBadge.swift`
- Create: `SonicMerge/Features/SmartCut/Views/Studio/StudioSummaryCard.swift`

### Task 4.1: Create `StudioPulseSavesBadge.swift`

- [ ] **Step 1: Write the file.**

  ```swift
  // StudioPulseSavesBadge.swift
  // SonicMerge
  //
  // Phase 12 (Smart Cut Studio Refactor): the pulsating "saves ~31s"
  // badge that anchors the Summary Card. TimelineView drives a single
  // animation pump producing both the scale (1.0 ↔ 1.04) and the lime
  // green outer glow alpha (0.40 ↔ 0.65) over a ~1.6s sine cycle.
  // Halts when reduceMotion is on OR when seconds == 0 (no savings to
  // celebrate — static, dimmer presentation).

  import SwiftUI
  import UIKit

  struct StudioPulseSavesBadge: View {
      let seconds: TimeInterval

      @Environment(\.sonicMergeSemantic) private var semantic
      @Environment(\.accessibilityReduceMotion) private var reduceMotion

      private var shouldPause: Bool { reduceMotion || seconds == 0 }

      var body: some View {
          TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: shouldPause)) { timeline in
              let t = timeline.date.timeIntervalSinceReferenceDate
              let phase = (sin(t * (2 * .pi / 1.6)) + 1) / 2  // 0...1 over ~1.6s
              let scale = shouldPause ? 1.0 : 1.0 + 0.04 * phase
              let glowAlpha = shouldPause ? 0.40 : 0.40 + 0.25 * phase

              Text(label)
                  .font(.headline.weight(.bold).monospacedDigit())
                  .foregroundStyle(Color.black)
                  .padding(.vertical, 6)
                  .padding(.horizontal, 12)
                  .background(
                      Capsule().fill(Color(uiColor: semantic.accentAI))
                  )
                  .scaleEffect(scale)
                  .shadow(
                      color: Color(uiColor: semantic.accentAI).opacity(glowAlpha),
                      radius: 12, x: 0, y: 0
                  )
                  .contentTransition(reduceMotion ? .identity : .numericText())
                  .accessibilityLabel("saves \(Int(seconds)) seconds")
                  .accessibilityAddTraits(.updatesFrequently)
          }
      }

      private var label: String {
          // "saves ~31s" / "saves ~1m 5s"
          let total = Int(seconds.rounded())
          if total < 60 { return "saves ~\(total)s" }
          let m = total / 60
          let s = total % 60
          return s == 0 ? "saves ~\(m)m" : "saves ~\(m)m \(s)s"
      }
  }

  #Preview("StudioPulseSavesBadge") {
      VStack(spacing: 24) {
          StudioPulseSavesBadge(seconds: 31)
          StudioPulseSavesBadge(seconds: 0)
          StudioPulseSavesBadge(seconds: 65)
      }
      .padding()
  }
  ```

- [ ] **Step 2: Verify build.**

  Run the build command. Expected: `** BUILD SUCCEEDED **`.

### Task 4.2: Create `StudioSummaryCard.swift`

- [ ] **Step 1: Write the file.**

  ```swift
  // StudioSummaryCard.swift
  // SonicMerge
  //
  // Phase 12 (Smart Cut Studio Refactor): glassmorphic top-of-screen card
  // anchoring the Smart Cut tab. Eyebrow ("✨ SMART CUT SUMMARY"), stats
  // line ("7 fillers + 2 long pauses"), pulsating saves badge, and a
  // Reset link in the trailing edge of the eyebrow row.

  import SwiftUI

  struct StudioSummaryCard: View {
      let fillerCount: Int
      let pauseCount: Int
      let savings: TimeInterval
      let onReset: () -> Void

      @Environment(\.sonicMergeSemantic) private var semantic

      var body: some View {
          VStack(alignment: .leading, spacing: 12) {
              HStack {
                  Text("✨ SMART CUT SUMMARY")
                      .font(.caption2.weight(.semibold))
                      .textCase(.uppercase)
                      .foregroundStyle(Color(uiColor: semantic.accentAction))
                  Spacer()
                  Button(action: onReset) {
                      Text("Reset")
                          .font(.subheadline)
                          .foregroundStyle(Color(uiColor: semantic.accentAction).opacity(0.5))
                  }
                  .accessibilityHint("Clear current Smart Cut analysis")
              }
              Text(statsLine)
                  .font(.subheadline)
                  .foregroundStyle(Color(uiColor: semantic.textSecondary))
              StudioPulseSavesBadge(seconds: savings)
          }
          .padding(16)
          .frame(maxWidth: .infinity, alignment: .leading)
          .studioGlassCard(cornerRadius: 24)
          .accessibilityElement(children: .combine)
      }

      private var statsLine: String {
          let f = "\(fillerCount) filler\(fillerCount == 1 ? "" : "s")"
          let p = "\(pauseCount) long pause\(pauseCount == 1 ? "" : "s")"
          return "\(f) + \(p)"
      }
  }

  #Preview("StudioSummaryCard") {
      StudioSummaryCard(fillerCount: 7, pauseCount: 2, savings: 31, onReset: {})
          .padding()
  }
  ```

- [ ] **Step 2: Verify build.**

  Run the build command. Expected: `** BUILD SUCCEEDED **`.

### Task 4.3: Commit Chunk 4

- [ ] **Step 1: Commit.**

  ```bash
  git add SonicMerge/Features/SmartCut/Views/Studio/StudioPulseSavesBadge.swift \
          SonicMerge/Features/SmartCut/Views/Studio/StudioSummaryCard.swift
  git commit -m "$(cat <<'EOF'
  feat(12-w4): Glassmorphic Summary Card + pulsating saves badge

  Two new top-level Studio views:

  - StudioPulseSavesBadge: TimelineView-driven scale-and-glow pulse on
    the lime green saves capsule. Single animation pump produces both
    the scale modulation (1.0 ↔ 1.04) and the outer-glow shadow alpha
    (0.40 ↔ 0.65) on a ~1.6s sine cycle. Halts when reduceMotion OR
    seconds == 0. .contentTransition(.numericText()) carries through
    so live updates roll smoothly when chunk 5's pause slider drags.

  - StudioSummaryCard: glass-card chassis (via studioGlassCard) holding
    the eyebrow label "✨ SMART CUT SUMMARY", a Reset link in Deep
    Indigo @ 50% opacity (color-audit goal item baked in here at
    creation rather than retrofitted later), the secondary stats line
    "N fillers + M long pauses", and the pulsating saves badge.

  No call-site integration — wired up by Chunk 8's
  SmartCutStudioContainer.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Chunk 5: Bento card chassis + filler row + pause control row

Spec refs: §1 (point 3), §2 goals (single-column bento, group toggle, toggle-off, pauses bento), §4.5 "Bento card structure", §4.7 "Pause slider".

Three new files. `StudioBentoCard` is the generic chassis (single-column wide card with leading + trailing slots and an optional `onTap` + `isDisabled` flag). `FillerCategoryRow` and `PauseControlRow` render the two specific contents. The hit-testing is established in `StudioBentoCard` once via the explicit-Button pattern; both rows reuse it.

**Files:**
- Create: `SonicMerge/Features/SmartCut/Views/Studio/StudioBentoCard.swift`
- Create: `SonicMerge/Features/SmartCut/Views/Studio/FillerCategoryRow.swift`
- Create: `SonicMerge/Features/SmartCut/Views/Studio/PauseControlRow.swift`

### Task 5.1: Create `StudioBentoCard.swift`

- [ ] **Step 1: Write the file.**

  ```swift
  // StudioBentoCard.swift
  // SonicMerge
  //
  // Phase 12 (Smart Cut Studio Refactor): generic single-column wide bento
  // card chassis used by both filler-category cards and the long-pauses
  // card. 28pt continuous squircle, opaque white surfaceCard fill (NOT
  // glass — sits on the page background, not on another glass surface),
  // soft Deep Indigo shadow, leading + trailing content slots.
  //
  // The `isDisabled` flag drives the toggle-off treatment: opacity 0.40,
  // text bold + strikethrough + Deep Indigo (applied at the content site
  // via a wrapping modifier — see FillerCategoryRow for the call shape).
  // The card itself dampens its shadow when disabled.

  import SwiftUI

  struct StudioBentoCard<Leading: View, Trailing: View>: View {
      let leading: Leading
      let trailing: Trailing
      var isDisabled: Bool = false
      var onTap: (() -> Void)? = nil

      @Environment(\.sonicMergeSemantic) private var semantic
      @Environment(\.accessibilityReduceMotion) private var reduceMotion

      init(
          isDisabled: Bool = false,
          onTap: (() -> Void)? = nil,
          @ViewBuilder leading: () -> Leading,
          @ViewBuilder trailing: () -> Trailing
      ) {
          self.isDisabled = isDisabled
          self.onTap = onTap
          self.leading = leading()
          self.trailing = trailing()
      }

      var body: some View {
          // The card body. If onTap is provided, wrap the content area in a
          // Button so the card-body region is one tappable target. Trailing
          // content (typically containing its own Buttons) stays as a sibling
          // outside that Button so SwiftUI's hit-test prefers it.
          HStack(spacing: 12) {
              if let onTap {
                  Button(action: onTap) {
                      HStack { leading; Spacer(minLength: 0) }
                          .contentShape(Rectangle())
                  }
                  .buttonStyle(.plain)
              } else {
                  leading
                  Spacer(minLength: 0)
              }
              trailing
          }
          .padding(.vertical, 16)
          .padding(.horizontal, 18)
          .background(
              RoundedRectangle(cornerRadius: 28, style: .continuous)
                  .fill(Color(uiColor: semantic.surfaceCard))
          )
          .shadow(
              color: Color(uiColor: semantic.accentGlow).opacity(isDisabled ? 0.04 : 0.10),
              radius: isDisabled ? 6 : 16,
              x: 0,
              y: isDisabled ? 2 : 6
          )
          .opacity(isDisabled ? 0.40 : 1.0)
          .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.75), value: isDisabled)
      }
  }
  ```

- [ ] **Step 2: Verify build.**

  Run the build command. Expected: `** BUILD SUCCEEDED **`.

### Task 5.2: Create `FillerCategoryRow.swift`

- [ ] **Step 1: Write the file.**

  ```swift
  // FillerCategoryRow.swift
  // SonicMerge
  //
  // Phase 12 (Smart Cut Studio Refactor): content of one filler-category
  // bento card. Leading column shows the count eyebrow + word label;
  // trailing column shows the saves chip + group toggle. Tapping the body
  // (anywhere outside the toggle) opens the detail sheet via the parent's
  // onOpenSheet callback.

  import SwiftUI

  struct FillerCategoryRow: View {
      let category: String
      let occurrenceCount: Int
      let savings: TimeInterval
      let isEnabled: Bool      // true = some occurrences will be cut (group .on or .mixed)
      let onToggleGroup: () -> Void
      let onOpenSheet: () -> Void

      @Environment(\.sonicMergeSemantic) private var semantic

      var body: some View {
          StudioBentoCard(
              isDisabled: !isEnabled,
              onTap: onOpenSheet,
              leading: {
                  VStack(alignment: .leading, spacing: 4) {
                      Text("\(occurrenceCount) OCCURRENCE\(occurrenceCount == 1 ? "" : "S")")
                          .font(.caption2.weight(.semibold))
                          .foregroundStyle(Color(uiColor: semantic.textSecondary))
                      Text(category)
                          .font(.title3.weight(isEnabled ? .semibold : .bold))
                          .foregroundStyle(isEnabled
                              ? Color(uiColor: semantic.textPrimary)
                              : Color(uiColor: semantic.accentAction))
                          .strikethrough(!isEnabled)
                  }
              },
              trailing: {
                  HStack(spacing: 12) {
                      SavesChip(seconds: savings)
                      Button(action: onToggleGroup) {
                          Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                              .font(.title3)
                              .foregroundStyle(isEnabled
                                  ? Color(uiColor: semantic.accentAI)
                                  : Color(uiColor: semantic.accentAction).opacity(0.5))
                              .frame(minWidth: 44, minHeight: 44)
                      }
                      .buttonStyle(.plain)
                      .accessibilityLabel(isEnabled ? "Disable \(category)" : "Enable \(category)")
                  }
              }
          )
      }
  }

  /// Small lime/dim chip used by the bento cards' trailing edge.
  struct SavesChip: View {
      let seconds: TimeInterval
      @Environment(\.sonicMergeSemantic) private var semantic

      var body: some View {
          Text(seconds > 0 ? "saves \(SmartCutFormatting.formatTimestamp(seconds))" : "saves —")
              .font(.subheadline.weight(.semibold).monospacedDigit())
              .foregroundStyle(seconds > 0
                  ? Color(uiColor: semantic.accentAI)
                  : Color(uiColor: semantic.textSecondary))
      }
  }
  ```

- [ ] **Step 2: Verify build.**

  Run the build command. Expected: `** BUILD SUCCEEDED **`.

### Task 5.3: Create `PauseControlRow.swift`

- [ ] **Step 1: Write the file.**

  ```swift
  // PauseControlRow.swift
  // SonicMerge
  //
  // Phase 12 (Smart Cut Studio Refactor): content of the long-pauses bento
  // card. ⏱ icon + slider (1.0...3.0s, step 0.25s) + rolling-digit threshold
  // readout + saves chip. Slider is bound to a local @State so the rolling
  // text animates smoothly during drag; on each step change the new value
  // is pushed to the VM via setPauseThreshold (which re-runs PauseDetector
  // and updates editList.pauses synchronously). Light haptic per step.

  import SwiftUI
  import UIKit

  struct PauseControlRow: View {
      @Bindable var viewModel: SmartCutViewModel
      @Environment(\.sonicMergeSemantic) private var semantic
      @Environment(\.accessibilityReduceMotion) private var reduceMotion

      /// Drives the slider locally so the rolling-digit readout animates
      /// smoothly during drag. Synced via .onAppear and .onChange.
      @State private var draftThreshold: TimeInterval = 1.5

      private var pauseSavings: TimeInterval {
          viewModel.editList.pauses.filter(\.isEnabled).reduce(0) { $0 + $1.duration }
      }

      var body: some View {
          StudioBentoCard(
              leading: {
                  HStack(spacing: 12) {
                      Image(systemName: "clock.badge.exclamationmark")
                          .foregroundStyle(Color(uiColor: semantic.textSecondary))
                          .font(.title3)
                      VStack(alignment: .leading, spacing: 6) {
                          HStack {
                              Text("LONG PAUSES")
                                  .font(.caption2.weight(.semibold))
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
                  }
              },
              trailing: {
                  SavesChip(seconds: pauseSavings)
                      .contentTransition(reduceMotion ? .identity : .numericText())
              }
          )
          .onAppear { draftThreshold = viewModel.pauseThreshold }
      }
  }
  ```

- [ ] **Step 2: Verify build.**

  Run the build command. Expected: `** BUILD SUCCEEDED **`.

### Task 5.4: Commit Chunk 5

- [ ] **Step 1: Commit.**

  ```bash
  git add SonicMerge/Features/SmartCut/Views/Studio/StudioBentoCard.swift \
          SonicMerge/Features/SmartCut/Views/Studio/FillerCategoryRow.swift \
          SonicMerge/Features/SmartCut/Views/Studio/PauseControlRow.swift
  git commit -m "$(cat <<'EOF'
  feat(12-w5): Bento card chassis + filler row + pause control row

  Three new Studio views composing the bento-card grid:

  - StudioBentoCard: generic single-column wide chassis. 28pt
    continuous squircle, opaque surfaceCard fill (NOT glass — sits on
    PremiumBackground, not on another glass surface). Leading +
    trailing content slots, optional onTap callback wrapped in an
    explicit Button so SwiftUI's hit-test honors trailing inner-Button
    children (e.g., the group toggle). isDisabled flag drives the
    toggle-off treatment: 0.40 opacity, dampened shadow, spring-eased.

  - FillerCategoryRow: filler bento card content. Leading column =
    count eyebrow + word label (text gains bold + strikethrough +
    Deep Indigo when group is off). Trailing = saves chip + group
    toggle (44pt min hit area). Tap body = open detail sheet (via
    onOpenSheet callback wired in Chunk 8).

  - PauseControlRow: pauses bento card content. ⏱ icon + slider
    (1.0...3.0s, step 0.25s) + rolling-digit threshold readout +
    saves chip. Slider bound to a local @State for smooth rolling-
    digit animation; each step writes to viewModel.setPauseThreshold
    (Chunk 1) and fires a light haptic. .contentTransition uses
    .numericText() unless reduceMotion is on.

  Plus a small SavesChip view shared by both rows. No call-site
  integration — wired in Chunk 8 by SmartCutStudioContainer.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Chunk 6: Detail sheet — `FillerOccurrenceSheet`

Spec refs: §1 (point 4), §3 user journey step 2, §4.6 "Detail sheet".

One new file containing the sheet view + a row capsule sub-component + the migrated `playWindow` helper. Tap from a filler bento card opens this sheet at `.medium` detent; user can drag to `.large`. Each row is a frosted capsule with ▶ preview, excerpt, timestamp, per-occurrence checkbox.

**Files:**
- Create: `SonicMerge/Features/SmartCut/Views/Studio/FillerOccurrenceSheet.swift`

### Task 6.1: Create `FillerOccurrenceSheet.swift`

- [ ] **Step 1: Write the file.**

  ```swift
  // FillerOccurrenceSheet.swift
  // SonicMerge
  //
  // Phase 12 (Smart Cut Studio Refactor): the detail sheet that opens when
  // the user taps a filler-category bento card. Glassmorphic background,
  // header with word + total saves + "Disable all"/"Enable all" link,
  // wrap-flow of capsule pill rows (▶ preview · excerpt · timestamp ·
  // checkbox), per-row preview state for the 4-second window playback.
  //
  // The playWindow helper is migrated from FillerListPanel:146-167 with
  // ONE deliberate extension: a previewingId reset inside the
  // stop-and-clear pre-amble and inside the dispatch-after closure (drives
  // the new ▶/■ icon swap). The previewPlayer === player self-comparison
  // and the 33162e6 stop-in-flight-player guard are preserved intact —
  // do not "improve" them during the move (the self-compare works because
  // of @State value semantics; refactoring risks behavioral drift).

  import SwiftUI
  import AVFoundation
  import UIKit

  struct FillerOccurrenceSheet: View {
      let category: String
      let edits: [FillerEdit]              // occurrences for this category
      let inputURL: URL?
      let onToggleEdit: (_ id: String, _ enabled: Bool) -> Void
      let onToggleCategory: (_ enabled: Bool) -> Void

      @Environment(\.dismiss) private var dismiss
      @Environment(\.sonicMergeSemantic) private var semantic
      @State private var previewPlayer: AVAudioPlayer?
      @State private var previewingId: String?

      private var totalSavings: TimeInterval {
          edits.filter(\.isEnabled).reduce(0) { $0 + ($1.timeRange.upperBound - $1.timeRange.lowerBound) }
      }

      private var allEnabled: Bool { edits.allSatisfy(\.isEnabled) }

      var body: some View {
          NavigationStack {
              ScrollView {
                  VStack(alignment: .leading, spacing: 16) {
                      // Header
                      HStack(alignment: .firstTextBaseline) {
                          VStack(alignment: .leading, spacing: 4) {
                              Text(category)
                                  .font(.title2.weight(.bold))
                              Text("\(edits.count) occurrence\(edits.count == 1 ? "" : "s") · saves \(SmartCutFormatting.formatTimestamp(totalSavings))")
                                  .font(.subheadline)
                                  .foregroundStyle(Color(uiColor: semantic.textSecondary))
                          }
                          Spacer()
                          Button(allEnabled ? "Disable all" : "Enable all") {
                              onToggleCategory(!allEnabled)
                          }
                          .font(.subheadline)
                          .foregroundStyle(Color(uiColor: semantic.accentAction).opacity(0.5))
                      }
                      .padding(.horizontal, 16)

                      // Capsule rows
                      VStack(spacing: 8) {
                          ForEach(edits) { edit in
                              occurrenceRow(edit: edit)
                          }
                      }
                      .padding(.horizontal, 16)
                  }
                  .padding(.vertical, 16)
              }
              .navigationTitle("Occurrences")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .topBarTrailing) {
                      Button("Done") { dismiss() }
                  }
              }
              .presentationDetents([.medium, .large])
              .presentationBackground(.ultraThinMaterial)
          }
          .onDisappear {
              previewPlayer?.stop()
              previewPlayer = nil
              previewingId = nil
          }
      }

      private func occurrenceRow(edit: FillerEdit) -> some View {
          HStack(spacing: 12) {
              Button {
                  playWindow(around: edit.timeRange, id: edit.id)
              } label: {
                  Image(systemName: previewingId == edit.id ? "stop.fill" : "play.fill")
                      .font(.subheadline)
                      .foregroundStyle(Color(uiColor: semantic.accentAction))
                      .frame(width: 32, height: 32)
              }
              .buttonStyle(.plain)
              Text(edit.contextExcerpt)
                  .lineLimit(1)
                  .font(.subheadline)
                  .foregroundStyle(edit.isEnabled
                      ? Color(uiColor: semantic.textPrimary)
                      : Color(uiColor: semantic.textSecondary))
              Spacer()
              Text(SmartCutFormatting.formatTimestamp(edit.timeRange.lowerBound))
                  .font(.caption.monospacedDigit())
                  .foregroundStyle(Color(uiColor: semantic.textSecondary))
              Button {
                  onToggleEdit(edit.id, !edit.isEnabled)
              } label: {
                  Image(systemName: edit.isEnabled ? "checkmark.square.fill" : "square")
                      .foregroundStyle(edit.isEnabled
                          ? Color(uiColor: semantic.accentAI)
                          : Color(uiColor: semantic.textSecondary))
                      .frame(width: 32, height: 32)
              }
              .buttonStyle(.plain)
          }
          .padding(.vertical, 8)
          .padding(.horizontal, 12)
          .studioFrostedCapsule(cornerRadius: 14)
      }

      // MARK: - Preview playback (verbatim from FillerListPanel.swift:146-167)

      private func playWindow(around range: ClosedRange<TimeInterval>, id: String) {
          guard let inputURL else { return }
          // Stop any in-flight preview before starting a new one. AVAudioPlayer
          // keeps playing even after its @State reference is overwritten, so
          // without this a rapid re-tap (or different occurrence tap) produces
          // overlapping playback. (Migrated from 33162e6.)
          previewPlayer?.stop()
          previewPlayer = nil
          previewingId = nil
          let centerSeconds = range.lowerBound
          let windowStart = max(0, centerSeconds - 2)
          do {
              let player = try AVAudioPlayer(contentsOf: inputURL)
              player.currentTime = windowStart
              player.play()
              previewPlayer = player
              previewingId = id
              DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                  if previewPlayer === player {
                      player.stop()
                      previewingId = nil
                  }
              }
          } catch {
              // Surface via a non-crash channel; UI shows nothing — silent on failure.
          }
      }
  }
  ```

- [ ] **Step 2: Verify build.**

  Run the build command. Expected: `** BUILD SUCCEEDED **`.

### Task 6.2: Commit Chunk 6

- [ ] **Step 1: Commit.**

  ```bash
  git add SonicMerge/Features/SmartCut/Views/Studio/FillerOccurrenceSheet.swift
  git commit -m "$(cat <<'EOF'
  feat(12-w6): FillerOccurrenceSheet — detail sheet for per-category occurrences

  New Studio view presented as a .sheet when a filler bento card is
  tapped. .presentationDetents([.medium, .large]) with .ultraThinMaterial
  background gives a glassmorphic frame. Header carries the category
  name + total occurrences/saves + a "Disable all"/"Enable all" trailing
  link in Deep Indigo @ 50%. Body is a column of capsule pill rows
  (▶ preview · excerpt · timestamp · checkbox) styled via the
  studioFrostedCapsule modifier from Chunk 3.

  The 4-second preview helper (playWindow + previewPlayer state)
  migrates VERBATIM from FillerListPanel's private playWindow (including
  the 33162e6 stop-in-flight guard); the only addition is a
  previewingId @State that drives the ▶/■ icon swap and clears in the
  dispatch-after closure. The previewPlayer === player self-comparison
  is preserved unchanged — it works because of @State value semantics
  and refactoring during the move risks behavioral drift.

  No call-site integration — wired in Chunk 8 by
  SmartCutStudioContainer's per-card onOpenSheet callback.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Chunk 7: Edit Filler List unified pool + `restoreAllDefaults()`

Spec refs: §1 (point 6), §2 goals (Edit Filler List bullets), §3 user journey "Edit Filler List sheet", §4.2 "FillerLibrary `restoreAllDefaults()`", §4.8.

Two changes: (1) one-line addition of `restoreAllDefaults()` to `FillerLibrary`, (2) new `EditFillerListStudioSheet` with unified-pool tag UI + add input + restore link. The library helper ships in this chunk because the UI consumes it; both must commit together for the new sheet to function.

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Models/FillerLibrary.swift`
- Create: `SonicMerge/Features/SmartCut/Views/Studio/EditFillerListStudioSheet.swift`

### Task 7.1: Add `restoreAllDefaults()` to `FillerLibrary`

- [ ] **Step 1: Read `FillerLibrary.swift` to find the right insertion point.**

  Use Read (already done in spec phase). Confirm the `mutating func remove(_ word: String)` ends around line 63. Add the new method immediately after.

- [ ] **Step 2: Add the method.**

  Use Edit. Old string (the closing `}` of `remove(_:)` followed by the closing `}` of the struct):
  ```swift
      mutating func remove(_ word: String) {
          let normalized = word.lowercased().trimmingCharacters(in: .whitespaces)
          if customWords.contains(normalized) {
              defaults.set(customWords.filter { $0 != normalized }, forKey: customKey)
              return
          }
          if (defaultOnWords + defaultOffWords).contains(normalized) {
              var removed = removedDefaults
              removed.insert(normalized)
              defaults.set(Array(removed), forKey: removedKey)
          }
      }
  }
  ```
  New string:
  ```swift
      mutating func remove(_ word: String) {
          let normalized = word.lowercased().trimmingCharacters(in: .whitespaces)
          if customWords.contains(normalized) {
              defaults.set(customWords.filter { $0 != normalized }, forKey: customKey)
              return
          }
          if (defaultOnWords + defaultOffWords).contains(normalized) {
              var removed = removedDefaults
              removed.insert(normalized)
              defaults.set(Array(removed), forKey: removedKey)
          }
      }

      /// Phase 12: clear the persisted set of removed default words so all
      /// shipped defaults reappear in `allWords`. Custom words are not
      /// affected. Called from EditFillerListStudioSheet's "Restore default
      /// words" link when the user wants to undo prior default-removals.
      mutating func restoreAllDefaults() {
          defaults.removeObject(forKey: removedKey)
      }
  }
  ```

- [ ] **Step 3: Verify build.**

  Run the build command. Expected: `** BUILD SUCCEEDED **`.

### Task 7.2: Create `EditFillerListStudioSheet.swift`

- [ ] **Step 1: Write the file.**

  ```swift
  // EditFillerListStudioSheet.swift
  // SonicMerge
  //
  // Phase 12 (Smart Cut Studio Refactor): replaces the flat-List
  // EditFillerListSheet. Single section "ALL FILLER WORDS"; wrap-flow of
  // frosted-glass capsules (one per word in library.allWords); every
  // capsule has a trailing Deep Indigo ✕ that calls library.remove(_:).
  // For default words, remove adds to removedDefaults (persisted; can be
  // undone via the "Restore default words" link). For custom words,
  // remove permanently deletes. Capsule add input at the bottom.

  import SwiftUI

  struct EditFillerListStudioSheet: View {
      @Binding var library: FillerLibrary
      @Environment(\.dismiss) private var dismiss
      @Environment(\.sonicMergeSemantic) private var semantic
      @State private var newWord: String = ""

      private var removedCount: Int { library.removedDefaults.count }

      var body: some View {
          NavigationStack {
              ScrollView {
                  VStack(alignment: .leading, spacing: 16) {
                      Text("ALL FILLER WORDS")
                          .font(.caption2.weight(.semibold))
                          .foregroundStyle(Color(uiColor: semantic.textSecondary))
                          .padding(.horizontal, 16)
                      StudioFlowLayout(spacing: 8) {
                          ForEach(library.allWords, id: \.self) { word in
                              WordCapsule(word: word) {
                                  withAnimation(.spring(response: 0.30, dampingFraction: 0.8)) {
                                      library.remove(word)
                                  }
                              }
                              .transition(.scale.combined(with: .opacity))
                          }
                      }
                      .padding(.horizontal, 16)
                      if removedCount > 0 {
                          Button {
                              withAnimation(.spring(response: 0.30, dampingFraction: 0.8)) {
                                  library.restoreAllDefaults()
                              }
                          } label: {
                              Text("Restore default words (\(removedCount))")
                                  .font(.subheadline)
                                  .foregroundStyle(Color(uiColor: semantic.accentAction).opacity(0.5))
                          }
                          .padding(.horizontal, 16)
                      }
                      addInputCapsule
                          .padding(.horizontal, 16)
                          .padding(.top, 8)
                  }
                  .padding(.vertical, 16)
              }
              .navigationTitle("Edit filler list")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .topBarTrailing) {
                      Button("Done") { dismiss() }
                  }
              }
              .presentationBackground(.ultraThinMaterial)
          }
      }

      private var addInputCapsule: some View {
          HStack(spacing: 8) {
              Image(systemName: "plus")
                  .foregroundStyle(Color(uiColor: semantic.accentAction))
              TextField("Add a word…", text: $newWord)
                  .submitLabel(.done)
                  .onSubmit {
                      withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                          library.addCustom(newWord)
                      }
                      newWord = ""
                  }
          }
          .padding(.vertical, 8)
          .padding(.horizontal, 12)
          .studioFrostedCapsule(cornerRadius: 14)
      }
  }

  private struct WordCapsule: View {
      let word: String
      let onRemove: () -> Void

      @Environment(\.sonicMergeSemantic) private var semantic

      var body: some View {
          HStack(spacing: 6) {
              Text(word)
                  .font(.subheadline)
                  .foregroundStyle(Color(uiColor: semantic.textPrimary))
              Button(action: onRemove) {
                  Image(systemName: "xmark")
                      .font(.caption2.weight(.semibold))
                      .foregroundStyle(Color(uiColor: semantic.accentAction).opacity(0.6))
                      .frame(width: 24, height: 24)
              }
              .buttonStyle(.plain)
              .accessibilityLabel("Remove \(word)")
          }
          .padding(.vertical, 5)
          .padding(.leading, 12)
          .padding(.trailing, 4)
          .studioFrostedCapsule(cornerRadius: 14)
      }
  }
  ```

- [ ] **Step 2: Verify build.**

  Run the build command. Expected: `** BUILD SUCCEEDED **`.

### Task 7.3: Commit Chunk 7

- [ ] **Step 1: Commit.**

  ```bash
  git add SonicMerge/Features/SmartCut/Models/FillerLibrary.swift \
          SonicMerge/Features/SmartCut/Views/Studio/EditFillerListStudioSheet.swift
  git commit -m "$(cat <<'EOF'
  feat(12-w7): EditFillerListStudioSheet + FillerLibrary.restoreAllDefaults()

  Two changes that ship together because the UI consumes the new helper:

  - FillerLibrary gains a one-line restoreAllDefaults() that clears the
    UserDefaults removedDefaults set. All other library semantics
    (defaultOnWords, defaultOffWords, addCustom, remove) are unchanged.

  - EditFillerListStudioSheet replaces the flat-List EditFillerListSheet
    with a single-section unified pool: every word from library.allWords
    is rendered as a frosted capsule (via studioFrostedCapsule from
    Chunk 3), each with a trailing Deep Indigo ✕. Tapping ✕ calls
    library.remove(word) (existing semantics: defaults go to
    removedDefaults, custom permanently deletes). Capsule layout uses
    StudioFlowLayout (Chunk 3) so words wrap to new rows.

    A "Restore default words (N)" link surfaces below the pool when
    library.removedDefaults is non-empty; tapping calls the new
    restoreAllDefaults(). Add-input is a capsule-shaped TextField with
    leading "+" icon; submit on Enter calls library.addCustom and
    clears the field.

  Animations: spring on insertion (response 0.35) and removal (0.30);
  capsules .transition(.scale + .opacity) for animated re-flow.

  No call-site integration in CleaningLabView — that's wired by Chunk 8
  via SmartCutStudioContainer.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Chunk 8: Container integration + call-site swap + color audit + retire old files

Spec refs: §1 (final paragraph), §2 goals (color audit + replace old files), §4.1 file table (`SmartCutStudioContainer.swift`), §9 "Migration & deprecation".

Wire all the Studio components into one top-level container, swap the call-site in `CleaningLabView`, audit Reset / "+ Edit filler list" colors, and retire the three old view files. Single chunk because these have to land together (the moment `SmartCutCardView` is deleted, the new container has to be in its place — splitting risks an intermediate broken state).

**Files:**
- Create: `SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift`
- Modify: `SonicMerge/Features/Denoising/CleaningLabView.swift`
- Delete: `SonicMerge/Features/SmartCut/SmartCutCardView.swift`
- Delete: `SonicMerge/Features/SmartCut/Views/FillerListPanel.swift`
- Delete: `SonicMerge/Features/SmartCut/Views/EditFillerListSheet.swift`

### Task 8.1: Create `SmartCutStudioContainer.swift`

This is the single biggest new file. It owns the state-machine switch that mirrors `SmartCutCardView`'s today (idle/analyzing/results/applied/stale/error), but in `.results` and `.applied` and `.stale` it renders the studio layout (summary + picker + bento + edit-link + sheet presentation). Other states render simple centered-orb scaffolds.

- [ ] **Step 1: Write the file.**

  ```swift
  // SmartCutStudioContainer.swift
  // SonicMerge
  //
  // Phase 12 (Smart Cut Studio Refactor): top-level container view that
  // replaces SmartCutCardView at the CleaningLabView call-site. Owns the
  // state-machine switch and renders the new studio layout in .results /
  // .applied / .stale states. Idle, analyzing, and error states preserve
  // the prior SmartCutCardView affordances (estimated-minutes label,
  // "Run in BG" button, "Reads from: denoised audio" footer, error icon
  // + Try-again-via-invalidate, applied-state green checkmark, stale-state
  // re-analyze warning) — those are user-visible features in the shipped
  // product, not stylistic choices, so they port across rather than
  // simplify out.
  //
  // Init signature mirrors the existing SmartCutCardView (vm:, library:);
  // CleaningLabView's call-site is a one-line swap.

  import SwiftUI

  /// Adapter for the SegmentedPill A/B picker. SegmentedPill requires
  /// Hashable & CaseIterable; the VM stores isPlayingCleaned: Bool.
  enum PlaybackTrack: Hashable, CaseIterable {
      case original, cleaned
  }

  struct SmartCutStudioContainer: View {
      @Bindable var vm: SmartCutViewModel
      @Binding var library: FillerLibrary

      @Environment(\.sonicMergeSemantic) private var semantic
      @State private var openCategory: String?
      @State private var showEditFillerList: Bool = false

      var body: some View {
          switch vm.state {
          case .idle:
              idleScaffold
          case .analyzing(let progress):
              analyzingScaffold(progress: progress)
          case .results:
              studioLayout(headerBanner: nil)
          case .applied(let saved):
              studioLayout(headerBanner: AnyView(appliedBanner(saved: saved)))
          case .stale:
              staleScaffold
          case .error(let message):
              errorScaffold(message: message)
          }
      }

      // MARK: - Studio layout (.results / .applied)

      private func studioLayout(headerBanner: AnyView?) -> some View {
          VStack(spacing: 12) {
              StudioSummaryCard(
                  fillerCount: vm.editList.fillers.count,
                  pauseCount: vm.editList.pauses.count,
                  savings: vm.editList.enabledSavings,
                  onReset: { vm.invalidate() }
              )

              if let headerBanner { headerBanner }

              SegmentedPill(
                  selection: playbackTrackBinding,
                  label: { $0 == .original ? "Original" : "Cleaned" },
                  selectedTint: .accent,
                  unselectedTint: .accent
              )

              VStack(spacing: 12) {
                  ForEach(vm.editList.categories, id: \.self) { category in
                      let edits = vm.editList.fillers.filter { $0.matchedText == category }
                      let categorySavings = edits.filter(\.isEnabled).reduce(0) {
                          $0 + ($1.timeRange.upperBound - $1.timeRange.lowerBound)
                      }
                      let state = vm.editList.categoryState(for: category)
                      FillerCategoryRow(
                          category: category,
                          occurrenceCount: edits.count,
                          savings: categorySavings,
                          isEnabled: state != .off,
                          onToggleGroup: { vm.setCategory(category, enabled: state == .off) },
                          onOpenSheet: { openCategory = category }
                      )
                  }
                  if !vm.editList.pauses.isEmpty {
                      PauseControlRow(viewModel: vm)
                  }
              }

              Button {
                  showEditFillerList = true
              } label: {
                  HStack(spacing: 4) {
                      Image(systemName: "plus")
                      Text("Edit filler list")
                  }
                  .font(.subheadline)
                  .foregroundStyle(Color(uiColor: semantic.accentAction).opacity(0.5))
              }
              .padding(.top, 4)
          }
          .sheet(item: Binding<SheetCategory?>(
              get: { openCategory.map { SheetCategory(rawValue: $0) } },
              set: { openCategory = $0?.rawValue }
          )) { sheetCategory in
              let edits = vm.editList.fillers.filter { $0.matchedText == sheetCategory.rawValue }
              FillerOccurrenceSheet(
                  category: sheetCategory.rawValue,
                  edits: edits,
                  inputURL: vm.inputURL,
                  onToggleEdit: { id, enabled in vm.setEdit(id: id, enabled: enabled) },
                  onToggleCategory: { enabled in vm.setCategory(sheetCategory.rawValue, enabled: enabled) }
              )
          }
          .sheet(isPresented: $showEditFillerList) {
              EditFillerListStudioSheet(library: $library)
          }
      }

      private var playbackTrackBinding: Binding<PlaybackTrack> {
          Binding<PlaybackTrack>(
              get: { vm.isPlayingCleaned ? .cleaned : .original },
              set: { newValue in
                  let wantsCleaned = newValue == .cleaned
                  if wantsCleaned != vm.isPlayingCleaned {
                      vm.toggleCleaned()
                  }
              }
          )
      }

      private func appliedBanner(saved: TimeInterval) -> some View {
          // Preserves the prior .applied-state "Applied · Xs saved" affordance
          // (SmartCutCardView.swift:115-116) so users still get a visible
          // confirmation that the cuts landed.
          Label("Applied · \(formatDuration(saved)) saved", systemImage: "checkmark.circle.fill")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.green)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 4)
      }

      // MARK: - Non-results scaffolds (preserve all prior SmartCutCardView features)

      private var idleScaffold: some View {
          // Mirrors SmartCutCardView.idleContent (lines 61-81): orb + body
          // copy + Analyze button (estimated-minutes label) + footer.
          VStack(spacing: 12) {
              Text("Remove fillers and trim long silences")
                  .foregroundStyle(.secondary)
              smartCutOrb(active: false)
                  .tint(.green)
              Button {
                  vm.analyze()
              } label: {
                  let label = vm.estimatedAnalysisMinutes > 0
                      ? "Analyze ~\(vm.estimatedAnalysisMinutes) min"
                      : "Analyze"
                  Label(label, systemImage: "sparkles")
                      .frame(maxWidth: .infinity)
              }
              .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
              Text("Reads from: denoised audio")
                  .font(.caption)
                  .foregroundStyle(.secondary)
          }
          .padding()
      }

      private func analyzingScaffold(progress: Double) -> some View {
          // Mirrors SmartCutCardView.analyzingContent (lines 83-96): orb +
          // progress + Cancel + Run in BG buttons.
          VStack(spacing: 12) {
              smartCutOrb(active: true)
                  .tint(.green)
              Text("Transcribing \(Int(progress * 100))%")
              ProgressView(value: progress)
              HStack {
                  Button("Cancel") { vm.cancelAnalyze() }
                      .buttonStyle(PillButtonStyle(variant: .outline, size: .regular, tint: .accent))
                  Button("Run in BG") { vm.scheduleBackgroundTranscription() }
                      .buttonStyle(PillButtonStyle(variant: .outline, size: .regular, tint: .ai))
              }
          }
          .padding()
      }

      private var staleScaffold: some View {
          // Mirrors SmartCutCardView.staleContent (lines 122-132): orange
          // warning + Re-analyze button. Studio layout NOT shown here since
          // the editList is stale and shouldn't be acted on until re-analyze.
          VStack(alignment: .leading, spacing: 12) {
              Label("Denoise was re-applied", systemImage: "exclamationmark.triangle.fill")
                  .foregroundStyle(.orange)
              Text("Smart Cut analysis is stale.")
                  .foregroundStyle(.secondary)
              Button("Re-analyze") {
                  vm.requestReanalyze()
                  vm.analyze()
              }
              .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
          }
          .padding()
      }

      private func errorScaffold(message: String) -> some View {
          // Mirrors SmartCutCardView.errorContent (lines 134-140): octagon
          // icon + Try-again-via-invalidate (NOT analyze, per prior behavior).
          VStack(alignment: .leading, spacing: 8) {
              Label(message, systemImage: "exclamationmark.octagon.fill")
                  .foregroundStyle(.red)
              Button("Try again") { vm.invalidate() }
          }
          .padding()
      }

      private func smartCutOrb(active: Bool) -> some View {
          Image(systemName: "sparkles")
              .font(.system(size: 56, weight: .bold))
              .foregroundStyle(.tint)
              .symbolEffect(.pulse, options: active ? .repeating : .nonRepeating)
              .frame(width: 80, height: 80)
      }

      private func formatDuration(_ s: TimeInterval) -> String {
          let m = Int(s) / 60
          let sec = Int(s) % 60
          return m > 0 ? "\(m)m \(sec)s" : "\(sec)s"
      }
  }

  /// Wraps a category String in an Identifiable so .sheet(item:) accepts it.
  private struct SheetCategory: Identifiable, Hashable {
      let rawValue: String
      var id: String { rawValue }
  }
  ```

  **Notes:**
  - Init signature mirrors `SmartCutCardView`'s real shape (`vm: SmartCutViewModel, library: Binding<FillerLibrary>`) — verified against `SonicMerge/Features/SmartCut/SmartCutCardView.swift:5-6` and the call-site at `CleaningLabView.swift:211-212`. No `denoisedURL` parameter (the prior view didn't have one either).
  - The four non-results scaffolds (idle / analyzing / stale / error) port the prior `SmartCutCardView`'s feature set 1:1 — `vm.estimatedAnalysisMinutes` label, "Reads from: denoised audio" footer, "Run in BG" button, applied banner, stale-state Re-analyze (calls `requestReanalyze(); analyze()`), error icon (`exclamationmark.octagon.fill`), and Try-again-via-`invalidate()` (NOT `analyze()`). These are not stylistic choices — they are shipped product features that must survive the refactor.
  - `Binding<SheetCategory?>` explicit generic guides type inference for `.sheet(item:)`.

- [ ] **Step 2: Verify build.**

  Run the build command. Expected: `** BUILD SUCCEEDED **`. Build will likely succeed even though `SmartCutCardView` is still present — they're independent files.

### Task 8.2: Swap call-site in `CleaningLabView` + color audit

- [ ] **Step 1: Read `CleaningLabView.swift` lines 209–213 to confirm the call-site.**

  Use Read on `SonicMerge/Features/Denoising/CleaningLabView.swift`. Verified call-site (lines 211–212):
  ```swift
          SmartCutCardView(vm: viewModel.smartCutVM,
                           library: $viewModel.fillerLibrary)
  ```

- [ ] **Step 2: Replace the call-site with the new container.**

  Use Edit. Old string (preserve exact whitespace — the call spans two lines with specific indentation):
  ```swift
          SmartCutCardView(vm: viewModel.smartCutVM,
                           library: $viewModel.fillerLibrary)
  ```
  New string:
  ```swift
          SmartCutStudioContainer(vm: viewModel.smartCutVM,
                                  library: $viewModel.fillerLibrary)
  ```

  No parameter changes — both views share the exact same external dependency surface (`vm`, `library`).

- [ ] **Step 3: Audit Reset / + Edit filler list link colors.**

  These links may exist outside `SmartCutStudioContainer` if `CleaningLabView` ever rendered them directly. Grep:
  ```bash
  grep -nE 'Reset|Edit filler list' /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMerge/Features/Denoising/CleaningLabView.swift
  ```
  If any matches use `Color.blue` or default `Color.accentColor`, edit to `Color(uiColor: semantic.accentAction).opacity(0.5)`. If no matches, color audit is satisfied entirely by the new Studio components (which already use Deep Indigo @ 50%).

- [ ] **Step 4: Verify build (will fail until old files are deleted in Task 8.4 if anything still references `SmartCutCardView`).**

  Run the build command. Expected: `** BUILD SUCCEEDED **` since `SmartCutCardView` is unused after this swap (no other call-sites). If anything else references the old type, the build will fail and surface the unexpected dependency — fix before proceeding.

### Task 8.3: Verify the swap with the simulator (mid-chunk smoke test)

- [ ] **Step 1: Boot iPhone 17 Sim and launch the app to confirm the studio layout renders.**

  This is a manual check, not a programmatic step. Open Xcode, select iPhone 17 Sim, run the app, navigate to Cleaning Lab → Smart Cut tab. Confirm:
  - In `.idle` state: simple "Analyze" button visible.
  - After Analyze (or via `_injectResultsForTesting` if no input set): summary card pulses, A/B pill, bento cards, slider, "+ Edit filler list" link.
  - Tapping a filler card opens the detail sheet at medium detent.
  - Tapping the slider drags fire haptics on the device (sim has no taptic but onChange fires).
  - Tapping "+ Edit filler list" opens the unified-pool sheet with frosted capsules.

  If anything is broken visually, fix in subsequent edits before deleting old files. **Do not proceed to Task 8.4 until this manual smoke test passes** — that's the gate that justifies destructive deletions.

### Task 8.4: Delete the three retired view files

- [ ] **Step 1: Sanity-grep for any remaining references to the three retired types.**

  ```bash
  grep -rE 'SmartCutCardView|FillerListPanel|EditFillerListSheet' /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMerge /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMergeTests 2>&1 | grep -v 'Studio/' | head -10
  ```
  Expected: matches only inside the three files about to be deleted, plus comments inside Studio/ files referencing the migration. Anything else means there's a stale reference — fix the call-site before deleting.

- [ ] **Step 2: Delete the three files.**

  ```bash
  rm /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMerge/Features/SmartCut/SmartCutCardView.swift
  rm /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMerge/Features/SmartCut/Views/FillerListPanel.swift
  rm /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMerge/Features/SmartCut/Views/EditFillerListSheet.swift
  ```

- [ ] **Step 3: Verify build + run the full test suite.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/sm-p12-c8.log | tail -8
  echo "PASS=$(grep -E '✔ Test .* passed' /tmp/sm-p12-c8.log | sort -u | wc -l)"
  echo "FAIL=$(grep -E '✘ Test .* failed' /tmp/sm-p12-c8.log | sort -u | wc -l)"
  ```
  Expected: `** TEST FAILED **` with PASS=57 (53 baseline + 4 from Chunk 1) and FAIL=5 (same baseline failures). If FAIL > 5, a chunk-introduced regression has surfaced — bisect.

### Task 8.5: Commit Chunk 8

- [ ] **Step 1: Commit.**

  ```bash
  git add SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift \
          SonicMerge/Features/Denoising/CleaningLabView.swift
  git rm SonicMerge/Features/SmartCut/SmartCutCardView.swift \
         SonicMerge/Features/SmartCut/Views/FillerListPanel.swift \
         SonicMerge/Features/SmartCut/Views/EditFillerListSheet.swift
  git commit -m "$(cat <<'EOF'
  feat(12-w8): SmartCutStudioContainer integration; retire old view layer

  Wires every Studio component shipped in Chunks 3-7 into one top-level
  container view, swaps it in for SmartCutCardView at the
  CleaningLabView call-site, audits Reset / + Edit filler list link
  colors to Deep Indigo @ 50%, and retires the three old view files.

  - SmartCutStudioContainer owns the state-machine switch (idle /
    analyzing / results / applied / stale / error). In results /
    applied / stale it renders the studio layout: StudioSummaryCard,
    SegmentedPill A/B (selectedTint:.accent / unselectedTint:.accent
    via Chunk 2), single-column bento grid (FillerCategoryRow per
    category + PauseControlRow), and "+ Edit filler list" link. Two
    sheets owned via @State: openCategory drives FillerOccurrenceSheet
    via .sheet(item:); showEditFillerList drives
    EditFillerListStudioSheet via .sheet(isPresented:).
  - PlaybackTrack enum + computed Binding<PlaybackTrack> adapt the VM's
    isPlayingCleaned: Bool to the Hashable & CaseIterable enum
    SegmentedPill requires.
  - CleaningLabView call-site (line ~211) swapped in-place.
  - Three old files deleted: SmartCutCardView.swift, FillerListPanel.swift,
    EditFillerListSheet.swift.

  Test suite: 57 pass / 5 fail (baseline preserved).

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Final Verification

### Task F.1: Regression test pass

- [ ] **Step 1: Run the full test suite.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/sm-p12-final.log | tail -8
  echo "PASS=$(grep -E '✔ Test .* passed' /tmp/sm-p12-final.log | sort -u | wc -l)"
  echo "FAIL=$(grep -E '✘ Test .* failed' /tmp/sm-p12-final.log | sort -u | wc -l)"
  ```
  Expected: PASS=57, FAIL=5 (3× ShareExtension, 1× ABPlayback, 1× AudioMergerService crossfade — same baseline). Anything else means a Phase 12 chunk regressed something — `git bisect` against the chunk commits.

### Task F.2: Human device verification

Phase 12 visuals are not unit-testable in this repo. Acceptance gate: human eyes on iPhone 17 Sim (iOS 26.2). Verify each item from spec §12 acceptance criteria:

- [ ] **Summary card:** glassmorphic, eyebrow + stats + pulsing saves badge + Reset link in Deep Indigo @ 50%.
- [ ] **A/B picker:** Original selected = filled Deep Indigo, Cleaned = outline Deep Indigo.
- [ ] **Bento cards:** single-column wide, 28pt squircle, soft Deep Indigo shadow. Filler cards show count eyebrow + word + saves chip + group toggle. Pauses card shows ⏱ icon + slider + threshold readout + saves chip.
- [ ] **Tap card opens sheet:** tap anywhere on a filler card body (not the toggle) opens detail sheet at medium detent.
- [ ] **Detail sheet:** glass background; capsule rows with ▶ preview · excerpt · timestamp · checkbox.
- [ ] **Group toggle:** tapping the trailing toggle disables the group: card opacity 0.40, text bold + strikethrough + Deep Indigo, shadow softens.
- [ ] **Pause slider:** drag fires light haptic per 0.25s step; threshold readout rolls smoothly; saves chip recomputes live.
- [ ] **Pulse + accessibility:** Saves badge pulse halts under Settings → Accessibility → Reduce Motion. Glass surfaces fall back to opaque cards under Reduce Transparency.
- [ ] **Edit Filler List sheet:** unified wrap-flow pool of frosted capsules; ✕ on default toggles off (capsule disappears, "Restore default words" link appears); ✕ on custom permanent-deletes; add input at bottom.
- [ ] **Color audit:** "Reset" + "+ Edit filler list" links in Deep Indigo @ 50% (no system blue anywhere).

### Task F.3: Push branch + open PR

- [ ] **Step 1: Push.**

  ```bash
  git push -u origin phase-12-smartcut-studio-refactor
  ```

- [ ] **Step 2: Open PR.**

  `gh` CLI not available in this environment — open the URL the push prints in a browser, paste a summary derived from the chunk commit messages plus the Final Verification checklist.

---

## Rollback

Each chunk is one atomic commit. To revert any one:

```bash
git revert <sha>
```

Chunks 2–7 are independent visual additions that can revert without touching others. Chunks 1 and 8 are coupled to model state and call-site integration respectively — reverting Chunk 8 alone would leave the new view files orphaned (still in tree but unreferenced) and the build would still succeed (deleted files restored, swap reversed); reverting Chunk 1 alone would leave Chunks 5/8 referencing the missing `setPauseThreshold` (build break — must be reverted last if reverting both).

Most-likely revert candidates:
- **Chunk 4 pulse:** if the pulsing badge feels seasick during long denoise runs, revert just Chunk 4 (loses summary card too — extract pulse-specific into its own commit if needed).
- **Chunk 5 toggle-off treatment:** if the bold + strikethrough + Indigo combo reads as broken instead of intentional, revert and tweak.
- **Chunk 7 unified pool:** if removing the Default/Your section split confuses users, revert and re-introduce a section header.

---

## Summary Ledger

| Chunk | Files | Lines (approx) | Requirement |
|-------|-------|----------------|-------------|
| 1 | 4 modified | ~100 | Cached segments + setPauseThreshold + 4 tests |
| 2 | 1 modified | ~10 | SegmentedPill optional tint params |
| 3 | 3 created | ~180 | Formatting + glass chrome + flow layout |
| 4 | 2 created | ~120 | Summary card + pulsing saves badge |
| 5 | 3 created | ~220 | Bento chassis + filler row + pause control row |
| 6 | 1 created | ~150 | Detail sheet with playWindow migration |
| 7 | 1 modified + 1 created | ~150 | restoreAllDefaults() + tag pool sheet |
| 8 | 1 created + 1 modified + 3 deleted | ~250 | Container + swap + retire |

**Commits expected:** 8 chunk commits, branch `phase-12-smartcut-studio-refactor`. Final verification + push as separate steps (no commits).
