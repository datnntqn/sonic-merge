# Monetization Sub-project 2 — Feature Gates Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire real Free-vs-Pro feature gates so the paywall has a reason to exist — daily caps, length caps, merge clip-count cap, export format restriction, free-tier watermark voiceover, locked custom filler library, foreground-only transcription. Sub-project 1 built the plumbing (`EntitlementService.gate(_:) -> GateResult`, `DailyUsageTracker`, `PaywallTriggerCoordinator`, `PaywallView`). This plan gives those types real semantics and binds them at six call sites.

**Architecture:** `EntitlementService.gate(_:)` returns `.requiresPro(reason: PaywallReason)` (an enum payload, not a `String`) when a free user exceeds a cap. Each gate-bearing view holds a `@State var paywallReason: PaywallReason?` that the existing `.paywall(reason:)` modifier (built in Sub-project 1) presents as a sheet. The watermark is a single `watermark.m4a` asset shipped in the bundle and concatenated to the export buffer for free users — not synthesized at export time, to avoid per-export TTS work.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, AVFoundation (composition + asset reading for watermark concat), existing `PaywallView` Variant A, existing `DailyUsageTracker`, Swift Testing.

**Spec source:** `docs/superpowers/specs/2026-05-04-monetization-design.md` §"Free vs Pro feature matrix" + §"File structure".

**Estimated scope:** ~500 lines of Swift, 6 commits in 6 chunks. Should land in 1-2 days of focused work.

---

## Pre-flight

- [ ] **Step 1: Confirm Sub-project 1 baseline**

```bash
git log --oneline | head -20
```

You should see `81ce91b feat(subscription): hoist subscription stack ...` near HEAD. If not, you're on the wrong branch — abort and check out `main`.

- [ ] **Step 2: Confirm FAIL=5 baseline before any new code**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5` with the canonical baseline names from CLAUDE.md (`compositionWithCrossfadeHasNonNilAudioMix`, the 3 ShareExtension entitlement-gated tests, `testPositionPreservedOnSwitch`). Anything beyond 5 means something regressed during Sub-project 1 — diagnose and fix BEFORE starting this plan, otherwise you can't tell which failures you introduced.

- [ ] **Step 3: Verify the StoreKit Configuration is set on the scheme**

Open Xcode → Product → Scheme → Edit Scheme → Run → Options. Confirm **StoreKit Configuration = `CleanCut.storekit`**. If "None", set it to the file. Required for the simulator to load mocked products during gate tests.

---

## Chunk 1: `GateResult` carries `PaywallReason` + real `gate(_:)` semantics

**Why first:** Every other chunk depends on the gate API returning a specific `PaywallReason`, not a free-form string. Changing the signature later forces you to revisit every call site. Land this once, fan out.

### Task 1.1: Refactor `GateResult` to carry a `PaywallReason`

**Files:**
- Modify: `SonicMerge/Features/Subscription/Models/ProFeature.swift`

The current `GateResult.requiresPro(reason: String)` was a Sub-project 1 stub. Replace `String` with the existing `PaywallReason` enum so call sites can pass it straight to the `.paywall(reason:)` modifier without parsing.

- [ ] **Step 1: Update the enum**

Replace lines 30-35 of `SonicMerge/Features/Subscription/Models/ProFeature.swift`:

```swift
/// Returned by `EntitlementService.gate(_:)`. The `requiresPro` case carries
/// a `PaywallReason` so call sites can bind it directly to a
/// `.paywall(reason:)` modifier without parsing strings — keeps gate logic
/// and paywall-routing logic in one piece.
enum GateResult: Equatable, Sendable {
    case allowed
    case requiresPro(reason: PaywallReason)
}
```

`PaywallReason: Equatable, Sendable` is already true (enum with only-`String`/no-payload cases — the compiler synthesizes both). No further changes needed.

- [ ] **Step 2: Update the EntitlementService stub return**

Modify `SonicMerge/Features/Subscription/Services/EntitlementService.swift` — the existing default-`.allowed` body still compiles, but the doc-comment now references the wrong type. Update the comment and leave the body alone (Task 1.2 fills it in):

```swift
/// Maps a `ProFeature` to a `GateResult`, deciding whether the user can
/// proceed. Free-tier callers bind the returned `PaywallReason` straight
/// into a `.paywall(reason:)` modifier when denied.
func gate(_ feature: ProFeature) -> GateResult {
    return .allowed
}
```

- [ ] **Step 3: Build to confirm no regressions**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`. If not, search for any remaining `.requiresPro(reason: "...")` string-literal callsites and update.

### Task 1.2: Implement real `gate(_:)` semantics

**Files:**
- Modify: `SonicMerge/Features/Subscription/Services/EntitlementService.swift`
- Modify (init): inject `DailyUsageTracker` so gate can read counts
- Test: `SonicMergeTests/Features/Subscription/Services/EntitlementServiceTests.swift` (already exists; extend it)

The service needs to read three things to decide:
1. `currentEntitlement.isPro` — Pro = always allowed
2. `DailyUsageTracker.count(for:)` — for daily-cap gates
3. The payload on the `ProFeature` case (length, count, format) — to compare against caps

Caps from spec (hardcoded constants — single source of truth here):

| Constant | Value |
|---|---|
| `freeSmartCutSessionsPerDay` | 3 |
| `freeDenoiseSessionsPerDay` | 3 |
| `freeSmartCutMaxSeconds` | 300 (5 min) |
| `freeDenoiseMaxSeconds` | 180 (3 min) |
| `freeMergeMaxClips` | 3 |

- [ ] **Step 1: Write the failing tests first**

Open `SonicMergeTests/Features/Subscription/Services/EntitlementServiceTests.swift`. Add the gate matrix below alongside whatever is already there (don't delete the existing tests):

```swift
// MARK: - gate(_:) — Sub-project 2

@Test func proUserAlwaysAllowed() {
    let svc = EntitlementService()
    svc.setEntitlement(.lifetime)

    let cases: [ProFeature] = [
        .smartCutSession, .smartCutLength(seconds: 99999),
        .denoiseSession, .denoiseLength(seconds: 99999),
        .mergeClipCount(count: 999),
        .exportFormat(format: .mp3),
        .removeWatermark, .customFillerLibrary, .backgroundProcessing
    ]
    for feature in cases {
        #expect(svc.gate(feature) == .allowed, "Pro should be allowed for \(feature)")
    }
}

@Test func freeSmartCutSessionDailyCap() {
    let suite = "EntitlementServiceTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let tracker = DailyUsageTracker(
        defaults: defaults,
        calendar: Calendar(identifier: .gregorian),
        dateProvider: { Date(timeIntervalSince1970: 1714824000) }
    )
    let svc = EntitlementService(usageTracker: tracker)
    // 0, 1, 2 → allowed; 3 → denied
    for _ in 0..<3 {
        #expect(svc.gate(.smartCutSession) == .allowed)
        tracker.increment(.smartCut)
    }
    #expect(svc.gate(.smartCutSession) == .requiresPro(reason: .hitDailyCap))
}

@Test func freeSmartCutLengthCap() {
    let svc = EntitlementService()
    #expect(svc.gate(.smartCutLength(seconds: 299)) == .allowed)
    #expect(svc.gate(.smartCutLength(seconds: 300)) == .allowed)  // 5:00 exactly is OK
    #expect(svc.gate(.smartCutLength(seconds: 301)) == .requiresPro(reason: .hitLengthCap))
}

@Test func freeDenoiseLengthCap() {
    let svc = EntitlementService()
    #expect(svc.gate(.denoiseLength(seconds: 180)) == .allowed)
    #expect(svc.gate(.denoiseLength(seconds: 181)) == .requiresPro(reason: .hitLengthCap))
}

@Test func freeMergeClipCountCap() {
    let svc = EntitlementService()
    #expect(svc.gate(.mergeClipCount(count: 3)) == .allowed)
    #expect(svc.gate(.mergeClipCount(count: 4)) == .requiresPro(reason: .hitLengthCap))
    // .hitLengthCap is the closest existing reason for "your input exceeds free." If
    // we want a distinct .hitClipCountCap later, add it to PaywallReason — for v1
    // we share the reason because the headline copy reads the same.
}

@Test func freeExportFormat() {
    let svc = EntitlementService()
    #expect(svc.gate(.exportFormat(format: .wav)) == .allowed)
    #expect(svc.gate(.exportFormat(format: .m4a)) == .requiresPro(reason: .watermarkExport))
    #expect(svc.gate(.exportFormat(format: .mp3)) == .requiresPro(reason: .watermarkExport))
}

@Test func freeRemoveWatermark() {
    let svc = EntitlementService()
    #expect(svc.gate(.removeWatermark) == .requiresPro(reason: .watermarkExport))
}

@Test func freeCustomFillerLibrary() {
    let svc = EntitlementService()
    #expect(svc.gate(.customFillerLibrary) == .requiresPro(reason: .settingsUpgrade))
    // .settingsUpgrade is the user-explicitly-chose-to-upgrade reason; library
    // editing is a Settings-adjacent feature so it shares that reason.
}

@Test func freeBackgroundProcessing() {
    let svc = EntitlementService()
    #expect(svc.gate(.backgroundProcessing) == .requiresPro(reason: .settingsUpgrade))
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SonicMergeTests/EntitlementServiceTests test 2>&1 | tail -20
```

Expected: most of these fail because `gate()` returns `.allowed` always today; also a compile error on `EntitlementService(usageTracker: tracker)` since the init doesn't accept a tracker yet. That compile error proves you need Step 3.

- [ ] **Step 3: Update `EntitlementService` to take a tracker + implement gate semantics**

Replace the body of `SonicMerge/Features/Subscription/Services/EntitlementService.swift` from the class declaration onward:

```swift
@MainActor
@Observable
final class EntitlementService {

    /// Process-wide singleton. Tests can construct fresh instances with
    /// custom trackers; the app uses `RootTabView`'s @State-owned instance.
    static let shared = EntitlementService()

    /// Free-tier caps. Single source of truth — gate() compares against
    /// these and nothing else hardcodes the values.
    enum FreeCap {
        static let smartCutSessionsPerDay = 3
        static let denoiseSessionsPerDay = 3
        static let smartCutMaxSeconds: TimeInterval = 300  // 5:00
        static let denoiseMaxSeconds: TimeInterval = 180   // 3:00
        static let mergeMaxClips = 3
    }

    private(set) var currentEntitlement: Entitlement = .free

    var isPro: Bool { currentEntitlement.isPro }

    private let usageTracker: DailyUsageTracker

    init(usageTracker: DailyUsageTracker = DailyUsageTracker()) {
        self.usageTracker = usageTracker
    }

    func setEntitlement(_ entitlement: Entitlement) {
        currentEntitlement = entitlement
    }

    /// Maps a `ProFeature` to a `GateResult`. Pro users always pass; Free
    /// users compare against `FreeCap` and `usageTracker`.
    func gate(_ feature: ProFeature) -> GateResult {
        if isPro { return .allowed }
        return gateFree(feature)
    }

    /// Mirrors `gate(_:)` but always evaluates the Free-tier path. Used by
    /// debug tooling that wants to preview "what the Free user would see"
    /// while testing on a Pro account.
    func gateFree(_ feature: ProFeature) -> GateResult {
        switch feature {
        case .smartCutSession:
            return usageTracker.count(for: .smartCut) >= FreeCap.smartCutSessionsPerDay
                ? .requiresPro(reason: .hitDailyCap)
                : .allowed

        case .smartCutLength(let seconds):
            return seconds > FreeCap.smartCutMaxSeconds
                ? .requiresPro(reason: .hitLengthCap)
                : .allowed

        case .denoiseSession:
            return usageTracker.count(for: .denoise) >= FreeCap.denoiseSessionsPerDay
                ? .requiresPro(reason: .hitDailyCap)
                : .allowed

        case .denoiseLength(let seconds):
            return seconds > FreeCap.denoiseMaxSeconds
                ? .requiresPro(reason: .hitLengthCap)
                : .allowed

        case .mergeClipCount(let count):
            return count > FreeCap.mergeMaxClips
                ? .requiresPro(reason: .hitLengthCap)
                : .allowed

        case .exportFormat(let format):
            return format == .wav
                ? .allowed
                : .requiresPro(reason: .watermarkExport)

        case .removeWatermark:
            return .requiresPro(reason: .watermarkExport)

        case .customFillerLibrary, .backgroundProcessing:
            return .requiresPro(reason: .settingsUpgrade)
        }
    }

    /// Helpers for incrementing usage. Called by SmartCut/Denoise call
    /// sites at the moment a session is committed (not at apply-cuts —
    /// session creation is the chargeable action).
    func recordSmartCutSession() { usageTracker.increment(.smartCut) }
    func recordDenoiseSession() { usageTracker.increment(.denoise) }
}
```

- [ ] **Step 4: Update `RootTabView` to inject the tracker into the service**

Open `SonicMerge/App/RootTabView.swift`. Replace the existing `@State private var entitlementService = EntitlementService()` with one that uses a shared tracker:

```swift
@State private var entitlementService = EntitlementService(usageTracker: DailyUsageTracker())
```

(Both the service and any direct DailyUsageTracker callsites elsewhere must agree on the same UserDefaults suite. Since `DailyUsageTracker.init` defaults to `.standard`, two `DailyUsageTracker()` instances see the same counters — but for cleanliness, route everything through `entitlementService.recordSmartCutSession()` / `recordDenoiseSession()` going forward.)

- [ ] **Step 5: Run tests to verify pass**

```bash
xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SonicMergeTests/EntitlementServiceTests test 2>&1 | tail -10
```

Expected: all 9 new tests pass plus any prior `EntitlementServiceTests` cases.

- [ ] **Step 6: Run full suite to confirm baseline preserved**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`.

- [ ] **Step 7: Commit**

```bash
git add SonicMerge/Features/Subscription/Models/ProFeature.swift \
        SonicMerge/Features/Subscription/Services/EntitlementService.swift \
        SonicMerge/App/RootTabView.swift \
        SonicMergeTests/Features/Subscription/Services/EntitlementServiceTests.swift
git commit -m "feat(subscription): real gate semantics + GateResult carries PaywallReason"
```

---

## Chunk 2: Smart Cut gates (sessions/day + length)

**Why second:** Smart Cut is the primary AI surface, so it's the highest-value feature to gate first. Daily-count tracking and length checking happen at import time (where we already have the duration) — this is the simplest of the three feature-tab gates.

### Task 2.1: Gate Smart Cut import

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift`

Two gates, one paywall route:
1. Length cap — refuse import if duration > 5 min
2. Daily cap — refuse import if user has already created 3 today

The check happens *after* duration is loaded but *before* `modelContext.insert(session)`. If denied, we delete the temp file we just copied and show the paywall.

- [ ] **Step 1: Add subscription environment + paywall state**

Open `SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift`. Find the existing `@Environment` block near the top and add:

```swift
@Environment(EntitlementService.self) private var entitlements
@State private var paywallReason: PaywallReason?
```

Then on the body (just below the existing `.toolbar { ... }` closure), add:

```swift
.paywall(reason: $paywallReason)
```

(The `.paywall(reason:)` modifier was added in Sub-project 1 / `PaywallTrigger.swift` — it's already in the codebase.)

- [ ] **Step 2: Add the gate check in `createSession`**

In `SmartCutHomeView.swift`, find `createSession(from:)` (currently around line 138). After `duration` is loaded (currently line 169) and BEFORE `let sourceHash` (line 176), insert:

```swift
        // Sub-project 2 gate: refuse if Free user exceeds 5-min length cap
        // or has hit today's 3-session quota. Cleanup the temp file we just
        // copied so we don't leak storage on rejected imports.
        if case .requiresPro(let reason) = entitlements.gate(.smartCutLength(seconds: duration)) {
            try? FileManager.default.removeItem(at: dir)
            paywallReason = reason
            return
        }
        if case .requiresPro(let reason) = entitlements.gate(.smartCutSession) {
            try? FileManager.default.removeItem(at: dir)
            paywallReason = reason
            return
        }
```

- [ ] **Step 3: Record the session AFTER the save succeeds**

Find the line `try modelContext.save()` (around line 194). Immediately after the closing `}` of its do-catch, but inside `createSession`, add:

```swift
        entitlements.recordSmartCutSession()
```

Order matters: increment ONLY after the model is persisted, otherwise an import error inflates the daily count.

- [ ] **Step 4: Build to confirm no compilation errors**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

### Task 2.2: Smart Cut gating tests (UI smoke + flow)

**Files:**
- Test: `SonicMergeTests/Features/SmartCut/SmartCutHomeViewGatingTests.swift` (new file)

UI integration tests are flaky on `xcodebuild`, so we test the *gate routing* directly: given a `EntitlementService` in a known state, verify the call site sets `paywallReason` correctly.

Since `createSession` is private and orchestrates file IO, we test through a thin extracted helper instead.

- [ ] **Step 1: Extract the gate-decision logic into a testable static helper**

In `SmartCutHomeView.swift`, add at the bottom of the struct (private nested type or static):

```swift
/// Pure decision: should we import this audio? Lifted out of `createSession`
/// so tests can verify gate routing without touching the file system.
struct ImportDecision {
    static func gate(
        durationSeconds: TimeInterval,
        entitlements: EntitlementService
    ) -> PaywallReason? {
        if case .requiresPro(let reason) = entitlements.gate(.smartCutLength(seconds: durationSeconds)) {
            return reason
        }
        if case .requiresPro(let reason) = entitlements.gate(.smartCutSession) {
            return reason
        }
        return nil
    }
}
```

Then change the gate-block in `createSession` from Step 2 above to use this helper:

```swift
        if let reason = ImportDecision.gate(durationSeconds: duration, entitlements: entitlements) {
            try? FileManager.default.removeItem(at: dir)
            paywallReason = reason
            return
        }
```

- [ ] **Step 2: Write the tests**

Create `SonicMergeTests/Features/SmartCut/SmartCutHomeViewGatingTests.swift`:

```swift
import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct SmartCutHomeViewGatingTests {

    private func freshTracker() -> DailyUsageTracker {
        let suite = "SmartCutGatingTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return DailyUsageTracker(
            defaults: defaults,
            calendar: Calendar(identifier: .gregorian),
            dateProvider: { Date(timeIntervalSince1970: 1714824000) }
        )
    }

    @Test func freeUserUnderCapsAllowed() {
        let svc = EntitlementService(usageTracker: freshTracker())
        let decision = SmartCutHomeView.ImportDecision.gate(
            durationSeconds: 60,
            entitlements: svc
        )
        #expect(decision == nil)
    }

    @Test func freeUserExceedsLengthCap() {
        let svc = EntitlementService(usageTracker: freshTracker())
        let decision = SmartCutHomeView.ImportDecision.gate(
            durationSeconds: 301,
            entitlements: svc
        )
        #expect(decision == .hitLengthCap)
    }

    @Test func freeUserHitsDailyCap() {
        let tracker = freshTracker()
        let svc = EntitlementService(usageTracker: tracker)
        for _ in 0..<3 { svc.recordSmartCutSession() }
        let decision = SmartCutHomeView.ImportDecision.gate(
            durationSeconds: 60,
            entitlements: svc
        )
        #expect(decision == .hitDailyCap)
    }

    @Test func proUserBypassesAllCaps() {
        let svc = EntitlementService(usageTracker: freshTracker())
        svc.setEntitlement(.lifetime)
        for _ in 0..<10 { svc.recordSmartCutSession() }  // count irrelevant for Pro
        let decision = SmartCutHomeView.ImportDecision.gate(
            durationSeconds: 9999,
            entitlements: svc
        )
        #expect(decision == nil)
    }

    @Test func lengthCapTakesPrecedenceOverDailyCap() {
        let tracker = freshTracker()
        let svc = EntitlementService(usageTracker: tracker)
        for _ in 0..<3 { svc.recordSmartCutSession() }
        let decision = SmartCutHomeView.ImportDecision.gate(
            durationSeconds: 9999,
            entitlements: svc
        )
        // Both caps fail. The order of checks gives length first → user
        // sees the .hitLengthCap copy (more specific message).
        #expect(decision == .hitLengthCap)
    }
}
```

- [ ] **Step 3: Run tests**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SonicMergeTests/SmartCutHomeViewGatingTests test 2>&1 | tail -10
```

Expected: PASS (5 tests).

- [ ] **Step 4: Run full suite + commit**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`.

```bash
git add SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift \
        SonicMergeTests/Features/SmartCut/SmartCutHomeViewGatingTests.swift
git commit -m "feat(subscription): gate Smart Cut imports on daily cap + length cap"
```

---

## Chunk 3: Denoise gates (sessions/day + length)

**Why third:** Identical pattern to Chunk 2 — different feature, different cap (3 min vs 5 min), same call-site shape. Should be quick because Chunk 2 established the recipe.

### Task 3.1: Gate Denoise import

**Files:**
- Modify: `SonicMerge/Features/Denoising/Views/Home/DenoiseHomeView.swift`

Two gates analogous to Smart Cut:
1. Length cap — refuse import if duration > 3 min
2. Daily cap — refuse import if user has already created 3 today

- [ ] **Step 1: Add subscription environment + paywall state**

In `DenoiseHomeView.swift`, near the existing `@Environment` block, add:

```swift
@Environment(EntitlementService.self) private var entitlements
@State private var paywallReason: PaywallReason?
```

On the body (below the existing `.toolbar { ... }` block — match the position used in `SmartCutHomeView`), add:

```swift
.paywall(reason: $paywallReason)
```

- [ ] **Step 2: Add the gate check in the import flow**

Find the section in `DenoiseHomeView.handleImport` / `createSession` that loads `let duration = try await AVURLAsset(url: destURL).load(.duration).seconds` (around line 156). After that line, BEFORE the `DenoiseSession` is constructed (line 167), insert:

```swift
        if let reason = ImportDecision.gate(durationSeconds: duration, entitlements: entitlements) {
            try? FileManager.default.removeItem(at: dir)
            paywallReason = reason
            return
        }
```

- [ ] **Step 3: Add the gate decision helper**

Mirroring `SmartCutHomeView.ImportDecision`, add at the bottom of `DenoiseHomeView`:

```swift
struct ImportDecision {
    static func gate(
        durationSeconds: TimeInterval,
        entitlements: EntitlementService
    ) -> PaywallReason? {
        if case .requiresPro(let reason) = entitlements.gate(.denoiseLength(seconds: durationSeconds)) {
            return reason
        }
        if case .requiresPro(let reason) = entitlements.gate(.denoiseSession) {
            return reason
        }
        return nil
    }
}
```

- [ ] **Step 4: Increment usage after save**

Find the section that saves the `DenoiseSession` to the model context. Immediately after the successful `try modelContext.save()`, add:

```swift
        entitlements.recordDenoiseSession()
```

- [ ] **Step 5: Build**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

### Task 3.2: Denoise gating tests

**Files:**
- Test: `SonicMergeTests/Features/Denoising/DenoiseHomeViewGatingTests.swift` (new)

- [ ] **Step 1: Write the tests**

```swift
import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct DenoiseHomeViewGatingTests {

    private func freshTracker() -> DailyUsageTracker {
        let suite = "DenoiseGatingTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return DailyUsageTracker(
            defaults: defaults,
            calendar: Calendar(identifier: .gregorian),
            dateProvider: { Date(timeIntervalSince1970: 1714824000) }
        )
    }

    @Test func freeUserUnderCapsAllowed() {
        let svc = EntitlementService(usageTracker: freshTracker())
        let decision = DenoiseHomeView.ImportDecision.gate(durationSeconds: 60, entitlements: svc)
        #expect(decision == nil)
    }

    @Test func freeUserExceedsLengthCap() {
        let svc = EntitlementService(usageTracker: freshTracker())
        // Denoise free length = 180s = 3 min
        let decision = DenoiseHomeView.ImportDecision.gate(durationSeconds: 181, entitlements: svc)
        #expect(decision == .hitLengthCap)
    }

    @Test func freeUserHitsDailyCap() {
        let tracker = freshTracker()
        let svc = EntitlementService(usageTracker: tracker)
        for _ in 0..<3 { svc.recordDenoiseSession() }
        let decision = DenoiseHomeView.ImportDecision.gate(durationSeconds: 60, entitlements: svc)
        #expect(decision == .hitDailyCap)
    }

    @Test func proUserBypassesAllCaps() {
        let svc = EntitlementService(usageTracker: freshTracker())
        svc.setEntitlement(.lifetime)
        let decision = DenoiseHomeView.ImportDecision.gate(durationSeconds: 9999, entitlements: svc)
        #expect(decision == nil)
    }
}
```

- [ ] **Step 2: Run tests + full suite + commit**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SonicMergeTests/DenoiseHomeViewGatingTests test 2>&1 | tail -10
```

Expected: PASS (4 tests).

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`.

```bash
git add SonicMerge/Features/Denoising/Views/Home/DenoiseHomeView.swift \
        SonicMergeTests/Features/Denoising/DenoiseHomeViewGatingTests.swift
git commit -m "feat(subscription): gate Denoise imports on daily cap + length cap"
```

---

## Chunk 4: Merge clip-count gate + export format gate

**Why fourth:** Both gates live in the Merge tab and share the same paywall-binding pattern. Bundling them avoids touching `MixingStationView` twice.

### Task 4.1: Gate clip-count in `MixingStationViewModel.importFiles`

**Files:**
- Modify: `SonicMerge/Features/MixingStation/MixingStationViewModel.swift`
- Modify: `SonicMerge/Features/MixingStation/MixingStationView.swift` (paywall binding)

The view-model owns the import path. We could push the gate up into the view (analogous to SmartCut/Denoise) but `MixingStationViewModel.importFiles` already does file-system work and computes `clips.count`, so the cleanest seam is a return-value: `importFiles` returns a `PaywallReason?` indicating "we refused some/all of these because of the clip-count cap." The view binds that into `paywallReason`.

- [ ] **Step 1: Add `EntitlementService` to the view-model**

Open `MixingStationViewModel.swift`. Find its initializer (currently takes `modelContext`). Extend it:

```swift
private let entitlements: EntitlementService

init(modelContext: ModelContext, entitlements: EntitlementService) {
    self.modelContext = modelContext
    self.entitlements = entitlements
}
```

In `RootTabView.swift`, where `MixingStationViewModel` is constructed in `.onAppear`, update:

```swift
mixingStationViewModel = MixingStationViewModel(
    modelContext: modelContext,
    entitlements: entitlementService
)
```

- [ ] **Step 2: Refactor `importFiles` to return a paywall reason**

Find `func importFiles(_ urls: [URL])` (around line 77). Change the signature to return `PaywallReason?`:

```swift
@discardableResult
func importFiles(_ urls: [URL]) -> PaywallReason? {
    // existing setup ...
    let alreadyHave = clips.count
    let projectedTotal = alreadyHave + urls.count
    if case .requiresPro(let reason) = entitlements.gate(.mergeClipCount(count: projectedTotal)) {
        // Free user would exceed cap. Don't import ANY of them — partial
        // import would be confusing ("why are 2 of my 4 files missing?").
        return reason
    }

    // existing import body ...
    return nil
}
```

The check happens before any file is copied — clean rejection, no temp files to clean up.

- [ ] **Step 3: Bind the result in `MixingStationView`**

Open `MixingStationView.swift`. Add the env + state near the top:

```swift
@Environment(EntitlementService.self) private var entitlements
@State private var paywallReason: PaywallReason?
```

Add the modifier on the body, near the existing `.toolbar` / `.sheet` modifiers:

```swift
.paywall(reason: $paywallReason)
```

Find the call site that invokes `viewModel.importFiles(...)` (search for `importFiles(`). Change it from:

```swift
viewModel.importFiles(urls)
```

to:

```swift
if let reason = viewModel.importFiles(urls) {
    paywallReason = reason
}
```

Apply this transformation at *every* `importFiles(...)` call site — there are typically two: the file-importer success handler and the drag-and-drop handler.

- [ ] **Step 4: Build**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

### Task 4.2: Gate export format in `ExportFormatSheet`

**Files:**
- Modify: `SonicMerge/Features/MixingStation/ExportFormatSheet.swift`

The sheet currently lets every user pick `.m4a` or `.wav`. Per spec, free users get WAV-only. The cleanest UX is to disable non-WAV options for free users + show a "Pro" tag. Tapping a disabled option triggers the paywall.

- [ ] **Step 1: Add subscription state + paywall reason**

In `ExportFormatSheet.swift`, add to the struct:

```swift
@Environment(EntitlementService.self) private var entitlements
@Binding var paywallReason: PaywallReason?
```

The new `paywallReason` binding is owned by the parent (the sheet's presenter — `MixingStationView`, `SmartCutSessionView`, `DenoiseSessionView` — passes its existing `$paywallReason` here).

- [ ] **Step 2: Replace the format Picker with a gated row layout**

Replace the current `Picker` block with:

```swift
VStack(spacing: 8) {
    formatRow(format: .wav, label: ".wav (Lossless)", isPro: false)
    formatRow(format: .m4a, label: ".m4a (AAC)", isPro: !entitlements.isPro)
}
.padding(.horizontal, 24)
```

Add the helper inside the struct:

```swift
@ViewBuilder
private func formatRow(format: ExportFormat, label: String, isPro: Bool) -> some View {
    Button {
        if isPro {
            paywallReason = .watermarkExport
        } else {
            selectedFormat = format
        }
    } label: {
        HStack {
            Image(systemName: selectedFormat == format ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(Color(uiColor: semantic.accentAction))
            Text(label)
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
            Spacer()
            if isPro {
                Text("PRO")
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(LinearGradient(
                        colors: semantic.accentAIGradientStops.map { Color(uiColor: $0) },
                        startPoint: .leading, endPoint: .trailing
                    )))
                    .foregroundStyle(.white)
            }
        }
        .padding(.vertical, 6)
    }
    .buttonStyle(.plain)
}
```

- [ ] **Step 3: Update presenters to pass the binding**

Find every `ExportFormatSheet(isPresented: ..., onExport: ...)` call site. There are 3:
1. `MixingStationView.swift` ~line 49
2. `SmartCutSessionView.swift` ~line 71
3. `DenoiseSessionView.swift` ~line 104

Each needs the new `paywallReason` argument. Each presenter view should already have a `@State var paywallReason: PaywallReason?` from its own gate work — for `SmartCutSessionView` and `DenoiseSessionView`, add the env + state if missing (same pattern as Chunks 2 & 3 added to the home views — but on the *Session* views, not the home views, because export happens from the session detail).

Update each call site:

```swift
ExportFormatSheet(
    isPresented: $showExportSheet,
    paywallReason: $paywallReason   // NEW
) { options in
    // existing onExport body
}
```

For `SmartCutSessionView` and `DenoiseSessionView`, also add the `.paywall(reason: $paywallReason)` modifier on their body if not already there.

- [ ] **Step 4: Free-tier safety on actual export call**

A user who already has a non-WAV format selected (because they were Pro yesterday and downgraded) shouldn't be able to bypass via stale `selectedFormat`. Find the "Export Audio" button's action:

```swift
Button("Export Audio") {
    isPresented = false
    onExport(ExportOptions(format: selectedFormat, lufsNormalize: lufsEnabled))
}
```

Replace with:

```swift
Button("Export Audio") {
    if !entitlements.isPro && selectedFormat != .wav {
        paywallReason = .watermarkExport
        return
    }
    isPresented = false
    onExport(ExportOptions(format: selectedFormat, lufsNormalize: lufsEnabled))
}
```

- [ ] **Step 5: Build**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

### Task 4.3: Tests for Chunk 4

**Files:**
- Test: `SonicMergeTests/Features/MixingStation/MixingStationViewModelGatingTests.swift` (new)

Cover the clip-count gate at the view-model layer. The export-format gate is best validated by manual smoke (since `ExportFormatSheet` is heavily SwiftUI), but we leave a render-only test as a regression guard.

- [ ] **Step 1: Write the tests**

```swift
import Testing
import Foundation
import SwiftData
@testable import SonicMerge

@MainActor
struct MixingStationViewModelGatingTests {

    private func freshContext() throws -> ModelContext {
        let schema = Schema([AudioClip.self, GapTransition.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func freshService() -> EntitlementService {
        let suite = "MixingStationGatingTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let tracker = DailyUsageTracker(
            defaults: defaults,
            calendar: Calendar(identifier: .gregorian),
            dateProvider: { Date(timeIntervalSince1970: 1714824000) }
        )
        return EntitlementService(usageTracker: tracker)
    }

    @Test func freeUserUnderCapPassesGate() throws {
        let svc = freshService()
        let vm = MixingStationViewModel(modelContext: try freshContext(), entitlements: svc)
        // Importing 3 fake files when clips is empty: total projected = 3.
        // freeMergeMaxClips = 3, so 3 ≤ 3 = allowed. Method may still fail
        // for *file-system* reasons — that's fine; we only check the gate.
        let urls = [URL(fileURLWithPath: "/tmp/a.m4a"),
                    URL(fileURLWithPath: "/tmp/b.m4a"),
                    URL(fileURLWithPath: "/tmp/c.m4a")]
        let result = vm.importFiles(urls)
        // Either nil (gate passed, file-system error doesn't propagate) or
        // a non-paywall failure surfaced via `importErrors`.
        #expect(result == nil)
    }

    @Test func freeUserExceedsClipCountCap() throws {
        let svc = freshService()
        let vm = MixingStationViewModel(modelContext: try freshContext(), entitlements: svc)
        let urls = (0..<5).map { URL(fileURLWithPath: "/tmp/\($0).m4a") }
        let result = vm.importFiles(urls)
        #expect(result == .hitLengthCap)
        // Sanity: nothing got imported because we reject the whole batch.
        #expect(vm.clips.isEmpty)
    }

    @Test func proUserBypassesClipCountCap() throws {
        let svc = freshService()
        svc.setEntitlement(.lifetime)
        let vm = MixingStationViewModel(modelContext: try freshContext(), entitlements: svc)
        let urls = (0..<10).map { URL(fileURLWithPath: "/tmp/\($0).m4a") }
        let result = vm.importFiles(urls)
        #expect(result == nil)
    }
}
```

- [ ] **Step 2: Run tests + full suite + commit**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SonicMergeTests/MixingStationViewModelGatingTests test 2>&1 | tail -10
```

Expected: PASS (3 tests).

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`.

```bash
git add SonicMerge/Features/MixingStation/MixingStationViewModel.swift \
        SonicMerge/Features/MixingStation/MixingStationView.swift \
        SonicMerge/Features/MixingStation/ExportFormatSheet.swift \
        SonicMerge/Features/SmartCut/Views/Home/SmartCutSessionView.swift \
        SonicMerge/Features/Denoising/Views/Home/DenoiseSessionView.swift \
        SonicMerge/App/RootTabView.swift \
        SonicMergeTests/Features/MixingStation/MixingStationViewModelGatingTests.swift
git commit -m "feat(subscription): gate merge clip-count + export format on free tier"
```

---

## Chunk 5: Free-export watermark voiceover

**Why fifth:** This is the only chunk that touches the audio pipeline (`AudioMergerService`). It's also the one with a non-trivial asset workflow (a `.m4a` voiceover file must be added to the bundle). Best to land it in isolation so any audio regression is bisectable to one commit.

### Task 5.1: Generate + bundle the watermark asset

**Files:**
- Create: `SonicMerge/Assets.xcassets/Watermark.dataset/` (Xcode asset catalog) OR `SonicMerge/Resources/watermark.m4a` (loose resource)
- Manual asset creation (one-time)

The voiceover line is "Cleaned with CleanCut" — ~0.5s at typical TTS speed. Simplest production path:

- [ ] **Step 1: Generate the audio**

On macOS, run:

```bash
say -v Samantha -o /tmp/watermark-raw.aiff "Cleaned with CleanCut."
```

Then convert to m4a (small file) at podcast-friendly settings:

```bash
afconvert /tmp/watermark-raw.aiff /tmp/watermark.m4a -d aac -f m4af -b 64000
```

Resulting file should be ~5-8 KB. Listen to it (`afplay /tmp/watermark.m4a`) and confirm clarity.

- [ ] **Step 2: Add to project**

In Xcode: File → Add Files to "SonicMerge" → select `/tmp/watermark.m4a`. Place it under `SonicMerge/Resources/`. Verify it's in the SonicMerge target's Copy Bundle Resources phase.

- [ ] **Step 3: Verify the asset is bundled**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build 2>&1 | tail -5
xcrun simctl get_app_container booted com.yourteam.SonicMerge 2>/dev/null | head -1
```

Open the resulting `.app` bundle and `ls` its contents — `watermark.m4a` should be present. If not, the file was added with the wrong target membership; revisit Step 2.

- [ ] **Step 4: Commit asset alone**

```bash
git add SonicMerge/Resources/watermark.m4a SonicMerge.xcodeproj/project.pbxproj
git commit -m "chore(subscription): add watermark voiceover asset (free-export tag)"
```

### Task 5.2: Apply watermark during export for free users

**Files:**
- Modify: `SonicMerge/Services/AudioMergerService.swift` (or wherever `exportFile` lives)
- Test: `SonicMergeTests/Services/AudioMergerWatermarkTests.swift` (new)

The export pipeline currently writes the user's audio. For free users, append `watermark.m4a` after their content. Since the watermark is short (~0.5s), do it as a composition concat — same `AVMutableComposition` pattern the merger already uses internally.

- [ ] **Step 1: Locate the single chokepoint for export**

```bash
grep -nE "func export|AVAssetExportSession|AVAssetWriter" SonicMerge/Services/AudioMergerService.swift | head -10
```

There should be one or two public `export*(...)` methods. The watermark logic goes immediately before the asset is exported — at the composition-build level, NOT after.

- [ ] **Step 2: Add a watermark-aware composition wrapper**

Add to `AudioMergerService.swift`:

```swift
/// Appends the free-tier watermark voiceover to the end of `composition`.
/// No-op if `applyWatermark` is false (Pro users) or the asset is missing
/// from the bundle (defensive: never block an export on a missing tag —
/// log + continue).
private func appendWatermarkIfNeeded(
    _ composition: AVMutableComposition,
    audioTrack: AVMutableCompositionTrack,
    applyWatermark: Bool
) async {
    guard applyWatermark else { return }
    guard let url = Bundle.main.url(forResource: "watermark", withExtension: "m4a") else {
        // Defensive: shouldn't happen in shipped builds. Log and let the
        // export continue without the tag rather than fail the user's work.
        print("[AudioMerger] watermark.m4a missing from bundle — skipping tag.")
        return
    }
    let watermarkAsset = AVURLAsset(url: url)
    do {
        let watermarkTracks = try await watermarkAsset.loadTracks(withMediaType: .audio)
        guard let watermarkTrack = watermarkTracks.first else { return }
        let watermarkDuration = try await watermarkAsset.load(.duration)
        let insertTime = composition.duration  // tail of existing content
        try audioTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: watermarkDuration),
            of: watermarkTrack,
            at: insertTime
        )
    } catch {
        print("[AudioMerger] failed to append watermark: \(error.localizedDescription)")
    }
}
```

- [ ] **Step 3: Thread the `applyWatermark` flag through the public API**

The existing `export*` methods take `ExportOptions` (which includes `format` and `lufsNormalize`). Decide watermark application at the call site by reading `EntitlementService.isPro` — but the *service* shouldn't depend on the entitlement service. So pass it as an explicit parameter:

```swift
func exportFile(
    from clips: [AudioClip],
    options: ExportOptions,
    applyWatermark: Bool   // NEW
) async throws -> URL { ... }
```

Inside, after composition is built and BEFORE exporting:

```swift
await appendWatermarkIfNeeded(
    composition,
    audioTrack: audioTrack,
    applyWatermark: applyWatermark
)
```

- [ ] **Step 4: Update every call site**

Every export call must compute `applyWatermark = !entitlements.isPro` and pass it through:

```swift
try await audioMerger.exportFile(
    from: clips,
    options: options,
    applyWatermark: !entitlements.isPro
)
```

Search for callers:

```bash
grep -rn "exportFile(" SonicMerge --include="*.swift" | grep -v "Tests"
```

Update each. The `MixingStationViewModel.exportClips` and the analogous Smart Cut / Denoise export paths each need the flag.

- [ ] **Step 5: Write the watermark test**

```swift
import Testing
import Foundation
import AVFoundation
@testable import SonicMerge

struct AudioMergerWatermarkTests {

    /// Builds a 2s sine-wave clip and exports with watermark on. Asserts
    /// the resulting file is at least 2.4s long (2.0s clip + ~0.5s tag),
    /// proving the watermark was concatenated.
    @Test func freeExportAppendsWatermark() async throws {
        // ... synthesize a 2s test clip → AudioClip → call exportFile with applyWatermark=true ...
        // Assert: result duration >= 2.4s
    }

    @Test func proExportSkipsWatermark() async throws {
        // ... same setup, applyWatermark=false ...
        // Assert: result duration ~= 2.0s (within 50ms tolerance)
    }
}
```

(Filling in synth/clip-build code is left to the implementer — a 2s sine-wave at 44.1kHz with `AVAudioFile` write is the standard pattern; consult existing `AudioMergerService` test fixtures for an example.)

- [ ] **Step 6: Run tests + commit**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SonicMergeTests/AudioMergerWatermarkTests test 2>&1 | tail -10
```

Expected: PASS (2 tests).

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`.

```bash
git add SonicMerge/Services/AudioMergerService.swift \
        SonicMerge/Features/MixingStation/MixingStationViewModel.swift \
        SonicMerge/Features/SmartCut/Views/Home/SmartCutSessionView.swift \
        SonicMerge/Features/Denoising/Views/Home/DenoiseSessionView.swift \
        SonicMergeTests/Services/AudioMergerWatermarkTests.swift
git commit -m "feat(subscription): append watermark voiceover to free-tier exports"
```

---

## Chunk 6: Custom filler library + background processing gates

**Why last:** Both are settings/configuration-adjacent — lower visibility than the import/export gates and more likely to evolve based on TestFlight feedback. Landing them last means if Sub-project 3 (conversion moments) renames `PaywallReason.settingsUpgrade` for finer routing, only this chunk needs updating.

### Task 6.1: Gate the custom filler library editing surface

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Studio/EditFillerListStudioSheet.swift` (or wherever the filler library is editable)

Free users see the default filler set and can toggle individual defaults on/off (per Sub-project 1 design — that's not "custom"). The Pro-gated capability is *adding new custom fillers*. So the gate fires at the "Add custom word" entry point.

- [ ] **Step 1: Find the "Add custom word" UI**

```bash
grep -nE "addCustomFiller|customWords|addFillerWord|TextField.*[Cc]ustom" SonicMerge/Features/SmartCut --include="*.swift"
```

The exact location varies; in Sub-project 1's codebase the editing sheet is `EditFillerListStudioSheet.swift`. The "add" button or text-field input is the gate site.

- [ ] **Step 2: Wrap the add action in a gate check**

In the relevant view (likely `EditFillerListStudioSheet`), add:

```swift
@Environment(EntitlementService.self) private var entitlements
@State private var paywallReason: PaywallReason?
```

In the body, add `.paywall(reason: $paywallReason)`.

In the "Add" action handler, check the gate before calling the existing add logic:

```swift
Button("Add") {
    if case .requiresPro(let reason) = entitlements.gate(.customFillerLibrary) {
        paywallReason = reason
        return
    }
    library.addCustom(word: newWord)
    newWord = ""
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

### Task 6.2: Gate background transcription start

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Services/BackgroundTranscriptionTask.swift` OR wherever the background-task is kicked off

Background transcription = the "OS notification when long file finishes processing while you're outside the app" feature. Free users get foreground only.

- [ ] **Step 1: Find the trigger**

```bash
grep -rn "BackgroundTranscriptionTask\|beginBackgroundTask\|backgroundTaskID" SonicMerge --include="*.swift" | head -10
```

The trigger is wherever Smart Cut decides "this file is long enough to keep running in background." That decision is the gate site.

- [ ] **Step 2: Add the gate check at the trigger**

At that call site, before scheduling the background task:

```swift
if case .requiresPro = entitlements.gate(.backgroundProcessing) {
    // Free user — skip background scheduling. Job continues in foreground;
    // when user backgrounds the app it pauses (existing behavior). On
    // re-foreground it resumes — no extra UI is needed beyond the existing
    // "tap to resume" affordance. We deliberately do NOT show a paywall
    // here — it would feel like punishment for closing the app.
    return
}
// existing background-scheduling code
```

Note the design choice: silent-skip rather than paywall-on-background. The user already paid the wow during foreground; they didn't *try* to do anything Pro-only. Surfacing a paywall here feels nag-y.

- [ ] **Step 3: Build + commit Chunk 6**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`.

```bash
git add SonicMerge/Features/SmartCut/Views/Studio/EditFillerListStudioSheet.swift \
        SonicMerge/Features/SmartCut/Services/BackgroundTranscriptionTask.swift
# Adjust paths above to whatever you actually modified.
git commit -m "feat(subscription): gate custom filler library + background transcription"
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

Expected: `FAIL=5` (baseline preserved). New tests added: ~21 across `EntitlementServiceTests`, `SmartCutHomeViewGatingTests`, `DenoiseHomeViewGatingTests`, `MixingStationViewModelGatingTests`, `AudioMergerWatermarkTests`. All passing.

- [ ] **Step 2: Manual end-to-end on simulator (Free tier)**

Set scheme's StoreKit Configuration to `CleanCut.storekit`. Reset simulator (Device → Erase All Content) so DailyUsageTracker counters are clean. Launch app.

1. **Smart Cut**: import a 1-min file → success. Repeat 2 more times. Try a 4th → paywall fires (`.hitDailyCap`).
2. **Smart Cut length**: import a 6-min file as the first action of the day → paywall fires (`.hitLengthCap`).
3. **Denoise**: same shape as Smart Cut, but length cap = 3 min.
4. **Merge**: import 4 files at once → paywall fires (`.hitLengthCap` shared reason).
5. **Export from Merge**: tap Export → format picker shows .wav unlocked, .m4a with PRO badge → tap .m4a → paywall fires (`.watermarkExport`).
6. **Free-tier export**: pick .wav → exports successfully → play the result → confirm "Cleaned with CleanCut" voiceover at the tail.
7. **Custom filler**: open Smart Cut studio → Edit fillers → tap Add custom → paywall fires (`.settingsUpgrade`).

- [ ] **Step 3: Manual end-to-end (Pro tier)**

In `EntitlementService`, temporarily call `setEntitlement(.lifetime)` on first appear (or run the StoreKit Test purchase flow). Repeat the 7 scenarios above; all should succeed without a paywall, and exports should NOT have the watermark voiceover.

Restore the dev override before commit.

- [ ] **Step 4: Verify FAIL=5 baseline + commit any final tweaks**

If the manual smoke surfaced any bugs, fix + commit each as its own narrow `fix(subscription): ...` commit. Don't bundle into Chunk 6's commit.

- [ ] **Step 5: Hand off to `superpowers:finishing-a-development-branch`**

Branch is `main`. The skill will likely just verify state and confirm "ready to ship" — no merge or PR needed since work landed directly on main.

---

## Notes for the implementer

- **Watch the `entitlementService.isPro` callsites for stale reads.** Because `EntitlementService` is `@Observable`, SwiftUI views re-render when `currentEntitlement` changes — but a view-model that captured `isPro` at init won't. Always read it fresh inside method bodies, not via stored properties.
- **`PaywallTriggerCoordinator` is NOT consulted in this sub-project.** Each gate just sets `paywallReason` and lets `.paywall(reason:)` present the sheet. Sub-project 3 will wrap the binding in a coordinator-aware modifier so the throttling rules (`hasShownPaywallThisSession`, dismiss-count) apply. For now, every gate event surfaces a paywall — that's intentional, since beta testers need to see the paywall trigger reliably to give feedback.
- **The shared `.hitLengthCap` reason for clip-count gates is a Sub-project 2 compromise.** If beta feedback is "the clip-count paywall feels confusing," Sub-project 3 should add `.hitClipCountCap` to `PaywallReason` and split.
- **The `say -v Samantha` command in Task 5.1** assumes macOS. The asset is generated once and committed; CI should not regenerate it.
