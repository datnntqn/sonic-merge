# Monetization Sub-project 4 — Reviews + Social Proof Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire `SKStoreReviewController.requestReview(in:)` at moments of demonstrated user value, filtered by a 3-emoji mood-check sheet so unhappy users never reach Apple's rating prompt — preserving star average.

**Architecture:** Three new files in `Features/Reviews/` (`ReviewMetricsStore`, `ReviewPromptCoordinator`, `MoodCheckSheet`) + a `.moodCheckSheet(...)` modifier matching Sub-project 3's `.paywall(reason:)` pattern. Wired post-export at three sites (Smart Cut, Denoise, Merge). Mutex with paywall via existing `PaywallTriggerCoordinator.hasShownPaywallThisSession`.

**Tech Stack:** Swift 6, SwiftUI, `@Observable`, `StoreKit.SKStoreReviewController`, `UserDefaults`, Swift Testing.

**Spec source:** `docs/superpowers/specs/2026-05-07-reviews-and-social-proof-design.md`.

**Estimated scope:** ~150 LOC new + ~30 modified across 3 export sites + ~80 LOC tests. 3 chunks, ~4 hours focused work.

---

## Pre-flight

- [ ] **Step 1: Confirm Sub-projects 1-3 baseline + spec exists**

```bash
git log --oneline | head -5
```

You should see `cdd0af7 docs(spec): monetization sub-project 4 — reviews + social proof` near HEAD plus Sub-project 3 commits (`195bab1`, `36877c4`, `1e56c9e`). If not, abort.

- [ ] **Step 2: Confirm FAIL=5 baseline**

```bash
rm -rf /Users/datnnt/Library/Developer/Xcode/DerivedData/SonicMerge-ffrtspafwgzstsgbvhypcerpzcpx/Logs/Test 2>/dev/null
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5` with canonical baseline names. Anything else means Sub-project 3 regressed — fix first.

---

## Chunk 1: `ReviewMetricsStore` + `ReviewPromptCoordinator`

**Why first:** Pure logic + persistence layer, no UI dependencies. TDD-friendly. Land it before any view code so the coordinator's API is stable when the views consume it.

### Task 1.1: ReviewMetricsStore

**Files:**
- Create: `SonicMerge/Features/Reviews/Services/ReviewMetricsStore.swift`
- Create: `SonicMergeTests/Features/Reviews/ReviewMetricsStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `SonicMergeTests/Features/Reviews/ReviewMetricsStoreTests.swift`:

```swift
import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct ReviewMetricsStoreTests {

    private func freshStore() -> ReviewMetricsStore {
        let suite = "ReviewMetricsStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return ReviewMetricsStore(defaults: defaults)
    }

    @Test func freshStoreHasZeroExports() {
        let store = freshStore()
        #expect(store.exportCount == 0)
    }

    @Test func incrementExportPersists() {
        let store = freshStore()
        store.incrementExportCount()
        store.incrementExportCount()
        store.incrementExportCount()
        #expect(store.exportCount == 3)
    }

    @Test func installDateInitializedOnFirstRead() {
        let store = freshStore()
        let now = Date()
        let installed = store.installDate
        #expect(abs(installed.timeIntervalSince(now)) < 5.0, "Install date should be ~now on first read")
    }

    @Test func installDatePersistsAfterFirstRead() {
        let suite = "ReviewMetricsStoreInstallDateTest-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store1 = ReviewMetricsStore(defaults: defaults)
        let date1 = store1.installDate
        // New instance, same defaults → should read the persisted date
        let store2 = ReviewMetricsStore(defaults: defaults)
        #expect(store2.installDate == date1)
    }

    @Test func lastPromptDateNilByDefault() {
        let store = freshStore()
        #expect(store.lastPromptDate == nil)
    }

    @Test func setLastPromptDatePersists() {
        let store = freshStore()
        let now = Date()
        store.lastPromptDate = now
        #expect(store.lastPromptDate == now)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail (compile error)**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SonicMergeTests/ReviewMetricsStoreTests test 2>&1 | tail -10
```

Expected: compile error — `ReviewMetricsStore` doesn't exist yet.

- [ ] **Step 3: Implement the store**

Create `SonicMerge/Features/Reviews/Services/ReviewMetricsStore.swift`:

```swift
import Foundation

/// Persistence layer for review-prompt gating metrics. UserDefaults-backed.
/// `installDate` lazy-initializes on first read so it tracks "first-app-open"
/// rather than "binary install" — better UX semantics for cooldown reasoning.
@MainActor
final class ReviewMetricsStore {

    private enum Key {
        static let installDate = "ReviewMetrics.installDate"
        static let exportCount = "ReviewMetrics.exportCount"
        static let lastPromptDate = "ReviewMetrics.lastPromptDate"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var installDate: Date {
        if let stored = defaults.object(forKey: Key.installDate) as? Date {
            return stored
        }
        let now = Date()
        defaults.set(now, forKey: Key.installDate)
        return now
    }

    var exportCount: Int {
        defaults.integer(forKey: Key.exportCount)
    }

    func incrementExportCount() {
        defaults.set(exportCount + 1, forKey: Key.exportCount)
    }

    var lastPromptDate: Date? {
        get { defaults.object(forKey: Key.lastPromptDate) as? Date }
        set { defaults.set(newValue, forKey: Key.lastPromptDate) }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SonicMergeTests/ReviewMetricsStoreTests test 2>&1 | grep -E "passed|failed" | head -10
```

Expected: 6 tests pass.

### Task 1.2: ReviewPromptCoordinator

**Files:**
- Create: `SonicMerge/Features/Reviews/Services/ReviewPromptCoordinator.swift`
- Create: `SonicMergeTests/Features/Reviews/ReviewPromptCoordinatorTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `SonicMergeTests/Features/Reviews/ReviewPromptCoordinatorTests.swift`:

```swift
import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct ReviewPromptCoordinatorTests {

    private func freshCoordinator(
        installedDaysAgo: Int = 5,
        paywallShown: Bool = false
    ) -> (ReviewPromptCoordinator, ReviewMetricsStore, PaywallTriggerCoordinator) {
        let suite = "ReviewCoordTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = ReviewMetricsStore(defaults: defaults)
        // Force install date by reading once, then overwriting via direct key write
        _ = store.installDate
        let earlier = Date().addingTimeInterval(-86400 * Double(installedDaysAgo))
        defaults.set(earlier, forKey: "ReviewMetrics.installDate")
        let paywall = PaywallTriggerCoordinator(defaults: defaults)
        if paywallShown { paywall.markPresented(.hitDailyCap) }
        let coord = ReviewPromptCoordinator(metrics: store, paywallCoordinator: paywall)
        return (coord, store, paywall)
    }

    @Test func belowExportThresholdSuppresses() {
        let (coord, store, _) = freshCoordinator()
        #expect(coord.shouldPromptNow() == false)  // 0 exports
        store.incrementExportCount()
        #expect(coord.shouldPromptNow() == false)  // 1
        store.incrementExportCount()
        #expect(coord.shouldPromptNow() == false)  // 2
    }

    @Test func threeExportsAndOldEnoughInstallAllows() {
        let (coord, store, _) = freshCoordinator(installedDaysAgo: 5)
        for _ in 0..<3 { store.incrementExportCount() }
        #expect(coord.shouldPromptNow() == true)
    }

    @Test func recentInstallSuppresses() {
        let (coord, store, _) = freshCoordinator(installedDaysAgo: 1)
        for _ in 0..<5 { store.incrementExportCount() }
        #expect(coord.shouldPromptNow() == false)
    }

    @Test func paywallShownSessionSuppresses() {
        let (coord, store, _) = freshCoordinator(installedDaysAgo: 5, paywallShown: true)
        for _ in 0..<5 { store.incrementExportCount() }
        #expect(coord.shouldPromptNow() == false)
    }

    @Test func cooldownActiveSuppresses() {
        let (coord, store, _) = freshCoordinator(installedDaysAgo: 100)
        for _ in 0..<5 { store.incrementExportCount() }
        store.lastPromptDate = Date().addingTimeInterval(-86400 * 30)  // 30d ago
        #expect(coord.shouldPromptNow() == false)
    }

    @Test func cooldownExpiredAllows() {
        let (coord, store, _) = freshCoordinator(installedDaysAgo: 200)
        for _ in 0..<5 { store.incrementExportCount() }
        store.lastPromptDate = Date().addingTimeInterval(-86400 * 100)  // 100d ago
        #expect(coord.shouldPromptNow() == true)
    }

    @Test func recordExportIncrementsCount() {
        let (coord, store, _) = freshCoordinator()
        coord.recordExport()
        #expect(store.exportCount == 1)
    }

    @Test func markPromptedSetsLastPromptDate() {
        let (coord, store, _) = freshCoordinator()
        let before = Date()
        coord.markPrompted()
        let after = Date()
        let stamp = store.lastPromptDate
        #expect(stamp != nil)
        #expect(stamp! >= before)
        #expect(stamp! <= after)
    }
}
```

- [ ] **Step 2: Implement the coordinator**

Create `SonicMerge/Features/Reviews/Services/ReviewPromptCoordinator.swift`:

```swift
import Foundation

/// Decides when to present the post-export mood-check sheet. Profile B
/// gating: install ≥ 3 days, exports ≥ 3, 90-day cooldown since last prompt,
/// no paywall shown this session (mutex with `PaywallTriggerCoordinator`).
@MainActor
@Observable
final class ReviewPromptCoordinator {

    enum Threshold {
        static let minInstallDays = 3
        static let minExportCount = 3
        static let cooldownDays = 90
    }

    private let metrics: ReviewMetricsStore
    private let paywallCoordinator: PaywallTriggerCoordinator

    init(metrics: ReviewMetricsStore, paywallCoordinator: PaywallTriggerCoordinator) {
        self.metrics = metrics
        self.paywallCoordinator = paywallCoordinator
    }

    func recordExport() {
        metrics.incrementExportCount()
    }

    func markPrompted() {
        metrics.lastPromptDate = Date()
    }

    func shouldPromptNow(now: Date = .init()) -> Bool {
        // Cheapest check first: paywall mutex.
        if paywallCoordinator.hasShownPaywallThisSession { return false }

        // Export-count threshold.
        if metrics.exportCount < Threshold.minExportCount { return false }

        // Install-age threshold.
        let installAge = now.timeIntervalSince(metrics.installDate)
        let minInstallSeconds = Double(Threshold.minInstallDays) * 86400
        if installAge < minInstallSeconds { return false }

        // Cooldown threshold (only applies if there's a prior prompt).
        if let last = metrics.lastPromptDate {
            let elapsed = now.timeIntervalSince(last)
            // Defensive: clock skew (last in future) → treat as "cooldown still active".
            if elapsed < 0 { return false }
            let cooldownSeconds = Double(Threshold.cooldownDays) * 86400
            if elapsed < cooldownSeconds { return false }
        }

        return true
    }
}
```

- [ ] **Step 3: Run tests**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SonicMergeTests/ReviewPromptCoordinatorTests test 2>&1 | grep -E "passed|failed" | head -10
```

Expected: 8 tests pass.

- [ ] **Step 4: Run full suite + commit Chunk 1**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`.

```bash
git add SonicMerge/Features/Reviews/Services/ReviewMetricsStore.swift \
        SonicMerge/Features/Reviews/Services/ReviewPromptCoordinator.swift \
        SonicMergeTests/Features/Reviews/ReviewMetricsStoreTests.swift \
        SonicMergeTests/Features/Reviews/ReviewPromptCoordinatorTests.swift
git commit -m "feat(reviews): ReviewMetricsStore + ReviewPromptCoordinator (Profile B gating)"
```

---

## Chunk 2: `MoodCheckSheet` view + modifier

**Why second:** Pure UI, no service wiring yet. Land it independently so the wire-in (Chunk 3) is just three small additions per call site.

### Task 2.1: MoodCheckSheet view

**Files:**
- Create: `SonicMerge/Features/Reviews/Views/MoodCheckSheet.swift`

The sheet itself is pure UI — three buttons, one per emoji. The caller's `onSelect` closure handles routing (😊 → SKStoreReviewController, 😐/😞 → just dismiss).

- [ ] **Step 1: Create the view**

```swift
import SwiftUI

/// Three-emoji mood-check sheet. Pure UI — `SKStoreReviewController` is
/// invoked by the caller's onSelect closure (keeps this view test-isolatable
/// and free of StoreKit dependency).
struct MoodCheckSheet: View {

    enum Mood: String, Sendable {
        case happy
        case neutral
        case sad
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.sonicMergeSemantic) private var semantic

    var onSelect: (Mood) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("How was that?")
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
                .padding(.top, 32)

            VStack(spacing: 12) {
                moodButton(.happy, emoji: "😊", label: "Loved it")
                moodButton(.neutral, emoji: "😐", label: "It was okay")
                moodButton(.sad, emoji: "😞", label: "Could be better")
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color(uiColor: semantic.surfaceBase))
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private func moodButton(_ mood: Mood, emoji: String, label: String) -> some View {
        Button {
            onSelect(mood)
            dismiss()
        } label: {
            HStack(spacing: 16) {
                Text(emoji).font(.system(size: 36))
                Text(label)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: semantic.surfaceCard))
            )
            .accessibilityIdentifier("MoodCheckSheet.\(mood.rawValue)")
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Build to confirm**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

### Task 2.2: `.moodCheckSheet(isPresented:onSelect:)` modifier

**Files:**
- Modify: `SonicMerge/Features/Reviews/Views/MoodCheckSheet.swift` (append the extension)

Mirror the `.paywall(reason:)` shape from Sub-project 3 — uniform modifier-based wiring at all 3 call sites.

- [ ] **Step 1: Append the modifier**

At the bottom of `MoodCheckSheet.swift`:

```swift
extension View {
    /// Presents the mood-check sheet when the binding is true. The caller's
    /// onSelect closure handles routing (e.g., 😊 → SKStoreReviewController).
    /// Use after a successful export when `ReviewPromptCoordinator.shouldPromptNow()`
    /// returned true.
    func moodCheckSheet(
        isPresented: Binding<Bool>,
        onSelect: @escaping (MoodCheckSheet.Mood) -> Void
    ) -> some View {
        sheet(isPresented: isPresented) {
            MoodCheckSheet(onSelect: onSelect)
        }
    }
}
```

- [ ] **Step 2: Build + commit Chunk 2**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

```bash
git add SonicMerge/Features/Reviews/Views/MoodCheckSheet.swift
git commit -m "feat(reviews): MoodCheckSheet view + .moodCheckSheet(isPresented:onSelect:) modifier"
```

---

## Chunk 3: Wire post-export at all 3 sites + inject coordinator

**Why last:** This is the integration moment. Each site picks up the coordinator from environment, calls `recordExport()` after success, and presents the sheet if eligible.

### Task 3.1: Inject `ReviewPromptCoordinator` from RootTabView

**Files:**
- Modify: `SonicMerge/App/RootTabView.swift`

- [ ] **Step 1: Add state property + env injection**

Find the existing `@State private var paywallCoordinator = PaywallTriggerCoordinator()` (line 34). Immediately after, add:

```swift
    @State private var reviewMetricsStore = ReviewMetricsStore()
    @State private var reviewPromptCoordinator: ReviewPromptCoordinator?
```

In `.onAppear` (find the existing init block ~line 96-105 where `mixingStationViewModel` is created), add:

```swift
            if reviewPromptCoordinator == nil {
                reviewPromptCoordinator = ReviewPromptCoordinator(
                    metrics: reviewMetricsStore,
                    paywallCoordinator: paywallCoordinator
                )
            }
```

Find the `.environment(\.paywallCoordinator, paywallCoordinator)` line (Sub-project 3 / Chunk 1 added it) and add immediately after:

```swift
            .environment(reviewPromptCoordinator ?? ReviewPromptCoordinator(
                metrics: reviewMetricsStore,
                paywallCoordinator: paywallCoordinator
            ))
```

(The fallback `?? ...` matches the `mixingStationViewModel` pattern — the `.onAppear` will populate the real instance before the user can interact, but fallback ensures the View always has *something*.)

- [ ] **Step 2: Build to confirm**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

### Task 3.2: Wire Smart Cut Session export

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Home/SmartCutSessionView.swift`

- [ ] **Step 1: Add review wiring**

Open `SmartCutSessionView.swift`. Near the top of the struct (alongside other `@Environment` declarations), add:

```swift
    @Environment(ReviewPromptCoordinator.self) private var reviewCoordinator
    @State private var showMoodCheckSheet = false
```

On the body, alongside the existing `.paywall(reason: $paywallReason)`, add:

```swift
        .moodCheckSheet(isPresented: $showMoodCheckSheet) { mood in
            handleMood(mood)
        }
```

Find the export-success completion handler (search for the closure that runs after `audioMerger.exportFile(...)` succeeds). Immediately after the user-facing success state is set, add:

```swift
                reviewCoordinator.recordExport()
                if reviewCoordinator.shouldPromptNow() {
                    reviewCoordinator.markPrompted()
                    showMoodCheckSheet = true
                }
```

Add the helper at the bottom of the struct:

```swift
    private func handleMood(_ mood: MoodCheckSheet.Mood) {
        guard mood == .happy else { return }
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
```

Add imports at top of file:

```swift
import StoreKit
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

### Task 3.3: Wire Denoise Session export

**Files:**
- Modify: `SonicMerge/Features/Denoising/Views/Home/DenoiseSessionView.swift`

- [ ] **Step 1: Apply the same pattern**

Same additions as Task 3.2 — `@Environment(ReviewPromptCoordinator.self)`, `@State var showMoodCheckSheet`, `.moodCheckSheet(...)`, success-handler wiring, `handleMood` helper, `import StoreKit`.

The key difference is the export-success site: in `DenoiseSessionView`, look for the closure that runs after the denoise-and-export pipeline completes successfully. Same 4-line addition (`recordExport / shouldPromptNow / markPrompted / showMoodCheckSheet = true`).

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

### Task 3.4: Wire Merge export

**Files:**
- Modify: `SonicMerge/Features/MixingStation/MixingStationView.swift`

- [ ] **Step 1: Apply the same pattern**

Same additions. Merge's export-success path runs through `MixingStationViewModel.exportClips(...)` — find the place where the `.success` Result branch is handled in the View and add the 4-line wiring there.

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

### Task 3.5: Run full suite + commit Chunk 3

- [ ] **Step 1: Run tests**

```bash
rm -rf /Users/datnnt/Library/Developer/Xcode/DerivedData/SonicMerge-ffrtspafwgzstsgbvhypcerpzcpx/Logs/Test 2>/dev/null
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5` (baseline preserved). 14 new tests added across `ReviewMetricsStoreTests` (6) + `ReviewPromptCoordinatorTests` (8). All passing.

- [ ] **Step 2: Commit**

```bash
git add SonicMerge/App/RootTabView.swift \
        SonicMerge/Features/SmartCut/Views/Home/SmartCutSessionView.swift \
        SonicMerge/Features/Denoising/Views/Home/DenoiseSessionView.swift \
        SonicMerge/Features/MixingStation/MixingStationView.swift
git commit -m "feat(reviews): wire post-export mood-check at SmartCut/Denoise/Merge sites"
```

---

## Final ship-readiness check

- [ ] **Step 1: Run full suite one last time**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5`.

- [ ] **Step 2: Manual smoke (Free tier, fresh install)**

1. Reset simulator (Erase All Content). Launch app. Onboarding → 🎉 paywall (Sub-project 3) → dismiss.
2. Make 3 successful Smart Cut exports across one session. NONE trigger MoodCheckSheet (installDate is today, < 3d threshold).
3. Inject debug `installDate = Date.now.addingTimeInterval(-86400 * 4)` (or just wait 3 days, or alter `installDate` via direct UserDefaults write in a debug build).
4. Make a 4th export → MoodCheckSheet presents.
5. Tap 😊 → Apple may (its choice) show system rating prompt. Sheet dismisses.
6. Make a 5th export same session → MoodCheckSheet does NOT re-present (cooldown active, lastPromptDate set).

- [ ] **Step 3: Manual smoke (paywall mutex)**

1. Reset simulator. Walk through onboarding → paywall fires. Dismiss.
2. (paywallCoordinator.hasShownPaywallThisSession is now true.)
3. Run an export. MoodCheckSheet does NOT present (mutex blocks).
4. Background app → foreground (resets paywallCoordinator session). Run another export → mutex no longer blocks; if other thresholds met (exports ≥ 3 etc.), MoodCheckSheet presents.

- [ ] **Step 4: Push to origin/main**

```bash
git push origin main
```

---

## Notes for the implementer

- **`SKStoreReviewController.requestReview(in:)` is fire-and-forget.** Apple decides whether to actually show the system rating prompt. Don't expect a callback — the app gets no signal whether the user rated, dismissed, or saw nothing at all.
- **`UIWindowScene` lookup** uses `UIApplication.shared.connectedScenes.first as? UIWindowScene`. Sufficient for v1 (CleanCut is iPhone-only single-window); revisit if iPad multi-window support comes later.
- **The 4-line wiring at each export site is intentionally identical.** Sub-project 5 (or future iteration) could lift this into a `.reviewPromptOnExport()` modifier — defer until rule of three is clearly met (we have exactly 3 sites today; refactor pressure low).
- **`installDate` is initialized lazily on first read.** A side effect: the very first read also writes to UserDefaults. In tests, ensure suite isolation (`UserDefaults(suiteName:)` per test) so tests don't pollute each other's install date.
- **No new tests for `MoodCheckSheet.swift`** — pure SwiftUI, no logic. Manual visual smoke in Step 2 above is sufficient for v1.
- **No tests for the wire-in points** at SmartCut/Denoise/Merge views. Same reason: trigger logic IS already tested at the coordinator level (Chunk 1). View-level integration is best validated by manual smoke, since SwiftUI body introspection is impractical in `xcodebuild`.
