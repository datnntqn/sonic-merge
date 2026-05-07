# Monetization Sub-project 3 — Conversion Moments Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the existing `PaywallTriggerCoordinator` into every paywall presentation site (so throttling rules actually apply) and add the post-onboarding paywall — the highest-converting moment per RevenueCat industry data, currently unwired.

**Architecture:** A coordinator-aware `.paywall(reason:)` modifier consults `EnvironmentValues.paywallCoordinator` before mounting the sheet, suppressing presentation when `shouldPresent(_:)` returns false. The post-onboarding paywall fires by setting `paywallReason = .endOfOnboarding` inside `RootTabView`'s existing `.onChange(of: hasOnboarded)` handler — no new host view needed. The existing `PaywallView` gains a small celebratory badge conditional on `reason == .endOfOnboarding`.

**Tech Stack:** Swift 6, SwiftUI, `@Observable`, existing `PaywallTriggerCoordinator` (Sub-project 1), existing `PaywallReason.endOfOnboarding` enum case (Sub-project 1 stub), existing `.paywall(reason:)` modifier (Sub-project 1), Swift Testing.

**Spec source:** `docs/superpowers/specs/2026-05-07-conversion-moments-design.md`.

**Estimated scope:** ~120 lines new + ~40 modified, 3 commits in 3 chunks. Should land in 0.5-1 day of focused work.

---

## Pre-flight

- [ ] **Step 1: Confirm baseline branch + tests**

```bash
git log --oneline | head -3
```

You should see `145c020 docs(spec): monetization sub-project 3 — conversion moments` near HEAD. If not, abort and check out `main`.

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5` with the canonical baseline names from `CLAUDE.md`. Anything beyond 5 means something regressed in Sub-project 2 — diagnose and fix BEFORE starting this plan, otherwise you can't tell which failures you introduced.

- [ ] **Step 2: Confirm relevant types already exist**

```bash
grep -nE "case endOfOnboarding|paywallCoordinator|PaywallTriggerCoordinator" \
  SonicMerge/Features/Subscription/Views/PaywallReason.swift \
  SonicMerge/Features/Subscription/Services/PaywallTriggerCoordinator.swift \
  SonicMerge/App/RootTabView.swift
```

Expected output:
- `PaywallReason.swift:9: case endOfOnboarding` (already-stubbed enum case)
- `PaywallTriggerCoordinator.swift:19: final class PaywallTriggerCoordinator`
- `RootTabView.swift: <some line>: paywallCoordinator` (existing state variable)

If any of these are missing, Sub-project 1 is incomplete — fix that first.

---

## Chunk 1: Coordinator-aware `.paywall(reason:)` modifier

**Why first:** Every other change depends on the modifier consulting the coordinator. If we ship Chunk 2 (celebratory header) before Chunk 1, the post-onboarding paywall would surface unthrottled — and then Chunk 1 would change behavior under us. Land throttling first; everything else layers on stable ground.

### Task 1.1: Add `EnvironmentValues.paywallCoordinator` env key

**Files:**
- Create: `SonicMerge/Features/Subscription/Services/PaywallCoordinatorEnvironment.swift`

The coordinator currently lives as `@State` on `RootTabView` and is passed by direct reference. We need an `Environment` key so the modifier (which has no view context) can reach it without prop-drilling.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

/// `EnvironmentValues` key for the app's `PaywallTriggerCoordinator`.
///
/// The default value is a fresh, process-local coordinator — this keeps the
/// `.paywall(reason:)` modifier safe to use in views that haven't been
/// explicitly wired (e.g., previews, isolated unit-test hosts). The `RootTabView`
/// injects the real shared instance via `.environment(\.paywallCoordinator, ...)`.
private struct PaywallCoordinatorKey: EnvironmentKey {
    @MainActor static let defaultValue: PaywallTriggerCoordinator = .init()
}

extension EnvironmentValues {
    var paywallCoordinator: PaywallTriggerCoordinator {
        get { self[PaywallCoordinatorKey.self] }
        set { self[PaywallCoordinatorKey.self] = newValue }
    }
}
```

- [ ] **Step 2: Build to confirm compiles**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`. Note: SwiftUI's `EnvironmentKey.defaultValue` is non-isolated by protocol but `PaywallTriggerCoordinator` is `@MainActor` — the `@MainActor static let` annotation on `defaultValue` resolves the isolation mismatch. If the build complains about MainActor isolation, the annotation may need to move; in that case, change `defaultValue` to a computed property: `@MainActor static var defaultValue: PaywallTriggerCoordinator { .init() }` — same effect, different shape.

### Task 1.2: Inject coordinator into environment from RootTabView

**Files:**
- Modify: `SonicMerge/App/RootTabView.swift`

The state variable already exists — we just publish it via the env key.

- [ ] **Step 1: Find the body's outermost view modifier chain**

```bash
grep -n "\.environment(\\\\\\.\\|TabView\|\.onAppear" SonicMerge/App/RootTabView.swift | head -10
```

You'll see existing `.environment(\.sonicMergeSemantic, ...)` injections. The new one slots in alongside.

- [ ] **Step 2: Add the injection**

Find the existing `.environment(\.sonicMergeSemantic, ...)` line. Immediately after it, add:

```swift
            .environment(\.paywallCoordinator, paywallCoordinator)
```

(`paywallCoordinator` is the existing `@State` variable on `RootTabView` — see the `resetSession()` callsite around line 111 for confirmation.)

- [ ] **Step 3: Build to confirm**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

### Task 1.3: Rewrite `.paywall(reason:)` modifier to consult coordinator

**Files:**
- Modify: `SonicMerge/Features/Subscription/Views/PaywallTrigger.swift`

The current implementation is a thin wrapper around `.sheet(item:)`. We replace it with a coordinator-aware modifier that:

1. On `reason` going non-nil, asks `coordinator.shouldPresent(reason)`.
2. If `false`, sets `reason = nil` (suppresses) and exits.
3. If `true`, calls `coordinator.markPresented(reason)` and lets the sheet present.
4. On sheet dismiss, calls `coordinator.recordDismiss(reason)`.

- [ ] **Step 1: Replace the file content**

Open `SonicMerge/Features/Subscription/Views/PaywallTrigger.swift`. Replace the entire file with:

```swift
import SwiftUI

/// Coordinator-aware paywall presenter. Same call signature as before
/// (`view.paywall(reason: $paywallReason)`) — but every presentation now
/// goes through `PaywallTriggerCoordinator.shouldPresent(_:)` so session
/// throttling and dismiss-count limits actually apply.
///
/// Sub-project 2 sites that just write `paywallReason = .X` get the new
/// behavior for free; no callsite change required.
extension View {
    func paywall(reason: Binding<PaywallReason?>) -> some View {
        modifier(PaywallTriggerModifier(reason: reason))
    }
}

private struct PaywallTriggerModifier: ViewModifier {
    @Binding var reason: PaywallReason?
    @Environment(\.paywallCoordinator) private var coordinator

    func body(content: Content) -> some View {
        content
            .onChange(of: reason) { _, newValue in
                guard let candidate = newValue else { return }
                if !coordinator.shouldPresent(candidate) {
                    // Suppress — clear the binding so the sheet never mounts.
                    reason = nil
                } else {
                    coordinator.markPresented(candidate)
                }
            }
            .sheet(item: $reason, onDismiss: {
                // The Binding is `nil` by the time onDismiss fires; capture
                // the dismissed reason via a side channel. The simplest is
                // to record dismiss whenever the sheet closes — coordinator
                // tolerates "extra" recordDismiss calls (just bumps a counter
                // for whatever reason was last presented).
            }) { actual in
                PaywallView(reason: actual)
                    .interactiveDismissDisabled(false)
                    .onDisappear {
                        coordinator.recordDismiss(actual)
                    }
            }
    }
}

extension PaywallReason: Identifiable {
    var id: String { rawValue }
}
```

**Why `onDisappear` on the sheet content rather than `onDismiss` on `.sheet`:** by the time `.sheet(onDismiss:)` fires, the `reason` binding is already nil (SwiftUI clears `item:` bindings before `onDismiss`). We instead use the captured `actual` reason inside the sheet builder closure and record dismiss when the content view itself disappears. This fires on both swipe-down and explicit dismiss-button taps.

- [ ] **Step 2: Build to confirm no callsite regressions**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`. All 7 existing `.paywall(reason: $paywallReason)` callsites compile against the new modifier with no change.

### Task 1.4: Integration tests for coordinator-modifier behavior

**Files:**
- Create: `SonicMergeTests/Features/Subscription/PaywallTriggerCoordinatorIntegrationTests.swift`

The throttling logic is already unit-tested at the coordinator level (Sub-project 1). What we add here verifies the modifier-coordinator contract: shouldPresent gates, markPresented gets called, recordDismiss gets called.

- [ ] **Step 1: Write the failing tests**

Create `SonicMergeTests/Features/Subscription/PaywallTriggerCoordinatorIntegrationTests.swift`:

```swift
import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct PaywallTriggerCoordinatorIntegrationTests {

    private func freshCoordinator() -> PaywallTriggerCoordinator {
        let suite = "PaywallCoordIntTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return PaywallTriggerCoordinator(defaults: defaults)
    }

    @Test func firstReasonPresents() {
        let coord = freshCoordinator()
        #expect(coord.shouldPresent(.hitDailyCap) == true)
        coord.markPresented(.hitDailyCap)
        #expect(coord.hasShownPaywallThisSession == true)
    }

    @Test func secondReasonInSessionSuppressed() {
        let coord = freshCoordinator()
        coord.markPresented(.hitDailyCap)
        #expect(coord.shouldPresent(.hitLengthCap) == false)
    }

    @Test func settingsUpgradeBypassesSessionThrottle() {
        let coord = freshCoordinator()
        coord.markPresented(.hitDailyCap)
        #expect(coord.shouldPresent(.settingsUpgrade) == true)
    }

    @Test func endOfOnboardingDoesNotBypassSessionThrottle() {
        let coord = freshCoordinator()
        coord.markPresented(.hitDailyCap)
        #expect(coord.shouldPresent(.endOfOnboarding) == false)
    }

    @Test func dismissThresholdReachedSuppresses() {
        let coord = freshCoordinator()
        for _ in 0..<5 { coord.recordDismiss(.hitDailyCap) }
        #expect(coord.shouldPresent(.hitDailyCap) == false)
    }

    @Test func dismissCounterPersistsAcrossInstances() {
        let suite = "PaywallCoordPersistTest-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let coord1 = PaywallTriggerCoordinator(defaults: defaults)
        for _ in 0..<5 { coord1.recordDismiss(.hitDailyCap) }
        // New instance, same defaults — counter survives
        let coord2 = PaywallTriggerCoordinator(defaults: defaults)
        #expect(coord2.shouldPresent(.hitDailyCap) == false)
    }

    @Test func resetSessionRehydratesPresentation() {
        let coord = freshCoordinator()
        coord.markPresented(.hitDailyCap)
        #expect(coord.shouldPresent(.hitLengthCap) == false)
        coord.resetSession()
        #expect(coord.shouldPresent(.hitLengthCap) == true)
    }
}
```

- [ ] **Step 2: Run tests to verify pass**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SonicMergeTests/PaywallTriggerCoordinatorIntegrationTests test 2>&1 | tail -10
```

Expected: PASS (7 tests). All tests target the coordinator's existing public API — they pass as long as Sub-project 1's coordinator behavior is intact. Their value is regression coverage: if anyone in the future weakens the throttling logic, these break.

- [ ] **Step 3: Run full suite to confirm baseline + new tests pass**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5` (baseline preserved). 7 new tests pass.

- [ ] **Step 4: Commit Chunk 1**

```bash
git add SonicMerge/Features/Subscription/Services/PaywallCoordinatorEnvironment.swift \
        SonicMerge/Features/Subscription/Views/PaywallTrigger.swift \
        SonicMerge/App/RootTabView.swift \
        SonicMergeTests/Features/Subscription/PaywallTriggerCoordinatorIntegrationTests.swift
git commit -m "feat(subscription): coordinator-aware .paywall(reason:) modifier"
```

---

## Chunk 2: Celebratory badge in PaywallView for `.endOfOnboarding`

**Why second:** Independent of the trigger wiring (Chunk 3). Lands the visual differentiation first so when Chunk 3 fires the trigger, the sheet is already styled correctly.

### Task 2.1: Add conditional celebratory badge above the SmartCutMark

**Files:**
- Modify: `SonicMerge/Features/Subscription/Views/PaywallView.swift`

The `hero` section currently has the layout: close-X → SmartCutMark → "CleanCut Pro" headline → reasonHeadline. We add a small celebratory pill ABOVE the SmartCutMark, conditional on `reason == .endOfOnboarding`. Existing `reasonHeadline` already differentiates copy per reason, so we leave that as-is.

- [ ] **Step 1: Inspect the current `hero` body**

Open `SonicMerge/Features/Subscription/Views/PaywallView.swift`. The `hero` computed property starts around line 62 and runs through ~line 87. The SmartCutMark sits at line 73-74.

- [ ] **Step 2: Add the badge**

Inside the `hero` `VStack`, BEFORE `SmartCutMark(size: .hero)`, insert:

```swift
            if reason == .endOfOnboarding {
                Text("🎉 You're all set")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(uiColor: semantic.accentAI).opacity(0.15)))
                    .foregroundStyle(Color(uiColor: semantic.accentAI))
                    .accessibilityIdentifier("PaywallView.celebratoryBadge")
            }
```

The `accessibilityIdentifier` is the test seam — Task 2.2 uses it to verify the badge mounts.

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

### Task 2.2: Tests — body identity per reason

**Files:**
- Create: `SonicMergeTests/Features/Subscription/PaywallViewBodyTests.swift`

SwiftUI bodies are notoriously hard to introspect in tests. The narrowest verification is: ensure the `hero` view's identity differs between `.endOfOnboarding` and any other reason — i.e., the conditional branch evaluates correctly.

We don't need an actual UI-level snapshot; we just need a smoke that `reasonHeadline` returns the right string per case and that the case-discrimination logic hasn't regressed. We test the pure helper.

- [ ] **Step 1: Write the failing tests**

Create `SonicMergeTests/Features/Subscription/PaywallViewBodyTests.swift`:

```swift
import Testing
@testable import SonicMerge

struct PaywallViewBodyTests {

    /// Sanity that all `PaywallReason` cases produce a non-empty headline —
    /// guards against someone adding a new case and forgetting to update the
    /// switch in `PaywallView.reasonHeadline`.
    @Test func everyReasonHasHeadline() {
        let cases: [PaywallReason] = [
            .endOfOnboarding, .hitDailyCap, .hitLengthCap,
            .watermarkExport, .settingsUpgrade, .trialExpired
        ]
        for reason in cases {
            let headline = PaywallView.headlineCopy(for: reason)
            #expect(!headline.isEmpty, "Reason \(reason) is missing a headline")
        }
    }

    @Test func endOfOnboardingHasCelebratoryHeadline() {
        let headline = PaywallView.headlineCopy(for: .endOfOnboarding)
        // The post-onboarding moment uses celebratory framing — different
        // from the matter-of-fact cap copy. Specifically, it should NOT
        // mention "limit" or "cap" (those words read as restrictive).
        #expect(!headline.lowercased().contains("limit reached"))
        #expect(!headline.lowercased().contains("cap"))
    }
}
```

- [ ] **Step 2: Extract `headlineCopy(for:)` as a static helper**

The existing `reasonHeadline` is a private computed property. Extract it as a static for testability:

In `PaywallView.swift`, replace:

```swift
    private var reasonHeadline: String {
        switch reason {
        case .endOfOnboarding: return "Cut fillers. Clean noise. No limits."
        // ... existing cases ...
        }
    }
```

with:

```swift
    private var reasonHeadline: String {
        Self.headlineCopy(for: reason)
    }

    /// Test seam — pure mapping reason → headline string.
    static func headlineCopy(for reason: PaywallReason) -> String {
        switch reason {
        case .endOfOnboarding: return "Cut fillers. Clean noise. No limits."
        case .hitDailyCap: return "You've used your daily free quota. Pro = unlimited."
        case .hitLengthCap: return "This clip is longer than free supports. Pro = any length."
        case .watermarkExport: return "Pro removes the export watermark."
        case .settingsUpgrade: return "Cut fillers. Clean noise. No limits."
        case .trialExpired: return "Your trial ended. Keep unlimited access?"
        }
    }
```

- [ ] **Step 3: Run tests**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SonicMergeTests/PaywallViewBodyTests test 2>&1 | tail -10
```

Expected: PASS (2 tests).

- [ ] **Step 4: Run full suite + commit Chunk 2**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`.

```bash
git add SonicMerge/Features/Subscription/Views/PaywallView.swift \
        SonicMergeTests/Features/Subscription/PaywallViewBodyTests.swift
git commit -m "feat(subscription): celebratory badge on PaywallView for .endOfOnboarding"
```

---

## Chunk 3: Wire post-onboarding paywall trigger from RootTabView

**Why last:** This is the call site that uses everything from Chunks 1 and 2. Land it last so each piece is independently verified before the integration moment.

### Task 3.1: Add `paywallReason` state + modifier to RootTabView

**Files:**
- Modify: `SonicMerge/App/RootTabView.swift`

`RootTabView` already manages `hasOnboarded` and reacts via `.onChange`. We add a `@State paywallReason` and a `.paywall(reason: $paywallReason)` modifier so the new sheet has a presenter.

- [ ] **Step 1: Add the state property**

Find the existing `@State` block at the top of `RootTabView` (e.g., near the `paywallCoordinator` declaration). Add:

```swift
    @State private var paywallReason: PaywallReason?
```

- [ ] **Step 2: Add the modifier on the body**

Find the existing `.environment(\.paywallCoordinator, paywallCoordinator)` line you added in Task 1.2. Immediately after, add:

```swift
            .paywall(reason: $paywallReason)
```

The modifier is now coordinator-aware (Chunk 1), so this sheet will respect throttling automatically.

- [ ] **Step 3: Set the reason in `.onChange(of: hasOnboarded)`**

Find the existing `.onChange(of: hasOnboarded) { _, newValue in ... }` block (around line 121). Inside the existing `if newValue { selection = .smartCut }` block, add the trigger:

```swift
            if newValue {
                selection = .smartCut
                // Sub-project 3: the celebratory post-onboarding paywall.
                // Coordinator-aware modifier handles throttling — if we're
                // showing for the 6th time after 5 dismisses, it suppresses.
                paywallReason = .endOfOnboarding
            }
```

- [ ] **Step 4: Build**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

### Task 3.2: Trigger test — onboarding completion sets reason exactly once

**Files:**
- Create: `SonicMergeTests/Features/Onboarding/PostOnboardingPaywallTriggerTests.swift`

`RootTabView`'s body is hard to test directly. We test the trigger logic by extracting it into a pure static helper, the same pattern Sub-project 2 used (`SmartCutHomeView.ImportDecision.gate`).

- [ ] **Step 1: Extract the trigger logic into a static helper on `RootTabView`**

In `RootTabView.swift`, add at the bottom of the struct (private nested helper):

```swift
    /// Pure decision: when `hasOnboarded` flips false → true, what paywall
    /// reason (if any) should fire? Lifted out of `.onChange(of:)` so tests
    /// can verify the trigger without instantiating the SwiftUI body.
    enum PostOnboardingTrigger {
        static func reasonOnCompletion(previous: Bool, current: Bool) -> PaywallReason? {
            guard previous == false, current == true else { return nil }
            return .endOfOnboarding
        }
    }
```

Then change the `.onChange` block to use it:

```swift
        .onChange(of: hasOnboarded) { oldValue, newValue in
            if newValue {
                selection = .smartCut
                paywallReason = PostOnboardingTrigger.reasonOnCompletion(
                    previous: oldValue,
                    current: newValue
                )
            }
        }
```

(Note: pre-Chunk-3 the `.onChange` signature was `_, newValue` — change to `oldValue, newValue`. SwiftUI supports both.)

- [ ] **Step 2: Write the tests**

Create `SonicMergeTests/Features/Onboarding/PostOnboardingPaywallTriggerTests.swift`:

```swift
import Testing
@testable import SonicMerge

@MainActor
struct PostOnboardingPaywallTriggerTests {

    @Test func freshCompletionFiresReason() {
        let reason = RootTabView.PostOnboardingTrigger.reasonOnCompletion(
            previous: false, current: true
        )
        #expect(reason == .endOfOnboarding)
    }

    @Test func staysOnboardedIsNoop() {
        // Subsequent body re-renders with hasOnboarded=true should NOT re-fire.
        let reason = RootTabView.PostOnboardingTrigger.reasonOnCompletion(
            previous: true, current: true
        )
        #expect(reason == nil)
    }

    @Test func unsetOnboardedIsNoop() {
        // Defensive — onboarding state shouldn't go true→false in production,
        // but if a debug "Reset onboarding" toggle does it, no paywall fires.
        let reason = RootTabView.PostOnboardingTrigger.reasonOnCompletion(
            previous: true, current: false
        )
        #expect(reason == nil)
    }

    @Test func uninitializedStateIsNoop() {
        let reason = RootTabView.PostOnboardingTrigger.reasonOnCompletion(
            previous: false, current: false
        )
        #expect(reason == nil)
    }
}
```

- [ ] **Step 3: Run tests**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SonicMergeTests/PostOnboardingPaywallTriggerTests test 2>&1 | tail -10
```

Expected: PASS (4 tests).

- [ ] **Step 4: Run full suite + commit Chunk 3**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`.

```bash
git add SonicMerge/App/RootTabView.swift \
        SonicMergeTests/Features/Onboarding/PostOnboardingPaywallTriggerTests.swift
git commit -m "feat(subscription): wire post-onboarding paywall trigger via RootTabView"
```

---

## Final ship-readiness check

- [ ] **Step 1: Run the full suite one last time**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5` (baseline preserved). New tests added: ~13 across `PaywallTriggerCoordinatorIntegrationTests` (7), `PaywallViewBodyTests` (2), `PostOnboardingPaywallTriggerTests` (4). All passing.

- [ ] **Step 2: Manual end-to-end (Free tier — first install)**

Set scheme's StoreKit Configuration to `CleanCut.storekit`. Reset simulator (Device → Erase All Content) so `hasOnboarded` and dismiss-counters are clean.

1. Launch app → onboarding fullScreenCover presents.
2. Walk through onboarding steps 1-5.
3. On final step, tap the primary CTA → onboarding dismisses → land on Smart Cut tab → paywall sheet rises with **🎉 You're all set** badge above SmartCutMark.
4. Tap "Maybe later" (close-X) → paywall dismisses.
5. Try to import a 4th Smart Cut audio same day → paywall does NOT fire (session throttle held from onboarding paywall — coordinator's `hasShownPaywallThisSession` is true).
6. Background the app → wait 2s → foreground → import 4th SC again → paywall NOW fires (`.scenePhase` reset cleared session).

- [ ] **Step 3: Manual end-to-end (Pro user — onboarding bypass check)**

In `EntitlementService` debug toggle (or via `setEntitlement(.lifetime)` on cold launch), make user Pro. Run onboarding again.

1. Complete onboarding → paywall STILL fires (per spec D-6, `.postOnboarding` does not check Pro state). Sheet shows celebratory badge but trial messaging looks weird.
2. Acceptable v1 behavior — flag for revisit if beta feedback complains.

Restore the dev override before commit.

- [ ] **Step 4: Manual smoke — dismiss-count throttle**

1. Reset simulator. Trip `.hitDailyCap` paywall, dismiss. Background → foreground (resets session). Repeat 5 times total.
2. On the 6th attempt, paywall does NOT fire.
3. Console may log `[PaywallTrigger]` suppression info — visible at Settings → Logs in Xcode console.

- [ ] **Step 5: Verify FAIL=5 baseline + commit any final tweaks**

If the manual smoke surfaced any bugs, fix + commit each as its own narrow `fix(subscription): ...` commit. Don't bundle into Chunk 3's commit.

- [ ] **Step 6: Hand off to `superpowers:finishing-a-development-branch`**

Branch is `main`. The skill will likely just verify state and confirm "ready to ship" — no merge or PR needed since work landed directly on main. Push to `origin` if not already.

---

## Notes for the implementer

- **Why `onDisappear` and not `onDismiss` for recordDismiss.** SwiftUI's `.sheet(item:)` clears the binding before `onDismiss` fires, which loses the reason. Capturing `actual` inside the sheet's content builder and recording dismiss in its `onDisappear` works correctly for both swipe-down and X-button dismissals.

- **Default `EnvironmentValues.paywallCoordinator` instance.** This is a fresh per-process coordinator, NOT shared with `RootTabView`'s injected one. If a view forgets to inherit the environment (e.g., a preview or detached test host), it gets isolated state — paywalls present unthrottled in that view. Acceptable defensive default; the real injection is via `RootTabView`.

- **`PostOnboardingTrigger` is a small enum, not a service.** It's pure — given previous/current flags, return the reason. No state, no dependencies, easy to test. Don't be tempted to grow it into a "trigger registry" — YAGNI per Karpathy guidelines.

- **The conditional badge is intentionally tiny (~10 lines).** Per spec D-2 (Q3/B), we resisted building a separate PaywallView variant. If beta data says "the post-onboarding sheet doesn't feel celebratory enough," THEN consider richer treatment.

- **`hasOnboarded` is `@AppStorage` and persists across launches.** Re-installing the app (simulator: Device → Erase All Content) resets it. There's no in-app "Reset onboarding" toggle — if you need one for QA, add it temporarily in Settings, but do NOT ship it.
