# CleanCut Onboarding Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 5-screen first-launch onboarding flow that introduces CleanCut's three features, sets the "private by design" thesis, prompts for Speech Recognition contextually, and lands the user in a hands-on Smart Cut magic moment on a bundled real podcast sample — all in ≤45s, gated by `@AppStorage("sonicMerge.hasOnboarded")`.

**Architecture:** A single new `OnboardingFlow.swift` (~280 lines) with five private nested step views, presented as a `.fullScreenCover` from `RootTabView` whenever the gate flag is `false`. Step 4 invokes the existing `SmartCutService.analyze(input:)` against a bundled `onboarding-sample.m4a` and the existing `AudioCutter.apply(input:editList:)` to produce a cleaned preview for the step-5 A/B toggle. No new services, no new view models, no new design tokens — onboarding consumes what's already there.

**Tech Stack:** Swift 6, SwiftUI, `@AppStorage`, `AVAudioPlayer`, existing `SmartCutService` + `AudioCutter` + `FillerLibraryStore`, Swift Testing for the smoke tests.

**Spec:** `docs/superpowers/specs/2026-05-03-cleancut-onboarding-design.md`.

> **Line-number policy:** Cited line numbers reflect `main` at plan-write time and may drift by 1–3 lines as Chunks land. Always locate target blocks by **searching the code snippet provided**, not by jumping to the cited line.

---

## Chunk 0: Branch + baseline

### Task 0.1: Verify clean working tree and create branch

**Files:** none (git only)

- [ ] **Step 1: Confirm we're on `main` and the tree is clean except for the standing UI-state file.**

  Run: `git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge status`
  Expected: only `M  SonicMerge.xcodeproj/.../UserInterfaceState.xcuserstate` and untracked `.cursor/` / `.superpowers/`. Anything else — investigate before continuing.

- [ ] **Step 2: Create the feature branch from main.**

  Run: `git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge checkout -b feat/onboarding main`
  Expected: `Switched to a new branch 'feat/onboarding'`.

- [ ] **Step 3: Baseline test run.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/ob-baseline.log | tail -3
  echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/ob-baseline.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
  ```
  Expected: build SUCCEEDS. `FAIL=5` with the same baseline names: `compositionWithCrossfadeHasNonNilAudioMix`, `testFileCopyToClipsDirectory`, `testLargeFileCopyDoesNotCrash`, `testPendingKeyWrittenAndCleared`, `testPositionPreservedOnSwitch`. New regressions are blockers.

---

## Chunk 1: Source + verify the bundled podcast sample

This chunk is a **manual research + verification** chunk before any view code is written. The bundled audio file is a hard dependency for Chunks 4 and 5 — without it, those chunks can't be built or tested. Per spec §6, the implementer picks one of three sources, downloads/records the candidate, runs the existing app's `SmartCutService` against it locally, and only proceeds when the empirical acceptance bar is met.

**Spec references:** §6.1 properties, §6.2 acceptance bar, §6.3 sourcing priority, §6.4 bundle location.

### Task 1.1: Pick a sourcing strategy and obtain a candidate file

**Files:**
- Output: `~/Downloads/onboarding-sample-candidate.m4a` (or any working-directory file — exact path doesn't matter, this stays outside the repo until verification passes)

- [ ] **Step 1: Choose a sourcing strategy.**

  Per spec §6.3, in priority order:
  1. **CC-BY podcast/interview from Internet Archive.** Search https://archive.org/details/podcasts for CC-BY-licensed shows. Filter for solo conversational segments. Examples: TWiT.tv archives, oral-history collections, conference interviews. Read the per-episode license — it MUST permit redistribution + modification (CC-BY, CC-BY-SA, CC-0, or public domain).
  2. **Project-owner-recorded clip.** Record ~60s of natural conversational speech using QuickTime / Voice Memos with the room's normal ambient noise (don't sit in a sound booth — we want the noise floor). Suggested topic that yields organic fillers: *"Tell me about the most surprising thing you learned at a conference last year"*. Trim to 30s in any audio editor.
  3. **Synthesized via TTS — REJECTED in spec.** Don't use this.

  Document the choice in a one-line note for the commit message. If choice = (1), copy the original source URL and license verbatim — Step 1.3 will need it.

- [ ] **Step 2: Trim/encode the candidate to spec.**

  Required output:
  - Duration: 28–32 seconds
  - Format: AAC, 48 kHz, stereo, ~256–320 kbps
  - File size: ~300–500 KB
  - Single conversational speaker, speech-only, no music/jingles

  Use any audio editor (Audacity, Logic, Adobe Audition, ffmpeg). For ffmpeg:
  ```bash
  ffmpeg -i input.{wav,mp3,...} -ss 0 -t 30 \
    -c:a aac -b:a 256k -ar 48000 -ac 2 \
    ~/Downloads/onboarding-sample-candidate.m4a
  ```
  Adjust `-ss` to find the best 30s window (one with high filler density and at least one long pause).

- [ ] **Step 3: Place the candidate in the repo for the verification step.**

  Drop the candidate at the bundle location:
  ```bash
  mkdir -p /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMerge/Resources
  cp ~/Downloads/onboarding-sample-candidate.m4a \
    /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMerge/Resources/onboarding-sample.m4a
  ```
  The file is now part of the main app target via `PBXFileSystemSynchronizedRootGroup` (auto-included).

### Task 1.2: Verify the candidate against the empirical acceptance bar

**Files:**
- Test (temporary, deleted in Step 3): `SonicMergeTests/_OnboardingSampleVerificationTests.swift`

- [ ] **Step 1: Write a one-shot verification test that runs `SmartCutService` against the bundled file and asserts the spec's acceptance bar.**

  Create `SonicMergeTests/_OnboardingSampleVerificationTests.swift` (the leading `_` marks it as a one-shot helper, deleted after pass):

  ```swift
  import Testing
  import Foundation
  @testable import SonicMerge

  @MainActor
  struct _OnboardingSampleVerificationTests {

      /// One-shot empirical-acceptance check for the bundled onboarding sample.
      /// Per spec §6.2: ≥8s savings, ≥2 filler categories, ≥1 pause cut.
      /// DELETE this file after the test passes — it's a sourcing gate, not
      /// a permanent regression test (the audio file doesn't change at runtime).
      @Test func bundledSampleMeetsEmpiricalAcceptanceBar() async throws {
          // In `xcodebuild test`, the host app loads alongside the test bundle.
          // `Bundle.main` resolves to the test runner; the audio sits in the
          // main app's bundle, so look it up by identifier with a fallback.
          let url = Bundle.main.url(forResource: "onboarding-sample", withExtension: "m4a")
              ?? Bundle(identifier: "com.dtech.SonicMerge")?
                  .url(forResource: "onboarding-sample", withExtension: "m4a")
          guard let url else {
              Issue.record("Bundle missing onboarding-sample.m4a in both Bundle.main and com.dtech.SonicMerge — Task 1.1 Step 3 didn't drop the file in the right place, or the file isn't in the main app target's Resources")
              return
          }

          let library = FillerLibrary(defaults: UserDefaults(suiteName: "verify-\(UUID())")!)
          let service = SmartCutService(library: library)

          var finalEditList: EditList?
          for try await update in service.analyze(input: url) {
              if case .completed(let list, _, _) = update {
                  finalEditList = list
              }
          }

          let editList = try #require(finalEditList, "analyze did not yield .completed")

          let savings = editList.enabledSavings
          let categoryCount = editList.categories.count
          let enabledPauseCount = editList.pauses.filter(\.isEnabled).count

          print("[ONBOARDING SAMPLE METRICS] savings=\(savings)s categories=\(categoryCount) pauseCuts=\(enabledPauseCount)")

          #expect(savings >= 8.0, "spec §6.2: savings must be ≥ 8 seconds — got \(savings)s")
          #expect(categoryCount >= 2, "spec §6.2: must have ≥ 2 filler categories — got \(categoryCount)")
          #expect(enabledPauseCount >= 1, "spec §6.2: must have ≥ 1 enabled pause cut — got \(enabledPauseCount)")
      }
  }
  ```

- [ ] **Step 2: Run the verification test.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:SonicMergeTests/_OnboardingSampleVerificationTests \
    -parallel-testing-enabled NO test 2>&1 | tail -25
  ```

  - **PASS:** Read the printed `[ONBOARDING SAMPLE METRICS]` line and record the actual values for the commit message. Proceed to Task 1.3.
  - **FAIL on `savings`:** the clip doesn't have enough filler content. Pick a different 30s window (more dense fillers) or a different source clip and repeat Task 1.1 Step 2 → Step 3 → 1.2 Step 2.
  - **FAIL on `categoryCount`:** all fillers are the same word ("um, um, um" only). Pick a clip with mixed fillers ("um", "uh", "you know", "like").
  - **FAIL on `enabledPauseCount`:** no silences ≥ 1.5s. Pick a clip with a thinking pause / breath / topic transition.
  - **FAIL with "Bundle missing":** Task 1.1 Step 3 didn't run — copy the file to the right path.

  Iterate until the test passes. Don't fudge the assertions — they encode the spec's empirical bar.

- [ ] **Step 3: Delete the verification test (it's not a regression test).**

  Run:
  ```bash
  rm /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMergeTests/_OnboardingSampleVerificationTests.swift
  ```

  Reason: the audio file is immutable post-bundle. Re-running this test on every CI build would be wasted work. The test served its purpose at sourcing time.

### Task 1.3: Add attribution file (only if CC-BY source) + commit

**Files:**
- Create (CC-BY source only): `SonicMerge/Resources/onboarding-sample-credit.txt`

- [ ] **Step 1: If the chosen source is CC-BY, write the attribution file.**

  Format (one line, plaintext, exactly):
  ```
  Onboarding sample audio: "<original title>" by <attribution name>, <year>, licensed under <CC-BY-X.X>. Source: <original URL>.
  ```

  If the source is project-owner-recorded or public domain, **skip this step** — no attribution file needed.

- [ ] **Step 2: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Resources/onboarding-sample.m4a \
    SonicMerge/Resources/onboarding-sample-credit.txt   # only if it exists
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(onboarding): bundle podcast sample (savings=Xs, categories=Y, pauseCuts=Z)"
  ```

  Replace `Xs`, `Y`, `Z` with the actual metrics from Task 1.2 Step 2's print output. The metrics in the commit message are the proof-of-acceptance for future reviewers.

---

## Chunk 2: Gate flag + RootTabView hook + smoke tests

This chunk wires up the `@AppStorage("sonicMerge.hasOnboarded")` gate and the `.fullScreenCover` on `RootTabView`. The cover will present an empty `OnboardingFlow` placeholder for now — Chunks 3–5 fill in the step views. Smoke tests for the AppStorage roundtrip ship in this chunk so subsequent chunks have green tests to compare against.

**Spec references:** §3 architecture, §8 migration, §11.1 smoke tests.

### Task 2.1: Smoke tests for the gate flag (TDD)

**Files:**
- Create: `SonicMergeTests/OnboardingGateTests.swift`

- [ ] **Step 1: Write the failing tests first.**

  Create `SonicMergeTests/OnboardingGateTests.swift`:

  ```swift
  // SMOKE TESTS — see QA checklist in spec §11.3 for full integration coverage.
  // These verify the storage layer behaves as expected; they do NOT exercise
  // the @AppStorage SwiftUI integration in RootTabView or the .fullScreenCover
  // presentation behavior. Manual QA covers those.

  import Testing
  import Foundation
  @testable import SonicMerge

  struct OnboardingGateTests {

      @Test func defaultGateIsFalse() {
          let defaults = UserDefaults(suiteName: "test-\(UUID())")!
          #expect(defaults.bool(forKey: "sonicMerge.hasOnboarded") == false)
      }

      @Test func gateRoundtripsAcrossInstances() {
          let suite = "test-\(UUID())"
          let writer = UserDefaults(suiteName: suite)!
          writer.set(true, forKey: "sonicMerge.hasOnboarded")
          let reader = UserDefaults(suiteName: suite)!
          #expect(reader.bool(forKey: "sonicMerge.hasOnboarded") == true)
      }
  }
  ```

- [ ] **Step 2: Run the tests, expect PASS already (these don't need any new production code).**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:SonicMergeTests/OnboardingGateTests \
    -parallel-testing-enabled NO test 2>&1 | grep -E "✘|✔|passed after|failed after|Test run with" | tail -5
  ```
  Expected: 2 tests pass.

  *Note: these are smoke tests that exercise UserDefaults directly. They guard against the storage key being mistyped at any future refactor point — if someone renames `"sonicMerge.hasOnboarded"` to `"sonicMerge.hasCompletedOnboarding"` and forgets to update both the test and the production code, the test will keep passing because it reads its own write. The real defense is the manual QA gate in §11.3 item 1.*

### Task 2.2: Create OnboardingFlow placeholder file

**Files:**
- Create: `SonicMerge/Features/Onboarding/OnboardingFlow.swift`

- [ ] **Step 1: Create the directory + file with a placeholder body.**

  ```bash
  mkdir -p /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMerge/Features/Onboarding
  ```

  Create `SonicMerge/Features/Onboarding/OnboardingFlow.swift`:

  ```swift
  // OnboardingFlow.swift
  // SonicMerge
  //
  // First-launch onboarding. 5 steps: brand opener → trust primer →
  // speech recognition permission → hands-on Smart Cut on bundled
  // sample → result + Denoise reveal. Gated by @AppStorage flag in
  // RootTabView. Spec: docs/superpowers/specs/2026-05-03-cleancut-onboarding-design.md

  import SwiftUI

  struct OnboardingFlow: View {
      /// Set true on Done; the @AppStorage in RootTabView observes the same
      /// key and dismisses the .fullScreenCover.
      @AppStorage("sonicMerge.hasOnboarded") private var hasOnboarded: Bool = false

      var body: some View {
          // TODO Chunk 3+: replace with actual step views.
          ZStack {
              Color.black.opacity(0.001)  // tappable placeholder for tests
              VStack(spacing: 16) {
                  Text("Onboarding placeholder")
                      .font(.headline)
                  Button("Done · Open Smart Cut") {
                      hasOnboarded = true
                  }
              }
          }
      }
  }
  ```

  This placeholder lets Chunk 2 land with a working dismiss path so manual QA can verify the gate end-to-end before we invest in step UI. Subsequent chunks replace the body progressively.

### Task 2.3: Wire the .fullScreenCover into RootTabView

**Files:**
- Modify: `SonicMerge/App/RootTabView.swift`

- [ ] **Step 1: Add the gate `@AppStorage` on `RootTabView`.**

  Open `SonicMerge/App/RootTabView.swift`. Find the existing `@AppStorage` declaration (currently around `:20`):

  ```swift
  @AppStorage("sonicMergeThemePreference") private var themePreferenceRaw: String = ThemePreference.light.rawValue
  ```

  Immediately below it, add:

  ```swift
  @AppStorage("sonicMerge.hasOnboarded") private var hasOnboarded: Bool = false
  ```

- [ ] **Step 2: Add the `.fullScreenCover` modifier on the TabView.**

  Find the modifier chain ending in `.onOpenURL { url in handleDeepLink(url) }` (around `:80`). Immediately before that line, insert:

  ```swift
  .fullScreenCover(isPresented: Binding(
      get: { !hasOnboarded },
      set: { newValue in if !newValue { hasOnboarded = true } }
  )) {
      OnboardingFlow()
  }
  .onChange(of: hasOnboarded) { _, newValue in
      // Spec §5 Done flow step 2: explicitly land on Smart Cut tab when
      // onboarding completes, even if the user navigated tabs in some
      // edge-case mid-onboarding scenario.
      if newValue {
          selection = .smartCut
      }
  }
  ```

  The Binding pattern (instead of `isPresented: !$hasOnboarded`) is required because `Bool` `@AppStorage` projection produces `Binding<Bool>` for the raw value, not its negation. The setter clamps so SwiftUI's "user dismissed sheet" path also marks onboarding done — which we want, since the only way out of the cover is via the Done button anyway.

  The `.onChange` ensures the post-onboarding tab is always Smart Cut. `selection` is the existing `@State` on `RootTabView` (declared near the top of the file as `@State private var selection: Tab = .smartCut`).

- [ ] **Step 3: Build.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`.

### Task 2.4: End-of-chunk verification + commit

- [ ] **Step 1: Full test suite.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/ob-chunk2.log | tail -3
  echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/ob-chunk2.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
  ```
  Expected: `FAIL=5` (matches Chunk 0 baseline). The 2 new `OnboardingGateTests` pass and don't add to FAIL count.

- [ ] **Step 2: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMergeTests/OnboardingGateTests.swift \
    SonicMerge/Features/Onboarding/OnboardingFlow.swift \
    SonicMerge/App/RootTabView.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(onboarding): gate flag + RootTabView hook + placeholder OnboardingFlow"
  ```

---

## Chunk 3: Steps 1 + 2 — Brand opener and Trust primer

Two static SwiftUI screens with no business logic. Replaces the placeholder body of `OnboardingFlow` with a step-machine that drives between three states: brand opener (step 1), trust primer (step 2), and a `.placeholder` state for steps 3–5 (filled in later chunks).

**Spec references:** §5 step 1, §5 step 2, §10 accessibility.

### Task 3.1: Add the step state machine + brand-opener step view

**Files:**
- Modify: `SonicMerge/Features/Onboarding/OnboardingFlow.swift`

- [ ] **Step 1: Replace the placeholder body with the step machine and step 1 view.**

  Open `SonicMerge/Features/Onboarding/OnboardingFlow.swift`. Replace the entire file content with:

  ```swift
  // OnboardingFlow.swift
  // SonicMerge
  //
  // First-launch onboarding. 5 steps: brand opener → trust primer →
  // speech recognition permission → hands-on Smart Cut on bundled
  // sample → result + Denoise reveal. Gated by @AppStorage flag in
  // RootTabView. Spec: docs/superpowers/specs/2026-05-03-cleancut-onboarding-design.md

  import SwiftUI

  struct OnboardingFlow: View {
      enum Step: Int { case brand = 0, trust, permission, sample, result }

      @AppStorage("sonicMerge.hasOnboarded") private var hasOnboarded: Bool = false
      @Environment(\.sonicMergeSemantic) private var semantic
      @Environment(\.accessibilityReduceMotion) private var reduceMotion
      @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

      @State private var step: Step = .brand

      var body: some View {
          ZStack {
              PremiumBackground()
              VStack(spacing: 0) {
                  StepProgressIndicator(step: step)
                      .padding(.top, 16)

                  Group {
                      switch step {
                      case .brand:
                          BrandOpenerStep(
                              semantic: semantic,
                              reduceMotion: reduceMotion,
                              onContinue: { advance(to: .trust) },
                              onSkip: { advance(to: .trust) }   // skip → trust per spec §5 step 1
                          )
                      case .trust:
                          TrustPrimerStep(
                              semantic: semantic,
                              reduceTransparency: reduceTransparency,
                              onContinue: { advance(to: .permission) }
                          )
                      case .permission, .sample, .result:
                          // TODO Chunks 4–5: replace
                          VStack {
                              Text("Step \(step.rawValue + 1) — not yet implemented")
                              Button("Done · Open Smart Cut") { hasOnboarded = true }
                                  .buttonStyle(.borderedProminent)
                          }
                          .frame(maxWidth: .infinity, maxHeight: .infinity)
                      }
                  }
                  .frame(maxHeight: .infinity)
              }
              .padding(.horizontal, 24)
              .padding(.bottom, 32)
          }
      }

      private func advance(to next: Step) {
          if reduceMotion {
              step = next
          } else {
              withAnimation(.easeInOut(duration: 0.25)) { step = next }
          }
      }
  }

  // MARK: - Step progress indicator

  private struct StepProgressIndicator: View {
      let step: OnboardingFlow.Step

      var body: some View {
          HStack(spacing: 6) {
              ForEach(0..<5, id: \.self) { index in
                  let isActive = index == step.rawValue
                  RoundedRectangle(cornerRadius: 2, style: .continuous)
                      .fill(isActive ? Color(uiColor: .systemIndigo) : Color(uiColor: .systemGray3))
                      .frame(width: isActive ? 24 : 14, height: 4)
                      .animation(.easeInOut(duration: 0.2), value: step)
              }
          }
          .accessibilityHidden(true)  // per-step .accessibilityLabel covers position
      }
  }

  // MARK: - Step 1: Brand opener

  private struct BrandOpenerStep: View {
      let semantic: SonicMergeSemantic
      let reduceMotion: Bool
      let onContinue: () -> Void
      let onSkip: () -> Void

      var body: some View {
          VStack(spacing: 0) {
              HStack {
                  Spacer()
                  Button("Skip", action: onSkip)
                      .font(.subheadline)
                      .foregroundStyle(Color(uiColor: semantic.textSecondary))
              }
              .padding(.top, 8)

              Spacer(minLength: 0)

              // Hero badge — gradient at 20% alpha, sparkles inside
              ZStack {
                  RoundedRectangle(cornerRadius: 24, style: .continuous)
                      .fill(LinearGradient(
                          colors: [
                              Color(uiColor: semantic.accentAI).opacity(0.20),
                              Color(uiColor: semantic.accentAction).opacity(0.20)
                          ],
                          startPoint: .topLeading,
                          endPoint: .bottomTrailing
                      ))
                  Image(systemName: "sparkles")
                      .font(.system(size: 38, weight: .bold))
                      .foregroundStyle(Color(uiColor: semantic.textPrimary))
              }
              .frame(width: 80, height: 80)
              .accessibilityHidden(true)
              .padding(.bottom, 20)

              Text("Cut. Clean. Merge.")
                  .font(.system(.title, design: .rounded, weight: .bold))
                  .foregroundStyle(Color(uiColor: semantic.textPrimary))
                  .multilineTextAlignment(.center)
                  .padding(.bottom, 8)

              Text("Your audio toolkit, all on this device.")
                  .font(.system(.body, design: .rounded))
                  .foregroundStyle(Color(uiColor: semantic.textSecondary))
                  .multilineTextAlignment(.center)
                  .frame(maxWidth: 280)
                  .padding(.bottom, 24)

              VStack(spacing: 10) {
                  FeaturePill(icon: "sparkles", iconBg: Color(uiColor: semantic.accentAI),
                              title: "Smart Cut", subtitle: "remove fillers", semantic: semantic)
                  FeaturePill(icon: "waveform.badge.minus", iconBg: Color(uiColor: semantic.accentAI),
                              title: "Denoise", subtitle: "clean noisy clips", semantic: semantic)
                  FeaturePill(icon: "rectangle.stack", iconBg: Color(uiColor: semantic.accentAction),
                              title: "Merge", subtitle: "combine audio", semantic: semantic)
              }

              Spacer()

              Button(action: onContinue) {
                  Text("Continue")
                      .font(.system(.body, design: .rounded, weight: .semibold))
                      .foregroundStyle(.white)
                      .frame(maxWidth: .infinity)
                      .padding(.vertical, 14)
                      .background(Capsule().fill(Color(uiColor: semantic.accentAction)))
              }
          }
          .accessibilityElement(children: .contain)
          .accessibilityLabel("Step 1 of 5: Cut. Clean. Merge. Your audio toolkit, all on this device.")
      }
  }

  private struct FeaturePill: View {
      let icon: String
      let iconBg: Color
      let title: String
      let subtitle: String
      let semantic: SonicMergeSemantic

      var body: some View {
          HStack(spacing: 12) {
              ZStack {
                  RoundedRectangle(cornerRadius: 7, style: .continuous).fill(iconBg)
                  Image(systemName: icon)
                      .font(.system(size: 13, weight: .bold))
                      .foregroundStyle(.white)
              }
              .frame(width: 24, height: 24)
              VStack(alignment: .leading, spacing: 0) {
                  Text(title).font(.subheadline.weight(.semibold))
                      .foregroundStyle(Color(uiColor: semantic.textPrimary))
                  Text(subtitle).font(.caption)
                      .foregroundStyle(Color(uiColor: semantic.textSecondary))
              }
              Spacer()
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
          .background(
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .fill(Color(uiColor: semantic.surfaceCard))
                  .overlay(
                      RoundedRectangle(cornerRadius: 12, style: .continuous)
                          .strokeBorder(Color(uiColor: .systemGray5), lineWidth: 0.5)
                  )
          )
      }
  }
  ```

  Note: `TrustPrimerStep` is referenced but not yet defined — that compiles failure is expected and Step 2 below adds it.

- [ ] **Step 2: Build to confirm the compile failure.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -5
  ```
  Expected: `Cannot find 'TrustPrimerStep' in scope` (or similar). Task 3.2 fixes this.

### Task 3.2: Add the trust-primer step view

**Files:**
- Modify: `SonicMerge/Features/Onboarding/OnboardingFlow.swift`

- [ ] **Step 1: Append the trust-primer step view to the file.**

  Open `OnboardingFlow.swift`. At the end of the file (after the `FeaturePill` struct), append:

  ```swift
  // MARK: - Step 2: Trust primer

  private struct TrustPrimerStep: View {
      let semantic: SonicMergeSemantic
      let reduceTransparency: Bool
      let onContinue: () -> Void

      var body: some View {
          VStack(spacing: 0) {
              Spacer().frame(height: 32)  // matches step 1's skip-row height
              Spacer(minLength: 0)

              // Hero badge — indigo at 14% alpha, lock.shield.fill inside
              ZStack {
                  RoundedRectangle(cornerRadius: 24, style: .continuous)
                      .fill(Color(uiColor: semantic.accentAction).opacity(0.14))
                  Image(systemName: "lock.shield.fill")
                      .font(.system(size: 38, weight: .bold))
                      .foregroundStyle(Color(uiColor: semantic.accentAction))
              }
              .frame(width: 80, height: 80)
              .accessibilityHidden(true)
              .padding(.bottom, 20)

              Text("Your audio\nnever leaves\nthis device.")
                  .font(.system(.title, design: .rounded, weight: .bold))
                  .foregroundStyle(Color(uiColor: semantic.textPrimary))
                  .multilineTextAlignment(.center)
                  .padding(.bottom, 8)

              Text("No upload. No cloud. No account.")
                  .font(.system(.body, design: .rounded))
                  .foregroundStyle(Color(uiColor: semantic.textSecondary))
                  .multilineTextAlignment(.center)
                  .padding(.bottom, 24)

              VStack(spacing: 10) {
                  TrustRow(text: "Apple's on-device AI handles every cut",
                           semantic: semantic,
                           reduceTransparency: reduceTransparency)
                  TrustRow(text: "Files stay in CleanCut's private folder",
                           semantic: semantic,
                           reduceTransparency: reduceTransparency)
              }

              Spacer()

              Button(action: onContinue) {
                  Text("Continue")
                      .font(.system(.body, design: .rounded, weight: .semibold))
                      .foregroundStyle(.white)
                      .frame(maxWidth: .infinity)
                      .padding(.vertical, 14)
                      .background(Capsule().fill(Color(uiColor: semantic.accentAction)))
              }
          }
          .accessibilityElement(children: .contain)
          .accessibilityLabel("Step 2 of 5: Your audio never leaves this device. No upload. No cloud. No account.")
      }
  }

  private struct TrustRow: View {
      let text: String
      let semantic: SonicMergeSemantic
      let reduceTransparency: Bool

      var body: some View {
          HStack(spacing: 10) {
              Image(systemName: "checkmark.shield.fill")
                  .foregroundStyle(Color(uiColor: semantic.accentAction))
                  .font(.system(size: 16, weight: .semibold))
              Text(text)
                  .font(.subheadline)
                  .foregroundStyle(Color(uiColor: semantic.textPrimary))
                  .multilineTextAlignment(.leading)
              Spacer()
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 10)
          .background(background)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      }

      @ViewBuilder
      private var background: some View {
          if reduceTransparency {
              Color(uiColor: semantic.surfaceCard)
          } else {
              ZStack {
                  Color(uiColor: semantic.accentGlow).opacity(0.06)
                  Rectangle().fill(.ultraThinMaterial)
              }
          }
      }
  }
  ```

- [ ] **Step 2: Build.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`.

### Task 3.3: End-of-chunk verification + commit

- [ ] **Step 1: Full test suite.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/ob-chunk3.log | tail -3
  echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/ob-chunk3.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
  ```
  Expected: `FAIL=5`.

- [ ] **Step 2: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Features/Onboarding/OnboardingFlow.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(onboarding): brand opener + trust primer steps"
  ```

---

## Chunk 4: Step 3 (permission) + Step 4 (hands-on first cut)

Step 3 triggers `SFSpeechRecognizer.requestAuthorization` and immediately advances to step 4. Step 4 loads the bundled sample, displays a card with a waveform stripe, and runs `SmartCutService.analyze(input:)` + `AudioCutter.apply(input:editList:)` when the user taps the lime CTA. The `editList`, `cleanedURL`, and `originalURL` are captured into shared `@State` on `OnboardingFlow` so step 5 can read them.

**Spec references:** §5 step 3, §5 step 4 (granted + denied paths), §6 (sample bundling), §7.1 (permissions).

### Task 4.1: Add the permission gate + shared state

**Files:**
- Modify: `SonicMerge/Features/Onboarding/OnboardingFlow.swift`

- [ ] **Step 1: Add shared `@State` properties on `OnboardingFlow`.**

  Open `SonicMerge/Features/Onboarding/OnboardingFlow.swift`. Find the existing `@State private var step: Step = .brand` declaration on `OnboardingFlow` and immediately below it, add:

  ```swift
  // Carried into step 5 — populated by step 4's analyze + apply.
  @State private var speechGranted: Bool = false
  @State private var sampleEditList: EditList?
  @State private var sampleCleanedURL: URL?
  @State private var sampleOriginalURL: URL? = Bundle.main.url(forResource: "onboarding-sample", withExtension: "m4a")
  // Re-entry guard: SwiftUI may re-fire `.task` on view re-render
  // (e.g. scenePhase change while the OS permission dialog is up).
  // SFSpeechRecognizer.requestAuthorization is idempotent post-decision,
  // but `advance(to: .sample)` is not — guard against double-advance.
  @State private var permissionRequested: Bool = false
  ```

  Also add the FillerLibrary environment read just below the existing `@Environment(\.sonicMergeSemantic)`:

  ```swift
  @Environment(\.fillerLibrary) private var libraryStore
  ```

- [ ] **Step 2: Add a permission helper static method.**

  At the end of `struct OnboardingFlow` (just before its closing `}`), add:

  ```swift
  private static func requestSpeechAuthorization() async -> Bool {
      await withCheckedContinuation { continuation in
          SFSpeechRecognizer.requestAuthorization { status in
              continuation.resume(returning: status == .authorized)
          }
      }
  }
  ```

  Add `import Speech` at the top of the file.

- [ ] **Step 3: Update the step machine to handle `.permission` as a transient async stage.**

  Replace the existing `case .permission, .sample, .result:` arm in the `body` `switch` statement with:

  ```swift
  case .permission:
      ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .task {
              guard !permissionRequested else { return }
              permissionRequested = true
              speechGranted = await Self.requestSpeechAuthorization()
              advance(to: .sample)
          }
  case .sample:
      SampleStep(
          semantic: semantic,
          libraryStore: libraryStore,
          speechGranted: speechGranted,
          sampleURL: sampleOriginalURL,
          onCompleted: { editList, cleanedURL in
              sampleEditList = editList
              sampleCleanedURL = cleanedURL
              advance(to: .result)
          },
          onSkipToHome: { hasOnboarded = true }
      )
  case .result:
      // TODO Chunk 5
      VStack {
          Text("Step 5 — not yet implemented")
          Button("Done · Open Smart Cut") { hasOnboarded = true }
              .buttonStyle(.borderedProminent)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  ```

  `SampleStep` is referenced but not yet defined — Task 4.2 adds it.

### Task 4.2: Add the sample step view (granted + denied paths)

**Files:**
- Modify: `SonicMerge/Features/Onboarding/OnboardingFlow.swift`

- [ ] **Step 1: Append the sample step view to the file.**

  First, ensure the imports at the top of `OnboardingFlow.swift` include `import UIKit` — needed for `UIApplication.openSettingsURLString` in the denied-path footer. SwiftUI does not transitively re-export it. The file already has `import SwiftUI` and `import Speech` from prior chunks; add `import UIKit` if missing.

  Then append at the end of the file:

  ```swift
  // MARK: - Step 4: Hands-on first cut

  private struct SampleStep: View {
      enum Phase { case ready, analyzing, cutting, error(String) }

      let semantic: SonicMergeSemantic
      let libraryStore: FillerLibraryStore
      let speechGranted: Bool
      let sampleURL: URL?
      let onCompleted: (EditList, URL) -> Void
      let onSkipToHome: () -> Void

      @State private var phase: Phase = .ready
      @State private var attemptCount: Int = 0

      var body: some View {
          VStack(spacing: 0) {
              Spacer().frame(height: 32)

              VStack(alignment: .leading, spacing: 6) {
                  Text(speechGranted ? "Try it on a sample" : "Sample loaded")
                      .font(.system(.title2, design: .rounded, weight: .bold))
                      .foregroundStyle(Color(uiColor: semantic.textPrimary))
                  Text(speechGranted
                       ? "A 30-second podcast clip is loaded for you."
                       : "Smart Cut needs Speech Recognition access. Enable it in Settings → CleanCut.")
                      .font(.subheadline)
                      .foregroundStyle(Color(uiColor: semantic.textSecondary))
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.top, 12)
              .padding(.bottom, 16)

              SampleCard(semantic: semantic, phase: phase)

              if speechGranted {
                  TipKitHint(
                      text: "💡 Tap Smart Cut to remove every \"um\" and long pause from this clip.",
                      semantic: semantic
                  )
                  .padding(.top, 12)
              }

              Spacer()

              if speechGranted {
                  grantedFooter
              } else {
                  deniedFooter
              }
          }
          .accessibilityElement(children: .contain)
          .accessibilityLabel("Step 4 of 5: \(speechGranted ? "Try Smart Cut on a sample audio clip" : "Sample loaded — Speech Recognition required to analyze")")
      }

      // MARK: - Granted path

      @ViewBuilder
      private var grantedFooter: some View {
          switch phase {
          case .ready:
              Button { Task { await runAnalyze() } } label: {
                  Label("Smart Cut This Sample", systemImage: "sparkles")
                      .font(.system(.body, design: .rounded, weight: .semibold))
                      .foregroundStyle(.white)
                      .frame(maxWidth: .infinity)
                      .padding(.vertical, 14)
                      .background(Capsule().fill(Color(uiColor: semantic.accentAI)))
              }
              .accessibilityHint("Removes filler words and long pauses from the bundled audio sample.")
          case .analyzing:
              ProgressView("Analyzing…").tint(Color(uiColor: semantic.accentAI))
                  .padding(.vertical, 14)
          case .cutting:
              ProgressView("Applying cuts…").tint(Color(uiColor: semantic.accentAI))
                  .padding(.vertical, 14)
          case .error(let message):
              VStack(spacing: 8) {
                  Text(message)
                      .font(.caption)
                      .foregroundStyle(Color(uiColor: semantic.textSecondary))
                      .multilineTextAlignment(.center)
                  HStack {
                      Button("Try again") { Task { await runAnalyze() } }
                          .buttonStyle(.bordered)
                      Button("Skip to home") { onSkipToHome() }
                          .buttonStyle(.borderless)
                  }
              }
          }
      }

      // MARK: - Denied path

      private var deniedFooter: some View {
          VStack(spacing: 12) {
              Button {
                  if let url = URL(string: UIApplication.openSettingsURLString) {
                      UIApplication.shared.open(url)
                  }
              } label: {
                  Text("Open Settings")
                      .font(.system(.body, design: .rounded, weight: .semibold))
                      .foregroundStyle(Color(uiColor: semantic.accentAction))
                      .frame(maxWidth: .infinity)
                      .padding(.vertical, 14)
                      .overlay(
                          Capsule().strokeBorder(Color(uiColor: semantic.accentAction), lineWidth: 1.5)
                      )
              }
              Button("Skip to home", action: onSkipToHome)
                  .font(.subheadline)
                  .foregroundStyle(Color(uiColor: semantic.textSecondary))
          }
      }

      // MARK: - Pipeline

      private func runAnalyze() async {
          guard let url = sampleURL else {
              phase = .error("Couldn't find the sample. Tap Skip to continue.")
              return
          }
          attemptCount += 1
          phase = .analyzing
          let service = SmartCutService(library: libraryStore.library)
          do {
              var resolvedEditList: EditList?
              for try await update in service.analyze(input: url) {
                  if case .completed(let list, _, _) = update {
                      resolvedEditList = list
                  }
              }
              guard let editList = resolvedEditList else {
                  bumpError("Couldn't analyze the sample. Tap to try again or skip.")
                  return
              }
              phase = .cutting
              let cleanedURL = try await AudioCutter().apply(input: url, editList: editList)
              onCompleted(editList, cleanedURL)
          } catch {
              bumpError("Couldn't analyze the sample. Tap to try again or skip.")
          }
      }

      private func bumpError(_ message: String) {
          if attemptCount >= 2 {
              // Spec §5 step 4: after 2 retries, force-skip to avoid a trapped user.
              onSkipToHome()
          } else {
              phase = .error(message)
          }
      }
  }

  // MARK: - Sample card

  private struct SampleCard: View {
      let semantic: SonicMergeSemantic
      let phase: SampleStep.Phase

      var body: some View {
          VStack(alignment: .leading, spacing: 6) {
              Text("SAMPLE AUDIO")
                  .font(.caption.weight(.bold))
                  .tracking(0.5)
                  .foregroundStyle(Color(uiColor: semantic.textSecondary))
              Text("podcast-snippet.m4a")
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(Color(uiColor: semantic.textPrimary))
              RoundedRectangle(cornerRadius: 4, style: .continuous)
                  .fill(LinearGradient(
                      colors: [
                          Color(uiColor: semantic.accentAction),
                          Color(uiColor: semantic.accentAI)
                      ],
                      startPoint: .leading,
                      endPoint: .trailing
                  ))
                  .frame(height: 24)
                  .opacity(phase.busy ? 0.6 : 0.4)
              Text("0:00 — 0:32")
                  .font(.caption)
                  .foregroundStyle(Color(uiColor: semantic.textSecondary))
          }
          .padding(12)
          .background(
              RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .fill(Color(uiColor: semantic.surfaceCard))
                  .overlay(
                      RoundedRectangle(cornerRadius: 14, style: .continuous)
                          .strokeBorder(Color(uiColor: .systemGray5), lineWidth: 0.5)
                  )
          )
      }
  }

  private extension SampleStep.Phase {
      var busy: Bool {
          if case .analyzing = self { return true }
          if case .cutting = self { return true }
          return false
      }
  }

  // MARK: - TipKit-style decorative hint

  private struct TipKitHint: View {
      let text: String
      let semantic: SonicMergeSemantic

      var body: some View {
          Text(text)
              .font(.caption)
              .foregroundStyle(Color(uiColor: semantic.textPrimary))
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 12)
              .padding(.vertical, 10)
              .background(Color(uiColor: semantic.accentAction).opacity(0.08))
              .overlay(
                  Rectangle()
                      .fill(Color(uiColor: semantic.accentAction))
                      .frame(width: 3),
                  alignment: .leading
              )
              .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      }
  }
  ```

- [ ] **Step 2: Build.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`.

### Task 4.3: End-of-chunk verification + commit

- [ ] **Step 1: Full test suite.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/ob-chunk4.log | tail -3
  echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/ob-chunk4.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
  ```
  Expected: `FAIL=5`.

- [ ] **Step 2: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Features/Onboarding/OnboardingFlow.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(onboarding): permission step + hands-on Smart Cut on bundled sample"
  ```

---

## Chunk 5: Step 5 — Result + soft Denoise reveal + Done

Step 5 displays the analyze result (filler count + savings pill) with an A/B Original/Cleaned playback toggle wired to two `AVAudioPlayer` instances and a decorative Denoise TipKit. Tapping Done sets `hasOnboarded = true` and fires a `.success` haptic.

**Spec references:** §5 step 5 (granted + denied paths), §10 accessibility.

### Task 5.1: Add the result step view

**Files:**
- Modify: `SonicMerge/Features/Onboarding/OnboardingFlow.swift`

- [ ] **Step 1: Replace the placeholder `.result` arm in the `body` switch with a real ResultStep.**

  Find the placeholder arm:

  ```swift
  case .result:
      // TODO Chunk 5
      VStack {
          Text("Step 5 — not yet implemented")
          Button("Done · Open Smart Cut") { hasOnboarded = true }
              .buttonStyle(.borderedProminent)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  ```

  Replace with:

  ```swift
  case .result:
      ResultStep(
          semantic: semantic,
          editList: sampleEditList,
          originalURL: sampleOriginalURL,
          cleanedURL: sampleCleanedURL,
          onDone: {
              hasOnboarded = true
              UINotificationFeedbackGenerator().notificationOccurred(.success)
          }
      )
  ```

- [ ] **Step 2: Append the ResultStep view to the bottom of the file.**

  At the end of `OnboardingFlow.swift`, append:

  ```swift
  // MARK: - Step 5: Result + soft Denoise reveal

  private struct ResultStep: View {
      let semantic: SonicMergeSemantic
      let editList: EditList?
      let originalURL: URL?
      let cleanedURL: URL?
      let onDone: () -> Void

      enum Track { case original, cleaned }

      @State private var selectedTrack: Track = .cleaned
      @State private var originalPlayer: AVAudioPlayer?
      @State private var cleanedPlayer: AVAudioPlayer?

      var body: some View {
          VStack(spacing: 0) {
              Spacer().frame(height: 32)

              VStack(alignment: .leading, spacing: 6) {
                  Text(headline)
                      .font(.system(.title2, design: .rounded, weight: .bold))
                      .foregroundStyle(Color(uiColor: semantic.textPrimary))
                  if hasResult {
                      Text("Tap Cleaned or Original to compare.")
                          .font(.subheadline)
                          .foregroundStyle(Color(uiColor: semantic.textSecondary))
                  } else {
                      Text("Open the Smart Cut tab anytime to start.")
                          .font(.subheadline)
                          .foregroundStyle(Color(uiColor: semantic.textSecondary))
                  }
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.top, 12)
              .padding(.bottom, 16)

              if hasResult, let editList {
                  ResultCard(semantic: semantic, editList: editList)
                      .padding(.bottom, 12)

                  ABToggle(semantic: semantic,
                           selected: $selectedTrack,
                           onChange: handleTrackChange)
                      .padding(.bottom, 12)

                  TipKitHint(
                      text: "💡 Try Denoise on this clip — the AI orb removes background hiss.",
                      semantic: semantic
                  )
              }

              Spacer()

              Button(action: {
                  stopAllPlayback()
                  onDone()
              }) {
                  Label("Done · Open Smart Cut", systemImage: "checkmark.circle.fill")
                      .font(.system(.body, design: .rounded, weight: .semibold))
                      .foregroundStyle(.white)
                      .frame(maxWidth: .infinity)
                      .padding(.vertical, 14)
                      .background(Capsule().fill(Color(uiColor: semantic.accentAction)))
              }
          }
          .task { preparePlayers() }
          .onDisappear { stopAllPlayback() }
          .accessibilityElement(children: .contain)
          .accessibilityLabel("Step 5 of 5: \(headline)")
      }

      private var hasResult: Bool { editList != nil && cleanedURL != nil }

      private var headline: String {
          guard let editList else { return "You're all set" }
          let n = editList.fillers.filter(\.isEnabled).count
          return n > 0 ? "\(n) fillers found" : "Smart Cut applied"
      }

      private func preparePlayers() {
          // Activate the shared audio session before the first AVAudioPlayer
          // call. Without this, prepareToPlay() succeeds silently but play()
          // produces no audible output on real devices.
          PlaybackAudioSession.activateIfNeeded()
          if let url = originalURL {
              originalPlayer = try? AVAudioPlayer(contentsOf: url)
              originalPlayer?.prepareToPlay()
          }
          if let url = cleanedURL {
              cleanedPlayer = try? AVAudioPlayer(contentsOf: url)
              cleanedPlayer?.prepareToPlay()
          }
      }

      private func handleTrackChange(_ track: Track) {
          switch track {
          case .original:
              cleanedPlayer?.pause()
              originalPlayer?.currentTime = 0
              originalPlayer?.play()
          case .cleaned:
              originalPlayer?.pause()
              cleanedPlayer?.currentTime = 0
              cleanedPlayer?.play()
          }
      }

      private func stopAllPlayback() {
          originalPlayer?.stop()
          cleanedPlayer?.stop()
      }
  }

  // MARK: - Result card

  private struct ResultCard: View {
      let semantic: SonicMergeSemantic
      let editList: EditList

      var body: some View {
          VStack(alignment: .leading, spacing: 6) {
              Text("SMART CUT SUMMARY")
                  .font(.caption.weight(.bold))
                  .tracking(0.5)
                  .foregroundStyle(Color(uiColor: semantic.accentAction))
              Text("podcast-snippet.m4a")
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(Color(uiColor: semantic.textPrimary))
              HStack(spacing: 8) {
                  if !editList.fillers.isEmpty {
                      Text("\(editList.fillers.count) fillers")
                          .font(.caption.weight(.semibold))
                          .padding(.horizontal, 10).padding(.vertical, 4)
                          .background(Capsule().fill(Color(uiColor: semantic.accentAction).opacity(0.14)))
                          .foregroundStyle(Color(uiColor: semantic.accentAction))
                  }
                  if !editList.pauses.isEmpty {
                      Text("\(editList.pauses.count) pauses")
                          .font(.caption.weight(.semibold))
                          .padding(.horizontal, 10).padding(.vertical, 4)
                          .background(Capsule().fill(Color(uiColor: semantic.accentAction).opacity(0.14)))
                          .foregroundStyle(Color(uiColor: semantic.accentAction))
                  }
                  Spacer()
                  Text("saves ~\(Int(editList.enabledSavings.rounded()))s")
                      .font(.subheadline.weight(.bold))
                      .padding(.horizontal, 12).padding(.vertical, 5)
                      .background(Capsule().fill(Color(uiColor: semantic.accentAI)))
                      .foregroundStyle(.white)
              }
              .padding(.top, 4)
          }
          .padding(12)
          .background(
              RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .fill(Color(uiColor: semantic.surfaceCard))
                  .overlay(
                      RoundedRectangle(cornerRadius: 14, style: .continuous)
                          .strokeBorder(Color(uiColor: .systemGray5), lineWidth: 0.5)
                  )
          )
      }
  }

  // MARK: - A/B toggle

  private struct ABToggle: View {
      let semantic: SonicMergeSemantic
      @Binding var selected: ResultStep.Track
      let onChange: (ResultStep.Track) -> Void

      var body: some View {
          HStack(spacing: 8) {
              segment(track: .original, label: "Original")
              segment(track: .cleaned, label: "Cleaned")
          }
      }

      @ViewBuilder
      private func segment(track: ResultStep.Track, label: String) -> some View {
          let isSelected = selected == track
          Button {
              selected = track
              onChange(track)
          } label: {
              Text(label)
                  .font(.system(.body, design: .rounded, weight: .semibold))
                  .foregroundStyle(isSelected ? .white : Color(uiColor: semantic.textPrimary))
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 10)
                  .background(
                      Capsule().fill(isSelected
                                     ? Color(uiColor: semantic.accentAction)
                                     : Color(uiColor: semantic.surfaceCard))
                  )
                  .overlay(
                      Capsule().strokeBorder(
                          isSelected ? Color.clear : Color(uiColor: .systemGray5),
                          lineWidth: 1
                      )
                  )
          }
          .accessibilityAddTraits(isSelected ? [.isSelected] : [])
          .accessibilityLabel("\(label) audio\(isSelected ? ", selected" : "")")
      }
  }
  ```

  Add `import AVFoundation` at the top of the file.

- [ ] **Step 2: Build.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`.

### Task 5.2: End-of-chunk verification + commit

- [ ] **Step 1: Full test suite.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/ob-chunk5.log | tail -3
  echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/ob-chunk5.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
  ```
  Expected: `FAIL=5`.

- [ ] **Step 2: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Features/Onboarding/OnboardingFlow.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(onboarding): result step + A/B player + soft Denoise reveal + Done"
  ```

---

## Chunk 6: Final verification + manual QA

### Task 6.1: Final test suite + clean tree

- [ ] **Step 1: Run final suite.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/ob-final.log | tail -3
  echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/ob-final.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
  ```
  Expected: `FAIL=5` matching baseline names. The 2 new `OnboardingGateTests` are PASS.

- [ ] **Step 2: Verify tree is clean.**

  Run: `git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge status`
  Expected: only the standing `.xcuserstate` modification.

### Task 6.2: Manual QA on simulator (spec §11.3)

Run the app on the iPhone 17 simulator. Confirm each of the 9 items:

- [ ] **1. First install (allow path):** wipe simulator → cold launch → all 5 steps render → tap "Smart Cut This Sample" on step 4 → savings pill appears on step 5 with N≥2 fillers and savings≥8s → A/B toggle plays both versions → Done dismisses cover → app lands on Smart Cut tab.

- [ ] **2. First install (deny path):** wipe simulator → cold launch → step 1 → 2 → step 3 dialog "Don't Allow" → step 4 shows "Sample loaded / Settings or Skip" copy → tap Skip → step 5 shows "You're all set" → Done dismisses.

- [ ] **3. Skip on step 1:** tap Skip → advance to step 2 (NOT home) → flow continues normally.

- [ ] **4. Already-onboarded:** Settings → CleanCut → toggle a UserDefaults editor or use `xcrun simctl spawn booted defaults write com.dtech.SonicMerge sonicMerge.hasOnboarded -bool YES` → cold launch → tabs render directly, no cover shown.

- [ ] **5. Reinstall:** delete app from sim → reinstall → onboarding re-appears.

- [ ] **6. Reduce Motion ON:** Settings → Accessibility → Motion → Reduce Motion → cold launch → step transitions are instant (no slide animation), bounce animations replaced with opacity fades; nothing breaks.

- [ ] **7. Reduce Transparency ON:** trust primer step renders with solid card background instead of glass.

- [ ] **8. Dynamic Type XXL:** Settings → Accessibility → Display & Text Size → Larger Text → set to max → cold launch → onboarding layout doesn't truncate or clip off-screen.

- [ ] **9. VoiceOver:** Triple-press home → enable VoiceOver → cold launch → all 5 steps announce step number + title; CTAs announce purpose; A/B toggle announces selection state ("Cleaned audio, selected").

If any QA item fails: fix with a small commit on the branch and re-run that item before proceeding.

### Task 6.3: Hand off to finishing-a-development-branch

- [ ] **Step 1: Use the `superpowers:finishing-a-development-branch` skill to merge or PR this work.**

  Announce: "I'm using the finishing-a-development-branch skill to complete this work."
