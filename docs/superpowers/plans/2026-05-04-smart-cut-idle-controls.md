# Smart Cut Idle Controls Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface the long-pause threshold slider and the filler-word list on the Smart Cut idle screen so the user can tune both *before* tapping Analyze, and wire `SmartCutService.analyze` to actually respect the chosen threshold.

**Architecture:** A new `IdleSettingsCards` view (with two private nested cards: `IdlePauseCard` and `IdleFillerCard`) embeds inside `SmartCutStudioContainer.idleScaffold`. The pause card writes directly to `viewModel.pauseThreshold`. The filler card displays read-only chips and reuses the existing `EditFillerListStudioSheet` for editing — the existing `WordCapsule` private struct is hoisted to file-internal and gains an optional `onRemove` parameter so both call sites share styling. `SmartCutService.analyze(input:)` is extended with an explicit `pauseThreshold:` argument; the init-time captured threshold is removed (it's been ignored by all real-world callers anyway).

**Tech Stack:** Swift 6, SwiftUI, Swift Testing for the new unit tests, existing `StudioBentoCard` chassis, existing `FillerLibrary` + `EditFillerListStudioSheet`.

**Spec:** `docs/superpowers/specs/2026-05-04-smart-cut-idle-controls-design.md`.

> **Line-number policy:** Cited line numbers reflect `main` at plan-write time and may drift by 1–3 lines as Chunks land. Always locate the target block by **searching the code snippet provided**, not by jumping to the cited line.

---

## Chunk 0: Branch + baseline

### Task 0.1: Verify clean tree and create branch

**Files:** none (git only)

- [ ] **Step 1: Confirm we're on `main` and the tree is clean.**

  Run: `git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge status`
  Expected: only `M  SonicMerge.xcodeproj/.../UserInterfaceState.xcuserstate` and untracked `.cursor/` / `.superpowers/`. Anything else — investigate before continuing.

- [ ] **Step 2: Create the feature branch.**

  Run: `git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge checkout -b feat/smart-cut-idle-controls main`
  Expected: `Switched to a new branch 'feat/smart-cut-idle-controls'`.

- [ ] **Step 3: Baseline test run.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/ic-baseline.log | tail -3
  echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/ic-baseline.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
  ```
  Expected: build SUCCEEDS. `FAIL=5` baseline names: `compositionWithCrossfadeHasNonNilAudioMix`, `testFileCopyToClipsDirectory`, `testLargeFileCopyDoesNotCrash`, `testPendingKeyWrittenAndCleared`, `testPositionPreservedOnSwitch`.

---

## Chunk 1: SmartCutService.analyze API change + unit tests

The actor captures `pauseThreshold` at init time and never reads it from VM state — both callers always get the default 1.5s regardless of what the user picked. Fix in three coordinated changes:

1. Add a `TranscriptionServicing` protocol so the analyze pipeline can be tested against a stub. **Required because `TranscriptionService` is declared `actor`, and Swift actors cannot be subclassed.** The protocol is a 2-line addition that makes the existing actor a conformer.
2. `SmartCutService` accepts `any TranscriptionServicing` instead of the concrete `TranscriptionService` type.
3. `SmartCutService.analyze(input:pauseThreshold:)` takes the threshold explicitly; the init-time `pauseThreshold` parameter and stored property are removed.

**Spec references:** §6 (API change), §11.1 (unit tests).

### Task 1.1: Add `TranscriptionServicing` protocol

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Services/TranscriptionService.swift`

- [ ] **Step 1: Add the protocol declaration.**

  Open `TranscriptionService.swift`. Find the `actor TranscriptionService {` line (around `:14`). Just before it, insert:

  ```swift
  /// Protocol seam over `TranscriptionService` so `SmartCutService` can be
  /// tested against a deterministic stub. The real `TranscriptionService` is
  /// an actor, which cannot be subclassed — a protocol is the only way to
  /// inject a stub.
  protocol TranscriptionServicing: Sendable {
      func transcribe(input: URL) -> AsyncThrowingStream<TranscriptionState, Error>
  }

  extension TranscriptionService: TranscriptionServicing {}
  ```

  The conformance is implicit — `TranscriptionService` already has a `transcribe(input:)` method with the matching signature, and `actor` types are implicitly `Sendable`.

- [ ] **Step 2: Build to confirm the protocol compiles.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`. If conformance fails because `transcribe(input:)` is actor-isolated and the protocol expects a non-isolated method, mark the protocol method as `nonisolated`-compatible by reading the actual file's actor isolation. Most likely the existing method signature is fine because it returns `AsyncThrowingStream` synchronously (the stream's iteration is async, not the call itself).

### Task 1.2: Update `SmartCutService` to use the protocol

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Services/SmartCutService.swift`

- [ ] **Step 1: Replace the concrete type reference and init signature.**

  Open `SmartCutService.swift`. Find lines 11-21:

  ```swift
  private let library: FillerLibrary
  private let pauseThreshold: TimeInterval
  private let transcriptionService: TranscriptionService

  init(library: FillerLibrary,
       pauseThreshold: TimeInterval = 1.5,
       transcriptionService: TranscriptionService = TranscriptionService()) {
      self.library = library
      self.pauseThreshold = pauseThreshold
      self.transcriptionService = transcriptionService
  }

  func analyze(input: URL) -> AsyncThrowingStream<Update, Error> {
  ```

  Replace with:

  ```swift
  private let library: FillerLibrary
  private let transcriptionService: any TranscriptionServicing

  init(library: FillerLibrary,
       transcriptionService: any TranscriptionServicing = TranscriptionService()) {
      self.library = library
      self.transcriptionService = transcriptionService
  }

  func analyze(input: URL, pauseThreshold: TimeInterval) -> AsyncThrowingStream<Update, Error> {
  ```

  Two changes: drop init-time `pauseThreshold` capture, switch to `any TranscriptionServicing` type. Inside `analyze`, the `threshold: pauseThreshold` reference at the `PauseDetector.detect(...)` call site (currently line 44) now resolves to the new parameter — same identifier, same value, different binding source. No body change needed.

### Task 1.3: Write the unit tests with the corrected stub

**Files:**
- Create: `SonicMergeTests/SmartCutServicePauseThresholdTests.swift`

- [ ] **Step 1: Create the test file.**

  ```swift
  import Testing
  import Foundation
  @testable import SonicMerge

  /// Verifies the explicit `pauseThreshold:` parameter on `SmartCutService.analyze`
  /// actually flows through to `PauseDetector` (rather than being ignored in favor
  /// of an init-time captured default).
  struct SmartCutServicePauseThresholdTests {

      /// Stub conforming to the `TranscriptionServicing` protocol. Yields one
      /// pre-built `TranscriptionState` whose recognized segments have a single
      /// 2.0-second gap (1.0s end → 3.0s start). Lets us assert which threshold
      /// is in effect inside `analyze` based on whether the gap becomes a pause.
      private struct StubTranscriptionService: TranscriptionServicing {
          let segments: [TranscriptionState.RecognizedSegment]
          let duration: TimeInterval

          func transcribe(input: URL) -> AsyncThrowingStream<TranscriptionState, Error> {
              let segments = self.segments
              let duration = self.duration
              return AsyncThrowingStream { continuation in
                  let state = TranscriptionState(
                      sourceHash: "test",
                      sourceDuration: duration,
                      chunkDurationSeconds: duration,
                      completedChunkCount: 1,
                      recognizedSegments: segments,
                      isComplete: true
                  )
                  continuation.yield(state)
                  continuation.finish()
              }
          }
      }

      // Two segments separated by a 2.0s gap: end at 1.0s, next start at 3.0s.
      private static func twoWordSegmentsWith2sGap() -> [TranscriptionState.RecognizedSegment] {
          [
              .init(text: "alpha", startTime: 0.0, endTime: 1.0, confidence: 0.9),
              .init(text: "beta",  startTime: 3.0, endTime: 4.0, confidence: 0.9)
          ]
      }

      @Test func analyzeRespectsExplicitPauseThresholdBelowGap() async throws {
          let stub = StubTranscriptionService(
              segments: Self.twoWordSegmentsWith2sGap(),
              duration: 4.0
          )
          let library = FillerLibrary(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
          let service = SmartCutService(library: library, transcriptionService: stub)

          var resolvedEditList: EditList?
          for try await update in await service.analyze(input: URL(fileURLWithPath: "/dev/null"),
                                                        pauseThreshold: 1.5) {
              if case .completed(let list, _, _) = update {
                  resolvedEditList = list
              }
          }

          let editList = try #require(resolvedEditList)
          // Threshold 1.5s, gap 2.0s → gap exceeds → 1 pause cut.
          #expect(editList.pauses.filter(\.isEnabled).count == 1)
      }

      @Test func analyzeRespectsExplicitPauseThresholdAboveGap() async throws {
          let stub = StubTranscriptionService(
              segments: Self.twoWordSegmentsWith2sGap(),
              duration: 4.0
          )
          let library = FillerLibrary(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
          let service = SmartCutService(library: library, transcriptionService: stub)

          var resolvedEditList: EditList?
          for try await update in await service.analyze(input: URL(fileURLWithPath: "/dev/null"),
                                                        pauseThreshold: 2.5) {
              if case .completed(let list, _, _) = update {
                  resolvedEditList = list
              }
          }

          let editList = try #require(resolvedEditList)
          // Threshold 2.5s, gap 2.0s → gap below threshold → 0 pause cuts.
          #expect(editList.pauses.filter(\.isEnabled).count == 0)
      }
  }
  ```

  **Note** (model signatures verified against actual files):
  - `TranscriptionState.init` is the synthesized memberwise init: `(sourceHash:, sourceDuration:, chunkDurationSeconds:, completedChunkCount:, recognizedSegments:, isComplete:)`. `progressFraction` is a computed `var`, not a stored property.
  - `RecognizedSegment.init` takes `(text:, startTime:, endTime:, confidence:)` — separate `start`/`end` fields, NOT a `timeRange` `ClosedRange`.

- [ ] **Step 2: Run the tests, expect PASS.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:SonicMergeTests/SmartCutServicePauseThresholdTests \
    -parallel-testing-enabled NO test 2>&1 | grep -E "✘|✔|passed after|failed after|Test run with" | tail -5
  ```
  Expected: 2 tests pass.

### Task 1.4: Update existing call sites

- [ ] **Step 1: Update `SmartCutViewModel.swift` call site.**

  Open `SonicMerge/Features/SmartCut/SmartCutViewModel.swift`. Find the `analyze()` method's stream loop (around `:140`). The current line:

  ```swift
  for try await update in await service.analyze(input: inputURL) {
  ```

  Change to:

  ```swift
  for try await update in await service.analyze(input: inputURL, pauseThreshold: pauseThreshold) {
  ```

  (`pauseThreshold` here resolves to `self.pauseThreshold`, the existing public `var TimeInterval = 1.5` on `SmartCutViewModel`. No `self.` prefix needed — Swift resolves it.)

- [ ] **Step 2: Update `OnboardingFlow.swift` call site.**

  Open `SonicMerge/Features/Onboarding/OnboardingFlow.swift`. Find the `runAnalyze()` method on `SampleStep` (around `:475`). The current line:

  ```swift
  for try await update in await service.analyze(input: url) {
  ```

  Change to:

  ```swift
  for try await update in await service.analyze(input: url, pauseThreshold: 1.5) {
  ```

  Onboarding uses the literal default since there's no slider; `1.5` matches the spec's default and is explicit at the call site for clarity.

### Task 1.5: Full suite + commit

- [ ] **Step 1: Full test suite, confirm baseline.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/ic-chunk1.log | tail -3
  echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/ic-chunk1.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
  ```
  Expected: `FAIL=5` matching baseline. The 2 new `SmartCutServicePauseThresholdTests` pass.

- [ ] **Step 2: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Features/SmartCut/Services/SmartCutService.swift \
    SonicMerge/Features/SmartCut/Services/TranscriptionService.swift \
    SonicMerge/Features/SmartCut/SmartCutViewModel.swift \
    SonicMerge/Features/Onboarding/OnboardingFlow.swift \
    SonicMergeTests/SmartCutServicePauseThresholdTests.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(smart-cut): explicit pauseThreshold: parameter on SmartCutService.analyze"
  ```

---

## Chunk 2: Hoist `WordCapsule` + add optional `onRemove`

`WordCapsule` is currently `private struct` inside `EditFillerListStudioSheet.swift` at line 124 with a required `let onRemove: () -> Void` (it always renders the trailing ✕). The new `IdleFillerCard` needs the same visual styling but with NO ✕ (read-only summary). Hoist + make `onRemove` optional.

**Spec references:** §5.2 (capsule reuse).

### Task 2.1: Make `onRemove` optional + render conditionally

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Studio/EditFillerListStudioSheet.swift:124-149`

- [ ] **Step 1: Change the struct's visibility and make `onRemove` optional.**

  Open `EditFillerListStudioSheet.swift`. Find:

  ```swift
  private struct WordCapsule: View {
      let word: String
      let onRemove: () -> Void
  ```

  Replace with:

  ```swift
  /// Frosted-glass capsule for one filler word. When `onRemove` is non-nil,
  /// renders a trailing ✕ that calls it (used by the editor sheet). When nil,
  /// renders read-only (used by the idle-screen filler summary card).
  struct WordCapsule: View {
      let word: String
      let onRemove: (() -> Void)?
  ```

  (Drop `private`; change type of `onRemove` to optional.)

- [ ] **Step 2: Conditionally render the ✕ button + remove the inner left/trailing padding when read-only.**

  In the same file's `WordCapsule.body`, replace the entire `body` with:

  ```swift
  var body: some View {
      HStack(spacing: 6) {
          Text(word)
              .font(.subheadline)
              .foregroundStyle(Color(uiColor: semantic.textPrimary))
          if let onRemove {
              Button(action: onRemove) {
                  Image(systemName: "xmark")
                      .font(.caption2.weight(.semibold))
                      .foregroundStyle(Color(uiColor: semantic.accentAction).opacity(0.6))
                      .frame(width: 24, height: 24)
              }
              .buttonStyle(.plain)
              .accessibilityLabel("Remove \(word)")
          }
      }
      .padding(.vertical, 5)
      .padding(.leading, 12)
      .padding(.trailing, onRemove == nil ? 12 : 4)
      .studioFrostedCapsule(cornerRadius: 14)
  }
  ```

  The trailing padding asymmetry is intentional: when ✕ is present, the button has its own 24pt frame so we keep the chip from looking lopsided with `.trailing, 4`. When the button is absent, balance the leading 12pt with `.trailing, 12`.

- [ ] **Step 3: Update the existing call site to pass a non-nil closure.**

  In the same file, find the existing call (around `:42`):

  ```swift
  WordCapsule(word: word) {
      library.remove(word)
  }
  ```

  This still works — Swift's trailing-closure syntax wraps the closure as the second argument. The optional type accepts a non-nil closure transparently. **No change needed.** Verify by reading the call site.

  However, if Swift complains about trailing-closure ambiguity at the call site (the `onRemove: (() -> Void)?` type can sometimes confuse trailing-closure resolution), explicit-label the argument:

  ```swift
  WordCapsule(word: word, onRemove: {
      library.remove(word)
  })
  ```

- [ ] **Step 4: Build to confirm compile.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`. If trailing-closure ambiguity warns, apply the explicit-label fix from Step 3 and rebuild.

### Task 2.2: End-of-chunk verification + commit

- [ ] **Step 1: Full test suite.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/ic-chunk2.log | tail -3
  echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/ic-chunk2.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
  ```
  Expected: `FAIL=5`.

- [ ] **Step 2: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Features/SmartCut/Views/Studio/EditFillerListStudioSheet.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "refactor(smart-cut): hoist WordCapsule to file-internal; optional onRemove for read-only mode"
  ```

---

## Chunk 3: Move `.sheet` to body + create `IdleSettingsCards`

This is the biggest chunk: relocate the existing filler-list `.sheet` from inside `studioLayout(headerBanner:)` to the container's `body`, then create `IdleSettingsCards.swift` and embed it inside `idleScaffold`.

**Spec references:** §4 (layout), §5 (component specs), §7 (state plumbing).

### Task 3.1: Move the `.sheet(isPresented: $showEditFillerList)` modifier to body level

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift`

- [ ] **Step 1: Wrap the body's bare `switch` in a `Group`.**

  Open `SmartCutStudioContainer.swift`. The current `body` (around `:34`) is:

  ```swift
  var body: some View {
      switch vm.state {
      case .idle:
          idleScaffold
      // ... other cases ...
      case .error(let message):
          errorScaffold(message: message)
      }
  }
  ```

  Wrap the `switch` in a `Group { ... }` so we can attach a modifier at body level:

  ```swift
  var body: some View {
      Group {
          switch vm.state {
          case .idle:
              idleScaffold
          // ... other cases unchanged ...
          case .error(let message):
              errorScaffold(message: message)
          }
      }
  }
  ```

- [ ] **Step 2: Move the `.sheet(isPresented: $showEditFillerList)` from `studioLayout` to the new `Group`.**

  Find the `.sheet(isPresented: $showEditFillerList)` block currently inside `studioLayout(headerBanner:)` (around `:124-126`):

  ```swift
  .sheet(isPresented: $showEditFillerList) {
      EditFillerListStudioSheet(library: $library)
  }
  ```

  Cut the entire block. Append it to the `Group` from Step 1:

  ```swift
  var body: some View {
      Group {
          switch vm.state {
          // ... cases ...
          }
      }
      .sheet(isPresented: $showEditFillerList) {
          EditFillerListStudioSheet(library: $library)
      }
  }
  ```

  Now both `idleScaffold` (which `IdleSettingsCards` will trigger in Task 3.3) and `studioLayout` (the existing post-analyze trigger) share the single sheet attachment. The sibling `.sheet(item: openCategory ...)` (around `:111`) stays inside `studioLayout` — it's only relevant post-analyze.

- [ ] **Step 3: Build.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`.

### Task 3.2: Create `IdleSettingsCards.swift`

**Files:**
- Create: `SonicMerge/Features/SmartCut/Views/Studio/IdleSettingsCards.swift`

- [ ] **Step 1: Create the file.**

  ```swift
  // IdleSettingsCards.swift
  // SonicMerge
  //
  // Pre-analyze controls on the Smart Cut idle screen: the long-pause
  // threshold slider and a read-only filler-word summary with an Edit
  // link. The pause card writes directly to viewModel.pauseThreshold;
  // the filler card displays library.allWords as read-only chips and
  // calls back via `onEditFillerList` to open the existing
  // EditFillerListStudioSheet (sheet attachment lives at the
  // SmartCutStudioContainer body level).
  //
  // Spec: docs/superpowers/specs/2026-05-04-smart-cut-idle-controls-design.md

  import SwiftUI
  import UIKit

  struct IdleSettingsCards: View {
      @Bindable var viewModel: SmartCutViewModel
      @Binding var library: FillerLibrary
      let onEditFillerList: () -> Void

      var body: some View {
          VStack(spacing: 12) {
              IdlePauseCard(viewModel: viewModel)
              IdleFillerCard(library: library, onEdit: onEditFillerList)
          }
      }
  }

  // MARK: - Pause card

  private struct IdlePauseCard: View {
      @Bindable var viewModel: SmartCutViewModel
      @Environment(\.sonicMergeSemantic) private var semantic
      @Environment(\.accessibilityReduceMotion) private var reduceMotion

      /// Drives the slider locally so the rolling-digit readout animates
      /// smoothly during drag. Synced via .onAppear (initial) and pushed to
      /// viewModel.pauseThreshold on each step change.
      @State private var draftThreshold: TimeInterval = 1.5

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
                                  // Pre-analyze direct write — setPauseThreshold(_:) bails
                                  // when cachedSegments is empty, which is always true here.
                                  viewModel.pauseThreshold = new
                                  UIImpactFeedbackGenerator(style: .light).impactOccurred()
                              }
                          Text("Cuts silences longer than \(SmartCutFormatting.formatThreshold(draftThreshold)).")
                              .font(.caption)
                              .foregroundStyle(Color(uiColor: semantic.textSecondary))
                              .contentTransition(reduceMotion ? .identity : .numericText())
                      }
                  }
              },
              trailing: { EmptyView() }
          )
          .onAppear { draftThreshold = viewModel.pauseThreshold }
          .accessibilityElement(children: .combine)
          .accessibilityLabel("Pause threshold: \(SmartCutFormatting.formatThreshold(draftThreshold))")
          .accessibilityHint("Adjust to set the minimum silence length that gets cut.")
      }
  }

  // MARK: - Filler card

  private struct IdleFillerCard: View {
      let library: FillerLibrary
      let onEdit: () -> Void
      @Environment(\.sonicMergeSemantic) private var semantic

      private var words: [String] { library.allWords }

      var body: some View {
          StudioBentoCard(
              leading: {
                  VStack(alignment: .leading, spacing: 10) {
                      HStack {
                          Image(systemName: "text.bubble")
                              .foregroundStyle(Color(uiColor: semantic.textSecondary))
                              .font(.title3)
                          Text("FILLER WORDS")
                              .font(.caption2.weight(.semibold))
                              .foregroundStyle(Color(uiColor: semantic.textSecondary))
                          Spacer()
                          Text("\(words.count) word\(words.count == 1 ? "" : "s")")
                              .font(.caption.weight(.semibold))
                              .padding(.horizontal, 8).padding(.vertical, 2)
                              .background(Capsule().fill(Color(uiColor: semantic.accentAction).opacity(0.14)))
                              .foregroundStyle(Color(uiColor: semantic.accentAction))
                      }

                      if words.isEmpty {
                          Text("No filler words. Tap Edit list to add some.")
                              .font(.subheadline)
                              .foregroundStyle(Color(uiColor: semantic.textSecondary))
                      } else {
                          ChipFlow(words: words)
                              .accessibilityHidden(true)
                      }

                      Button(action: onEdit) {
                          HStack(spacing: 4) {
                              Image(systemName: "pencil")
                              Text("Edit list")
                              Image(systemName: "chevron.right")
                                  .font(.caption2.weight(.semibold))
                          }
                          .font(.subheadline.weight(.semibold))
                          .foregroundStyle(Color(uiColor: semantic.accentAction))
                      }
                      .buttonStyle(.plain)
                      .accessibilityLabel("Edit filler list")
                  }
              },
              trailing: { EmptyView() }
          )
          .accessibilityElement(children: .contain)
          .accessibilityLabel("Filler words. \(words.count) word\(words.count == 1 ? "" : "s"). Tap Edit list to modify.")
      }
  }

  // MARK: - Chip flow (uses existing StudioFlowLayout)

  private struct ChipFlow: View {
      let words: [String]

      var body: some View {
          // Reuses the project's existing `StudioFlowLayout` (already used by
          // EditFillerListStudioSheet for the same chip-wrap layout).
          StudioFlowLayout(spacing: 6) {
              ForEach(words, id: \.self) { word in
                  WordCapsule(word: word, onRemove: nil)
              }
          }
      }
  }
  ```

  **Existing infrastructure used:** `StudioFlowLayout` is already at `SonicMerge/Features/SmartCut/Views/Studio/StudioFlowLayout.swift` and is used by `EditFillerListStudioSheet:40` for the identical chip-wrap layout. Reusing it keeps a single source of truth for wrap behavior.

- [ ] **Step 2: Build to confirm.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`. The new file isn't referenced anywhere yet, so this is just a clean-compile check.

### Task 3.3: Embed `IdleSettingsCards` in `idleScaffold`

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift:154-177` (the existing `idleScaffold` body)

- [ ] **Step 1: Replace `idleScaffold`'s body.**

  Find the existing `private var idleScaffold: some View { ... }` block (currently `:154-177`):

  ```swift
  private var idleScaffold: some View {
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
  ```

  Replace with:

  ```swift
  private var idleScaffold: some View {
      ScrollView {
          VStack(spacing: 16) {
              Text("Remove fillers and trim long silences")
                  .foregroundStyle(.secondary)

              smartCutOrb(active: false)
                  .tint(.green)
                  // Shrink the existing 80pt orb to ~56pt visually + reserve
                  // a 56×56 layout slot. `.scaleEffect` defaults to `.center`
                  // anchor, which is what we want — the orb stays visually
                  // centered inside its frame.
                  .scaleEffect(56.0 / 80.0, anchor: .center)
                  .frame(width: 56, height: 56)

              IdleSettingsCards(
                  viewModel: vm,
                  library: $library,
                  onEditFillerList: { showEditFillerList = true }
              )

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
  }
  ```

  Notes:
  - The orb shrink uses `.scaleEffect` + an explicit 56×56 frame so the layout reserves the smaller area while reusing `smartCutOrb(active:)` verbatim. (We could alternately add a `size:` parameter to `smartCutOrb` — defer that as a polish refactor; the scaleEffect approach is one line and reversible.)
  - `library` is the existing `@Binding<FillerLibrary>` already at the struct level (`SmartCutStudioContainer.swift:28`). `$library` works.
  - `showEditFillerList` is the existing `@State` (`SmartCutStudioContainer.swift:32`).

- [ ] **Step 2: Build.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`.

### Task 3.4: End-of-chunk verification + commit

- [ ] **Step 1: Full test suite.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/ic-chunk3.log | tail -3
  echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/ic-chunk3.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
  ```
  Expected: `FAIL=5` baseline.

- [ ] **Step 2: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift \
    SonicMerge/Features/SmartCut/Views/Studio/IdleSettingsCards.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(smart-cut): IdleSettingsCards — pre-analyze pause + filler controls"
  ```

---

## Chunk 4: Final verification + manual QA

### Task 4.1: Final full test suite + tree check

- [ ] **Step 1: Final suite.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/ic-final.log | tail -3
  echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/ic-final.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
  ```
  Expected: `FAIL=5` matching baseline. The 2 new `SmartCutServicePauseThresholdTests` pass.

- [ ] **Step 2: Tree clean.**

  Run: `git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge status`
  Expected: only the standing `.xcuserstate` modification.

### Task 4.2: Manual QA on simulator (spec §11.3)

Run on the iPhone 17 simulator:

- [ ] **1. Pause threshold persistence.** Open a Smart Cut session → idle screen → drag pause slider to 2.5s → tap Analyze → confirm result page shows pauses ≥ 2.5s only (none in 1.5–2.5s range).
- [ ] **2. Filler list editing.** Idle screen → tap "Edit list" → sheet opens → remove "um" → close sheet → idle screen chip wrap reflects removed word + count is N–1.
- [ ] **3. Empty filler library.** Edit sheet → remove every word → close → idle screen shows "No filler words. Tap Edit list to add some." → tap Edit → add "however" → close → chip wrap shows `[however]`, count is 1.
- [ ] **4. Reduce Motion ON.** Settings → Accessibility → Reduce Motion → idle slider drag still works; threshold readout updates without animation.
- [ ] **5. Reduce Transparency ON.** Idle chips render with solid `surfaceCard` background (no glass).
- [ ] **6. Dynamic Type XL.** Idle scaffold scrolls; nothing clips off-screen.
- [ ] **7. VoiceOver.** Pause card and filler card both reachable; labels read as specified ("Pause threshold: 1.5s" / "Filler words. N words. Tap Edit list to modify.").
- [ ] **8. Onboarding sample.** Re-run onboarding's Smart Cut sample → confirm it still works (this is the second `service.analyze` call site that gets the wiring change).

### Task 4.3: Hand off

- [ ] **Step 1: Use the `superpowers:finishing-a-development-branch` skill to merge or PR this work.**

  Announce: "I'm using the finishing-a-development-branch skill to complete this work."
