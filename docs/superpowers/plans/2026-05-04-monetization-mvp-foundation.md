# Monetization Sub-Project 1: MVP Foundation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a working subscription system to CleanCut — Settings sheet reachable from a gear icon in each home toolbar, three IAP products wired via StoreKit 2, full-screen paywall (Variant A: annual default with toggle), Restore Purchases, Terms/Privacy links — but no feature gates and no automatic conversion-moment triggers yet. Ship-able to TestFlight as a "you can buy Pro from Settings" baseline.

**Architecture:** Native StoreKit 2 (no RevenueCat). One service layer (`EntitlementService` + `StoreKitClient` + `DailyUsageTracker` + `PaywallTriggerCoordinator`), one set of models (`Entitlement`, `ProFeature`, `SubscriptionProduct`), one paywall view. The rest of the app talks ONLY to `EntitlementService`. A new `Settings/` feature directory hosts the sheet content.

**Tech Stack:** Swift 6, SwiftUI, StoreKit 2 (`Product`, `Transaction`, `StoreKit.Storefront`), Swift Testing, `StoreKitTest` framework + `.storekit` configuration file for integration tests. iOS 17.0 deployment floor.

**Spec:** `docs/superpowers/specs/2026-05-04-monetization-design.md`

**Branch:** `main` (per ongoing user direction; auto-mode work).

**Out of scope (deferred to Sub-projects 2/3/4):**
- Feature gates (daily caps, length caps, watermark, format restrictions) — Sub-project 2
- Conversion-moment automatic triggers (post-onboarding, hit-the-cap, watermark export) — Sub-project 3
- In-app review flow (mood-check, feedback form) — Sub-project 4

After this sub-project, the paywall is reachable ONLY from Settings → "Upgrade to Pro" pill. That's intentional: it's the safest first ship, lets you smoke-test the StoreKit integration in TestFlight without aggressive surfacing, and gives you a baseline to A/B against when conversion moments wire up later.

---

## OQ-1 resolution: gear icon in toolbar (Option B)

**Decision:** Add a gear-icon toolbar button to all 3 home views (Smart Cut, Denoise, Merge). Tapping it presents `SettingsView` as a modal sheet. The existing `ThemeToggleButton` stays in the toolbar (theme is fast-access chrome; pushing it into Settings would be a 2-tap regression from today's 1-tap).

**Rationale:**
1. Preserves the 3-tab brand identity established in the recent rebrand. A 4th "Settings" tab would break the visual rhythm and read as utility-clutter against the headline 3 features.
2. Pattern matches iOS productivity apps (Things, Carrot Weather, Bear, Procreate) — gear in toolbar opens Settings sheet, no tab.
3. Theme toggle stays where it is (1-tap), gear adds Settings (2-tap for chrome that's accessed less often: Restore Purchases, Privacy, Upgrade).
4. Restore Purchases is rarely-used after first-time setup — it doesn't need top-level navigation.

**Toolbar layout:** title in center, `[gear icon] [theme toggle]` on the right. (Both on the right keeps the left side clear for back-chevrons in pushed views.)

---

## File structure (locked-in)

```
SonicMerge/Features/Subscription/             — NEW directory
├── Models/
│   ├── Entitlement.swift                     — .free / .pro(expirationDate) / .lifetime
│   ├── ProFeature.swift                      — .smartCutSession / .smartCutLength(seconds:) / etc.
│   └── SubscriptionProduct.swift             — wrapper around StoreKit Product
├── Services/
│   ├── EntitlementService.swift              — single source of truth (isPro, gate(_:))
│   ├── StoreKitClient.swift                  — wraps StoreKit Product / Transaction APIs
│   ├── DailyUsageTracker.swift               — UserDefaults-backed daily counter (used by Sub-project 2)
│   └── PaywallTriggerCoordinator.swift       — session-level throttling + dismiss counting
└── Views/
    ├── PaywallReason.swift                   — enum: .endOfOnboarding / .hitDailyCap / etc.
    ├── PaywallView.swift                     — full-sheet paywall (Variant A)
    ├── PaywallTrigger.swift                  — .paywall(reason:) view modifier
    └── RestorePurchasesButton.swift          — small text button used inside paywall + settings

SonicMerge/Features/Settings/                 — NEW directory
├── Views/
│   ├── SettingsView.swift                    — sheet content: account section, upgrade card, restore, links
│   ├── SettingsToolbarButton.swift           — gear icon for the home-view toolbars
│   ├── ProStatusCard.swift                   — top of Settings: shows Pro status / upgrade pill
│   └── SettingsRowLink.swift                 — reusable disclosure-indicator row for legal links

Configuration/                                — NEW directory
└── CleanCut.storekit                         — local IAP config for StoreKit Test (3 products + 7-day intro offer)
```

**Convention notes:**
- Project uses `PBXFileSystemSynchronizedRootGroup` (FileSystemSynchronized in pbxproj) — Xcode picks up new Swift files automatically. NO pbxproj edits needed for source files.
- The `.storekit` configuration file MUST be added to the project as a resource (it's NOT auto-discovered — it's used by Xcode's StoreKit testing harness, configured per-scheme).
- All new files use English comments per CLAUDE.md.
- New tests use Swift Testing (`import Testing`, `@Test`, `#expect`).

**Test files mirror source layout under `SonicMergeTests/Features/Subscription/` and `SonicMergeTests/Features/Settings/`.**

---

## Chunk 1: Models + StoreKit Configuration File

**Why first:** Models are pure data with no dependencies. The `.storekit` file is needed by every test that exercises the StoreKit client. Land both in one chunk to unblock everything else.

### Task 1.1: Create the Entitlement enum

**Files:**
- Create: `SonicMerge/Features/Subscription/Models/Entitlement.swift`
- Test: `SonicMergeTests/Features/Subscription/Models/EntitlementTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `SonicMergeTests/Features/Subscription/Models/EntitlementTests.swift`:

```swift
import Testing
import Foundation
@testable import SonicMerge

struct EntitlementTests {

    @Test func freeIsNotPro() {
        let e: Entitlement = .free
        #expect(e.isPro == false)
        #expect(e.isLifetime == false)
    }

    @Test func proWithFutureExpirationIsPro() {
        let e: Entitlement = .pro(expiresAt: Date(timeIntervalSinceNow: 86400))
        #expect(e.isPro == true)
        #expect(e.isLifetime == false)
    }

    @Test func proWithPastExpirationIsNotPro() {
        let e: Entitlement = .pro(expiresAt: Date(timeIntervalSinceNow: -1))
        #expect(e.isPro == false)
    }

    @Test func lifetimeIsAlwaysPro() {
        let e: Entitlement = .lifetime
        #expect(e.isPro == true)
        #expect(e.isLifetime == true)
    }

    @Test func displayLabelMatchesTier() {
        #expect(Entitlement.free.displayLabel == "Free")
        #expect(Entitlement.pro(expiresAt: Date(timeIntervalSinceNow: 86400)).displayLabel.contains("Pro"))
        #expect(Entitlement.lifetime.displayLabel == "Pro · Lifetime")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `set -o pipefail; xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SonicMergeTests/EntitlementTests test 2>&1 | tail -10`
Expected: FAIL — "Cannot find 'Entitlement' in scope"

- [ ] **Step 3: Implement `Entitlement.swift`**

Create `SonicMerge/Features/Subscription/Models/Entitlement.swift`:

```swift
import Foundation

/// Represents the user's current entitlement to Pro features. Computed
/// from StoreKit's `Transaction.currentEntitlements` async stream by
/// `EntitlementService`. Three cases plus a derived `isPro` boolean
/// that's the only thing most callsites care about.
///
/// `pro(expiresAt:)` distinguishes from `lifetime` because the UI shows
/// expiration date for subscribers but not for lifetime buyers.
enum Entitlement: Equatable, Sendable {
    case free
    case pro(expiresAt: Date)
    case lifetime

    /// True when the user can access Pro features right now. `pro` expires
    /// at `expiresAt` (Apple's grace period is handled by StoreKit before
    /// we get to this state — by the time we see `.expired`, it's truly
    /// expired). `lifetime` is always Pro.
    var isPro: Bool {
        switch self {
        case .free: return false
        case .pro(let expiresAt): return expiresAt > .now
        case .lifetime: return true
        }
    }

    var isLifetime: Bool {
        if case .lifetime = self { return true }
        return false
    }

    /// Used in Settings → "Account" section as the primary status label.
    var displayLabel: String {
        switch self {
        case .free: return "Free"
        case .pro(let expiresAt):
            let f = DateFormatter()
            f.dateStyle = .medium
            return "Pro · expires \(f.string(from: expiresAt))"
        case .lifetime: return "Pro · Lifetime"
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `set -o pipefail; xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SonicMergeTests/EntitlementTests test 2>&1 | tail -10`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add SonicMerge/Features/Subscription/Models/Entitlement.swift \
        SonicMergeTests/Features/Subscription/Models/EntitlementTests.swift
git commit -m "feat(subscription): Entitlement enum (.free / .pro / .lifetime)"
```

### Task 1.2: Create the ProFeature enum

**Files:**
- Create: `SonicMerge/Features/Subscription/Models/ProFeature.swift`
- Test: `SonicMergeTests/Features/Subscription/Models/ProFeatureTests.swift`

`ProFeature` enumerates every gate-able capability. `EntitlementService.gate(_:)` returns `.allowed` or `.requiresPro(reason:)` for each. Sub-project 2 uses these; Sub-project 1 only NEEDS the type to compile (the gate logic is added in Sub-project 2).

- [ ] **Step 1: Write the failing tests**

Create `SonicMergeTests/Features/Subscription/Models/ProFeatureTests.swift`:

```swift
import Testing
@testable import SonicMerge

struct ProFeatureTests {

    @Test func allCasesEnumerated() {
        // Just construct each case to verify the enum compiles + has the expected shape.
        // Sub-project 2 will exercise the actual gate semantics.
        let _: ProFeature = .smartCutSession
        let _: ProFeature = .smartCutLength(seconds: 600)
        let _: ProFeature = .denoiseSession
        let _: ProFeature = .denoiseLength(seconds: 600)
        let _: ProFeature = .mergeClipCount(count: 5)
        let _: ProFeature = .exportFormat(format: .m4a)
        let _: ProFeature = .removeWatermark
        let _: ProFeature = .customFillerLibrary
        let _: ProFeature = .backgroundProcessing
        #expect(true)  // compile-only test
    }

    @Test func equatableMatchesByCase() {
        #expect(ProFeature.smartCutSession == ProFeature.smartCutSession)
        #expect(ProFeature.smartCutLength(seconds: 600) == ProFeature.smartCutLength(seconds: 600))
        #expect(ProFeature.smartCutLength(seconds: 600) != ProFeature.smartCutLength(seconds: 300))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild ... -only-testing:SonicMergeTests/ProFeatureTests test 2>&1 | tail -5`
Expected: FAIL — "Cannot find 'ProFeature' in scope"

- [ ] **Step 3: Implement `ProFeature.swift`**

Create `SonicMerge/Features/Subscription/Models/ProFeature.swift`:

```swift
import Foundation

/// Every gate-able capability in the app. Used by
/// `EntitlementService.gate(_ feature: ProFeature) -> GateResult`.
/// Sub-project 1 introduces the type; Sub-project 2 wires the gate
/// semantics at each callsite.
///
/// The `seconds:` and `count:` payloads let gates be context-aware
/// without hardcoding limits inside the service (e.g., `.smartCutLength(600)`
/// for "user is trying to import a 10-min clip" — service compares to the
/// 5-min free cap and returns .requiresPro if exceeded).
enum ProFeature: Equatable, Hashable, Sendable {
    case smartCutSession
    case smartCutLength(seconds: TimeInterval)
    case denoiseSession
    case denoiseLength(seconds: TimeInterval)
    case mergeClipCount(count: Int)
    case exportFormat(format: ExportFormat)
    case removeWatermark
    case customFillerLibrary
    case backgroundProcessing

    enum ExportFormat: Equatable, Hashable, Sendable {
        case wav
        case m4a
        case mp3
    }
}

/// Returned by `EntitlementService.gate(_:)`. Sub-project 1 only declares the
/// type; Sub-project 2 returns specific reasons at gate sites.
enum GateResult: Equatable, Sendable {
    case allowed
    case requiresPro(reason: String)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild ... -only-testing:SonicMergeTests/ProFeatureTests test 2>&1 | tail -5`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add SonicMerge/Features/Subscription/Models/ProFeature.swift \
        SonicMergeTests/Features/Subscription/Models/ProFeatureTests.swift
git commit -m "feat(subscription): ProFeature enum + GateResult type"
```

### Task 1.3: Create SubscriptionProduct wrapper

**Files:**
- Create: `SonicMerge/Features/Subscription/Models/SubscriptionProduct.swift`

`SubscriptionProduct` wraps StoreKit's `Product` to give the paywall a stable, view-friendly shape. Doesn't add behavior — just maps `Product` → display values (price string, period label, savings calculation for the yearly plan).

- [ ] **Step 1: Write the failing tests**

Create `SonicMergeTests/Features/Subscription/Models/SubscriptionProductTests.swift`:

```swift
import Testing
@testable import SonicMerge

struct SubscriptionProductTests {

    @Test func tierMonthly() {
        let p = SubscriptionProduct(
            id: "com.cleancut.pro.monthly",
            displayPrice: "$4.99",
            tier: .monthly
        )
        #expect(p.periodLabel == "/mo")
        #expect(p.tier == .monthly)
    }

    @Test func tierYearly() {
        let p = SubscriptionProduct(
            id: "com.cleancut.pro.yearly",
            displayPrice: "$39.99",
            tier: .yearly
        )
        #expect(p.periodLabel == "/yr")
        #expect(p.tier == .yearly)
    }

    @Test func tierLifetime() {
        let p = SubscriptionProduct(
            id: "com.cleancut.pro.lifetime",
            displayPrice: "$79.99",
            tier: .lifetime
        )
        #expect(p.periodLabel == "once")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild ... -only-testing:SonicMergeTests/SubscriptionProductTests test`
Expected: FAIL — type not found.

- [ ] **Step 3: Implement `SubscriptionProduct.swift`**

```swift
import Foundation

/// View-friendly wrapper around StoreKit's `Product`. The paywall reads
/// only this type; `StoreKitClient` is the only place `Product` itself
/// appears. Decouples view code from StoreKit.
struct SubscriptionProduct: Equatable, Identifiable, Sendable {
    let id: String              // App Store product ID
    let displayPrice: String    // localized e.g. "$4.99" / "₹450" / "¥600"
    let tier: Tier

    enum Tier: Equatable, Sendable {
        case monthly
        case yearly
        case lifetime
    }

    var periodLabel: String {
        switch tier {
        case .monthly: return "/mo"
        case .yearly: return "/yr"
        case .lifetime: return "once"
        }
    }

    /// "$3.33/mo" for yearly, derived. Returns nil for non-yearly tiers.
    /// Plan-author note: this is a display-only convenience. For Apple
    /// guideline 3.1.2(a) compliance, the yearly capsule must show BOTH
    /// the actual yearly price (`displayPrice`) AND any "/mo equivalent"
    /// derived value if shown.
    var monthlyEquivalentPrice: String? {
        guard tier == .yearly else { return nil }
        // Display-only computation: parses the "$" + decimal value.
        // Real Apple-localized version reads from `Product.subscription.subscriptionPeriod`.
        return nil  // Computed by StoreKitClient when the actual Product is bridged in Task 2.2.
    }
}

/// Product IDs — match the App Store Connect IAP setup.
enum SubscriptionProductID {
    static let monthly = "com.cleancut.pro.monthly"
    static let yearly = "com.cleancut.pro.yearly"
    static let lifetime = "com.cleancut.pro.lifetime"
    static let allIDs: [String] = [monthly, yearly, lifetime]
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild ... -only-testing:SonicMergeTests/SubscriptionProductTests test`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add SonicMerge/Features/Subscription/Models/SubscriptionProduct.swift \
        SonicMergeTests/Features/Subscription/Models/SubscriptionProductTests.swift
git commit -m "feat(subscription): SubscriptionProduct view-model + product IDs"
```

### Task 1.4: Create CleanCut.storekit configuration file

**Files:**
- Create: `Configuration/CleanCut.storekit`

The `.storekit` file is a JSON config Xcode reads when running with the StoreKit Test scheme option enabled. It mocks the 3 products + the 7-day intro offer so we can run the paywall locally without App Store Connect setup. After App Store Connect products are configured, the `.storekit` file remains useful for local development + automated tests.

- [ ] **Step 1: Create `Configuration/` directory and the `.storekit` file**

```bash
mkdir -p Configuration
```

Create `Configuration/CleanCut.storekit` with this JSON content:

```json
{
  "identifier" : "9D6A8E5F-2E4B-4F2A-AC1D-8C3F0B0E5A4D",
  "nonRenewingSubscriptions" : [],
  "products" : [
    {
      "displayPrice" : "79.99",
      "familyShareable" : true,
      "internalID" : "com.cleancut.pro.lifetime",
      "localizations" : [
        {
          "description" : "Unlock all CleanCut Pro features forever — no recurring charge.",
          "displayName" : "CleanCut Pro · Lifetime",
          "locale" : "en_US"
        }
      ],
      "productID" : "com.cleancut.pro.lifetime",
      "referenceName" : "CleanCut Pro Lifetime",
      "type" : "NonConsumable"
    }
  ],
  "settings" : {
    "_compatibilityTimeRate" : 1,
    "_locale" : "en_US",
    "_storefront" : "USA",
    "_storeKitErrors" : []
  },
  "subscriptionGroups" : [
    {
      "id" : "21384721",
      "localizations" : [],
      "name" : "CleanCut Pro",
      "subscriptions" : [
        {
          "adHocOffers" : [],
          "codeOffers" : [],
          "displayPrice" : "4.99",
          "familyShareable" : true,
          "groupNumber" : 1,
          "internalID" : "com.cleancut.pro.monthly",
          "introductoryOffer" : {
            "internalID" : "free-trial-7d-monthly",
            "paymentMode" : "free",
            "subscriptionPeriod" : "P7D"
          },
          "localizations" : [
            {
              "description" : "Unlimited Smart Cut and Denoise. No watermarks. Files of any length.",
              "displayName" : "CleanCut Pro · Monthly",
              "locale" : "en_US"
            }
          ],
          "productID" : "com.cleancut.pro.monthly",
          "recurringSubscriptionPeriod" : "P1M",
          "referenceName" : "CleanCut Pro Monthly",
          "subscriptionGroupID" : "21384721",
          "type" : "RecurringSubscription"
        },
        {
          "adHocOffers" : [],
          "codeOffers" : [],
          "displayPrice" : "39.99",
          "familyShareable" : true,
          "groupNumber" : 2,
          "internalID" : "com.cleancut.pro.yearly",
          "introductoryOffer" : {
            "internalID" : "free-trial-7d-yearly",
            "paymentMode" : "free",
            "subscriptionPeriod" : "P7D"
          },
          "localizations" : [
            {
              "description" : "Unlimited Smart Cut and Denoise. Save 33% vs monthly. 7-day free trial.",
              "displayName" : "CleanCut Pro · Yearly",
              "locale" : "en_US"
            }
          ],
          "productID" : "com.cleancut.pro.yearly",
          "recurringSubscriptionPeriod" : "P1Y",
          "referenceName" : "CleanCut Pro Yearly",
          "subscriptionGroupID" : "21384721",
          "type" : "RecurringSubscription"
        }
      ]
    }
  ],
  "version" : {
    "major" : 4,
    "minor" : 0
  }
}
```

- [ ] **Step 2: Add the `.storekit` file to Xcode project**

In Xcode: drag `Configuration/CleanCut.storekit` into the project navigator (top-level, sibling to `SonicMerge/`). Confirm it's added with target membership unchecked (it's a config file, not a build artifact).

- [ ] **Step 3: Configure scheme to use the file**

Edit Scheme → Run → Options → "StoreKit Configuration" → select `CleanCut.storekit`.

This makes Product.products(for:) return the mock products in Debug builds and tests.

- [ ] **Step 4: Verify by building**

Run: `set -o pipefail; xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Configuration/CleanCut.storekit SonicMerge.xcodeproj/xcshareddata/xcschemes/*.xcscheme
git commit -m "feat(subscription): CleanCut.storekit local IAP config (3 products + 7-day intro)"
```

---

## Chunk 2: EntitlementService + StoreKitClient

**Why second:** All other code in this sub-project reads `EntitlementService`. The StoreKit wiring is the riskiest piece (async streams, `Transaction.updates`, sandbox quirks) so land it early under tests so later UI work proceeds with confidence.

### Task 2.1: EntitlementService skeleton with stubbed `gate(_:)`

**Files:**
- Create: `SonicMerge/Features/Subscription/Services/EntitlementService.swift`
- Test: `SonicMergeTests/Features/Subscription/Services/EntitlementServiceTests.swift`

In Sub-project 1, `gate(_:)` returns `.allowed` for everything (no caps wired yet — Sub-project 2 fills them in). The service exists primarily to expose `currentEntitlement` to the UI.

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct EntitlementServiceTests {

    @Test func defaultEntitlementIsFree() {
        let svc = EntitlementService()
        #expect(svc.currentEntitlement == .free)
        #expect(svc.isPro == false)
    }

    @Test func setEntitlementUpdatesIsPro() {
        let svc = EntitlementService()
        svc.setEntitlement(.lifetime)
        #expect(svc.currentEntitlement == .lifetime)
        #expect(svc.isPro == true)
    }

    @Test func gateAlwaysAllowedInSubProject1() {
        let svc = EntitlementService()
        // Free user — but Sub-project 1 doesn't gate yet. Always .allowed.
        #expect(svc.gate(.smartCutSession) == .allowed)
        #expect(svc.gate(.smartCutLength(seconds: 9999)) == .allowed)
        #expect(svc.gate(.removeWatermark) == .allowed)
    }
}
```

- [ ] **Step 2: Verify failing**

Run: `xcodebuild ... -only-testing:SonicMergeTests/EntitlementServiceTests test 2>&1 | tail -10`
Expected: FAIL — `EntitlementService` not in scope.

- [ ] **Step 3: Implement `EntitlementService.swift`**

```swift
import Foundation
import SwiftUI

/// Single source of truth for the user's Pro entitlement state. Other
/// code in the app talks to this — never to StoreKit directly. That
/// decoupling means swapping StoreKit for any other IAP backend
/// (RevenueCat, Adapty) only changes `StoreKitClient.swift`.
///
/// In Sub-project 1, `gate(_:)` always returns `.allowed` — no feature
/// caps yet. Sub-project 2 wires the actual gate semantics. Keep the
/// type stable so callsites added now don't need to change.
@MainActor
@Observable
final class EntitlementService {

    /// Process-wide singleton. The app injects this via `.environment`
    /// so previews and tests can inject a fake.
    static let shared = EntitlementService()

    private(set) var currentEntitlement: Entitlement = .free

    var isPro: Bool { currentEntitlement.isPro }

    init() {}

    /// Called by `StoreKitClient` when `Transaction.currentEntitlements`
    /// resolves or when `Transaction.updates` emits a new state.
    /// Public so tests can inject states without StoreKit.
    func setEntitlement(_ entitlement: Entitlement) {
        currentEntitlement = entitlement
    }

    /// Sub-project 1: always `.allowed`. Sub-project 2 will read daily
    /// usage trackers and the entitlement to return `.requiresPro(reason:)`
    /// at the right times.
    func gate(_ feature: ProFeature) -> GateResult {
        return .allowed
    }
}

private struct EntitlementServiceKey: EnvironmentKey {
    @MainActor static let defaultValue = EntitlementService.shared
}

extension EnvironmentValues {
    var entitlementService: EntitlementService {
        get { self[EntitlementServiceKey.self] }
        set { self[EntitlementServiceKey.self] = newValue }
    }
}
```

- [ ] **Step 4: Verify passing**

Run: `xcodebuild ... -only-testing:SonicMergeTests/EntitlementServiceTests test`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add SonicMerge/Features/Subscription/Services/EntitlementService.swift \
        SonicMergeTests/Features/Subscription/Services/EntitlementServiceTests.swift
git commit -m "feat(subscription): EntitlementService — single source of truth for Pro state"
```

### Task 2.2: StoreKitClient — load products, listen to transactions, restore

**Files:**
- Create: `SonicMerge/Features/Subscription/Services/StoreKitClient.swift`
- Test: `SonicMergeTests/Features/Subscription/Services/StoreKitClientTests.swift`

The hard one. Three responsibilities:
1. **Load products** — calls `Product.products(for: SubscriptionProductID.allIDs)` and bridges them to `SubscriptionProduct`
2. **Listen to entitlement changes** — runs a background `Task` that iterates `Transaction.updates` async stream, mapping transaction state → Entitlement, calling `EntitlementService.setEntitlement(_:)`
3. **Restore Purchases** — calls `AppStore.sync()` and re-queries `Transaction.currentEntitlements`

Tests use the StoreKit Test framework (`StoreKitTest` import) which works with the `.storekit` configuration from Task 1.4.

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Foundation
import StoreKit
import StoreKitTest
@testable import SonicMerge

@MainActor
struct StoreKitClientTests {

    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "CleanCut")
        session.disableDialogs = true
        session.clearTransactions()
        session.resetToDefaultState()
        return session
    }

    @Test func loadProductsReturnsThreeSKUs() async throws {
        let _ = try makeSession()
        let entitlements = EntitlementService()
        let client = StoreKitClient(entitlementService: entitlements)
        let products = try await client.loadProducts()
        #expect(products.count == 3)
        #expect(products.contains { $0.id == SubscriptionProductID.monthly })
        #expect(products.contains { $0.id == SubscriptionProductID.yearly })
        #expect(products.contains { $0.id == SubscriptionProductID.lifetime })
    }

    @Test func purchasingMonthlySetsEntitlementToPro() async throws {
        let session = try makeSession()
        let entitlements = EntitlementService()
        let client = StoreKitClient(entitlementService: entitlements)
        _ = try await client.loadProducts()

        try await client.purchase(productID: SubscriptionProductID.monthly)

        // The Transaction.updates listener should have fired by now.
        // Give it a tick to propagate.
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(entitlements.isPro == true)
        _ = session  // keep alive
    }

    @Test func restoreAfterClearedTransactionsKeepsEntitlement() async throws {
        let session = try makeSession()
        let entitlements = EntitlementService()
        let client = StoreKitClient(entitlementService: entitlements)
        _ = try await client.loadProducts()

        try await client.purchase(productID: SubscriptionProductID.lifetime)
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(entitlements.currentEntitlement == .lifetime)

        try await client.restore()
        #expect(entitlements.currentEntitlement == .lifetime)
        _ = session
    }
}
```

- [ ] **Step 2: Verify failing**

Run: `xcodebuild ... -only-testing:SonicMergeTests/StoreKitClientTests test`
Expected: FAIL — `StoreKitClient` not in scope.

- [ ] **Step 3: Implement `StoreKitClient.swift`**

```swift
import Foundation
import StoreKit

/// Thin wrapper around StoreKit 2. The ONE place in the app that imports
/// StoreKit. Bridges `Product` ↔ `SubscriptionProduct`, `Transaction` ↔
/// `Entitlement`, and exposes purchase / restore as async functions.
///
/// Owns a long-running `Task` that listens to `Transaction.updates` for
/// the lifetime of the app (started in `init`, kept alive via a stored
/// reference). Whenever a transaction transitions (purchase, expire,
/// revoke, refund), it re-resolves the user's current entitlement and
/// calls `EntitlementService.setEntitlement(_:)`.
@MainActor
final class StoreKitClient {

    enum StoreKitError: Error {
        case productNotLoaded(id: String)
        case purchaseFailed(reason: String)
        case userCancelled
        case verificationFailed
    }

    private let entitlementService: EntitlementService
    private var products: [String: Product] = [:]
    private var transactionListener: Task<Void, Never>?

    init(entitlementService: EntitlementService) {
        self.entitlementService = entitlementService
        self.transactionListener = Task { [weak self] in
            await self?.listenForTransactions()
        }
        // Resolve initial state on launch.
        Task { [weak self] in
            await self?.refreshCurrentEntitlement()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    /// Loads all 3 products from the App Store (or `.storekit` config in
    /// debug) and caches them. Returns view-friendly wrappers.
    func loadProducts() async throws -> [SubscriptionProduct] {
        let storeProducts = try await Product.products(for: SubscriptionProductID.allIDs)
        for p in storeProducts {
            products[p.id] = p
        }
        return storeProducts.compactMap { Self.bridgeToSubscriptionProduct($0) }
    }

    /// Purchases `productID`. On success, the `Transaction.updates`
    /// listener fires and updates `EntitlementService` automatically.
    func purchase(productID: String) async throws {
        guard let product = products[productID] else {
            throw StoreKitError.productNotLoaded(id: productID)
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                await refreshCurrentEntitlement()
            case .unverified:
                throw StoreKitError.verificationFailed
            }
        case .userCancelled:
            throw StoreKitError.userCancelled
        case .pending:
            // Apple SCA / parental approval flow — Transaction.updates will
            // fire later when resolved. Nothing to do now.
            break
        @unknown default:
            throw StoreKitError.purchaseFailed(reason: "Unknown StoreKit result")
        }
    }

    /// Restore Purchases — required by App Store guideline 3.1.1.
    func restore() async throws {
        try await AppStore.sync()
        await refreshCurrentEntitlement()
    }

    // MARK: - Private

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            guard case .verified(let transaction) = update else { continue }
            await transaction.finish()
            await refreshCurrentEntitlement()
        }
    }

    /// Iterates `Transaction.currentEntitlements` and reduces to one
    /// `Entitlement`. Lifetime trumps subscription; latest expiration
    /// wins between subscription transactions.
    private func refreshCurrentEntitlement() async {
        var resolved: Entitlement = .free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            switch transaction.productID {
            case SubscriptionProductID.lifetime:
                resolved = .lifetime
            case SubscriptionProductID.monthly, SubscriptionProductID.yearly:
                if case .lifetime = resolved { continue } // lifetime trumps
                if let expiration = transaction.expirationDate, expiration > .now {
                    if case .pro(let existing) = resolved, existing >= expiration {
                        continue // keep the later one
                    }
                    resolved = .pro(expiresAt: expiration)
                }
            default:
                continue
            }
        }
        entitlementService.setEntitlement(resolved)
    }

    static func bridgeToSubscriptionProduct(_ product: Product) -> SubscriptionProduct? {
        let tier: SubscriptionProduct.Tier
        switch product.id {
        case SubscriptionProductID.monthly: tier = .monthly
        case SubscriptionProductID.yearly: tier = .yearly
        case SubscriptionProductID.lifetime: tier = .lifetime
        default: return nil
        }
        return SubscriptionProduct(
            id: product.id,
            displayPrice: product.displayPrice,
            tier: tier
        )
    }
}
```

- [ ] **Step 4: Verify passing**

Run: `xcodebuild ... -only-testing:SonicMergeTests/StoreKitClientTests test`
Expected: PASS (3 tests). If `SKTestSession` initialization fails with "configuration not found," verify the `.storekit` file is in the project AND added to the test target's resources.

- [ ] **Step 5: Run full suite — confirm FAIL=5 baseline**

Run: `set -o pipefail; xcodebuild ... -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3`
Then: `echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"`
Expected: `FAIL=5` (baseline preserved).

- [ ] **Step 6: Commit**

```bash
git add SonicMerge/Features/Subscription/Services/StoreKitClient.swift \
        SonicMergeTests/Features/Subscription/Services/StoreKitClientTests.swift
git commit -m "feat(subscription): StoreKitClient — products, purchase, restore, transaction listener"
```

---

## Chunk 3: DailyUsageTracker + PaywallTriggerCoordinator

**Why third:** These two services are independent of StoreKit but depend on the model types. Land them before the paywall view so the view can read coordinator state for "should this paywall be shown."

### Task 3.1: DailyUsageTracker

**Files:**
- Create: `SonicMerge/Features/Subscription/Services/DailyUsageTracker.swift`
- Test: `SonicMergeTests/Features/Subscription/Services/DailyUsageTrackerTests.swift`

Tracks "N Smart Cuts today" and "N Denoise today" gates. UserDefaults-backed: stores counts keyed by ISO-8601 date. New day = counter resets automatically because the key changes. Sub-project 1 introduces it; Sub-project 2 reads it from `EntitlementService.gate(_:)`.

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Foundation
@testable import SonicMerge

struct DailyUsageTrackerTests {

    private func freshTracker() -> (DailyUsageTracker, UserDefaults) {
        let suite = "DailyUsageTrackerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let tracker = DailyUsageTracker(
            defaults: defaults,
            calendar: Calendar(identifier: .gregorian),
            dateProvider: { Date(timeIntervalSince1970: 1714824000) }  // 2024-05-04
        )
        return (tracker, defaults)
    }

    @Test func defaultCountIsZero() {
        let (tracker, _) = freshTracker()
        #expect(tracker.count(for: .smartCut) == 0)
        #expect(tracker.count(for: .denoise) == 0)
    }

    @Test func incrementBumpsCount() {
        let (tracker, _) = freshTracker()
        tracker.increment(.smartCut)
        tracker.increment(.smartCut)
        #expect(tracker.count(for: .smartCut) == 2)
        #expect(tracker.count(for: .denoise) == 0)
    }

    @Test func newDayResetsCount() {
        let suite = "DailyUsageTrackerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let calendar = Calendar(identifier: .gregorian)
        var fakeDate = Date(timeIntervalSince1970: 1714824000)  // 2024-05-04
        let dateProvider: () -> Date = { fakeDate }
        let tracker = DailyUsageTracker(
            defaults: defaults,
            calendar: calendar,
            dateProvider: dateProvider
        )
        tracker.increment(.smartCut)
        tracker.increment(.smartCut)
        #expect(tracker.count(for: .smartCut) == 2)
        // Advance the clock by 24h
        fakeDate = Date(timeIntervalSince1970: 1714910400)  // 2024-05-05
        #expect(tracker.count(for: .smartCut) == 0)
    }
}
```

- [ ] **Step 2: Verify failing**

Run: `xcodebuild ... -only-testing:SonicMergeTests/DailyUsageTrackerTests test`
Expected: FAIL — type not in scope.

- [ ] **Step 3: Implement `DailyUsageTracker.swift`**

```swift
import Foundation

/// Tracks daily usage counters per AI feature. UserDefaults-backed. The
/// "today" key changes at midnight (local calendar), so counts reset
/// implicitly without us writing reset logic. Date and calendar are
/// injectable so tests can fake "tomorrow."
final class DailyUsageTracker {

    enum Feature: String, Sendable {
        case smartCut = "smartCut"
        case denoise = "denoise"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let dateProvider: () -> Date

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.dateProvider = dateProvider
    }

    func count(for feature: Feature) -> Int {
        defaults.integer(forKey: key(for: feature))
    }

    func increment(_ feature: Feature) {
        let k = key(for: feature)
        defaults.set(defaults.integer(forKey: k) + 1, forKey: k)
    }

    private func key(for feature: Feature) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: dateProvider())
        let dateKey = "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        return "DailyUsage.\(feature.rawValue).\(dateKey)"
    }
}
```

- [ ] **Step 4: Verify passing**

Run: `xcodebuild ... -only-testing:SonicMergeTests/DailyUsageTrackerTests test`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add SonicMerge/Features/Subscription/Services/DailyUsageTracker.swift \
        SonicMergeTests/Features/Subscription/Services/DailyUsageTrackerTests.swift
git commit -m "feat(subscription): DailyUsageTracker — UserDefaults-backed daily counter"
```

### Task 3.2: PaywallTriggerCoordinator

**Files:**
- Create: `SonicMerge/Features/Subscription/Views/PaywallReason.swift`
- Create: `SonicMerge/Features/Subscription/Services/PaywallTriggerCoordinator.swift`
- Test: `SonicMergeTests/Features/Subscription/Services/PaywallTriggerCoordinatorTests.swift`

Three jobs:
1. Track per-`PaywallReason` dismiss-count in UserDefaults
2. Hold a session-scoped `hasShownPaywallThisSession: Bool` flag
3. Expose `shouldPresent(_:)` that returns false when (a) dismiss-count exceeds threshold, or (b) the session has already shown a paywall

Settings-entry paywall (`reason == .settingsUpgrade`) is exempt — the user explicitly tapped Upgrade, no throttling.

- [ ] **Step 1: Create `PaywallReason.swift`**

```swift
import Foundation

/// Why the paywall is being presented. Used by `PaywallTriggerCoordinator`
/// to throttle aggressive surfacing and by `PaywallView` to set the
/// header copy.
enum PaywallReason: String, Sendable {
    /// User just finished onboarding step 5 (Smart Cut applied to sample).
    /// Highest-converting moment. Sub-project 3 wires this.
    case endOfOnboarding

    /// User tried to do a 4th Smart Cut/Denoise today. Sub-project 3 wires this.
    case hitDailyCap

    /// User imported a clip exceeding the free length cap. Sub-project 3 wires this.
    case hitLengthCap

    /// User toggled "Remove watermark" in the Export sheet. Sub-project 3 wires this.
    case watermarkExport

    /// User tapped "Upgrade to Pro" from Settings. Always shown — no throttling.
    case settingsUpgrade

    /// `Transaction.updates` listener detected `.expired`/`.revoked`.
    /// Sub-project 3 wires this. Highest re-conversion probability.
    case trialExpired

    /// True when this trigger should bypass session-and-dismiss throttling
    /// (user explicitly asked for the paywall).
    var bypassesThrottle: Bool {
        switch self {
        case .settingsUpgrade: return true
        default: return false
        }
    }
}
```

- [ ] **Step 2: Write the failing tests**

```swift
import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct PaywallTriggerCoordinatorTests {

    private func freshCoordinator() -> (PaywallTriggerCoordinator, UserDefaults) {
        let suite = "PaywallTriggerCoordinatorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let coord = PaywallTriggerCoordinator(defaults: defaults)
        return (coord, defaults)
    }

    @Test func defaultShouldPresent() {
        let (coord, _) = freshCoordinator()
        #expect(coord.shouldPresent(.endOfOnboarding) == true)
    }

    @Test func sessionFlagBlocksSecondPresent() {
        let (coord, _) = freshCoordinator()
        coord.markPresented(.endOfOnboarding)
        #expect(coord.shouldPresent(.hitDailyCap) == false)
    }

    @Test func settingsUpgradeBypassesSessionFlag() {
        let (coord, _) = freshCoordinator()
        coord.markPresented(.endOfOnboarding)
        // .settingsUpgrade ignores throttling — user explicitly tapped Upgrade.
        #expect(coord.shouldPresent(.settingsUpgrade) == true)
    }

    @Test func dismissCountReachesThreshold() {
        let (coord, _) = freshCoordinator()
        // Dismissing the same reason 5 times suppresses it.
        for _ in 0..<5 { coord.recordDismiss(.hitDailyCap) }
        #expect(coord.shouldPresent(.hitDailyCap) == false)
    }

    @Test func differentReasonNotAffectedByDismissCount() {
        let (coord, _) = freshCoordinator()
        for _ in 0..<5 { coord.recordDismiss(.hitDailyCap) }
        // Different reason still surfaces.
        #expect(coord.shouldPresent(.endOfOnboarding) == true)
    }

    @Test func resetSessionClearsFlag() {
        let (coord, _) = freshCoordinator()
        coord.markPresented(.endOfOnboarding)
        coord.resetSession()
        #expect(coord.shouldPresent(.hitDailyCap) == true)
    }
}
```

- [ ] **Step 3: Verify failing**

Run: `xcodebuild ... -only-testing:SonicMergeTests/PaywallTriggerCoordinatorTests test`
Expected: FAIL — type not in scope.

- [ ] **Step 4: Implement `PaywallTriggerCoordinator.swift`**

```swift
import Foundation

/// Decides whether a paywall should actually be presented for a given
/// `PaywallReason`. Two layers of throttling:
///
/// 1. Session-level: once any paywall has been shown in this app launch,
///    no other (non-bypass) paywalls fire until next launch. Prevents
///    "user dismissed paywall on screen A, then tapped feature B and saw
///    another paywall instantly" annoyance.
///
/// 2. Per-reason dismiss count (persisted to UserDefaults): if a user has
///    dismissed the .hitDailyCap paywall 5 times across all sessions, we
///    stop showing it (Apple may flag aggressive re-prompting). Refreshes
///    only when the user upgrades to Pro (next sub-project).
///
/// `.settingsUpgrade` bypasses both — the user explicitly tapped Upgrade.
@MainActor
@Observable
final class PaywallTriggerCoordinator {

    /// 5 dismissals of the same reason → stop offering it.
    static let dismissThreshold = 5

    private let defaults: UserDefaults
    private(set) var hasShownPaywallThisSession: Bool = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func shouldPresent(_ reason: PaywallReason) -> Bool {
        if reason.bypassesThrottle { return true }
        if hasShownPaywallThisSession { return false }
        if dismissCount(for: reason) >= Self.dismissThreshold { return false }
        return true
    }

    func markPresented(_ reason: PaywallReason) {
        hasShownPaywallThisSession = true
    }

    func recordDismiss(_ reason: PaywallReason) {
        let key = dismissCountKey(for: reason)
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
    }

    /// Reset on cold launch / scenePhase becoming .background → .active
    /// transition. Caller hooks via SonicMergeApp.onChange(of: scenePhase).
    func resetSession() {
        hasShownPaywallThisSession = false
    }

    // MARK: - Private

    private func dismissCount(for reason: PaywallReason) -> Int {
        defaults.integer(forKey: dismissCountKey(for: reason))
    }

    private func dismissCountKey(for reason: PaywallReason) -> String {
        "PaywallTriggerCoordinator.dismissCount.\(reason.rawValue)"
    }
}
```

- [ ] **Step 5: Verify passing + full suite**

Run targeted: `xcodebuild ... -only-testing:SonicMergeTests/PaywallTriggerCoordinatorTests test`
Expected: PASS (6 tests).

Run full suite: `set -o pipefail; xcodebuild ... -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3 && echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"`
Expected: `FAIL=5`.

- [ ] **Step 6: Commit**

```bash
git add SonicMerge/Features/Subscription/Views/PaywallReason.swift \
        SonicMerge/Features/Subscription/Services/PaywallTriggerCoordinator.swift \
        SonicMergeTests/Features/Subscription/Services/PaywallTriggerCoordinatorTests.swift
git commit -m "feat(subscription): PaywallTriggerCoordinator — session + per-reason throttling"
```

---

## Chunk 4: Paywall view (Variant A)

**Why fourth:** The visual surface. Depends on `EntitlementService`, `StoreKitClient`, `SubscriptionProduct`. Single large view file (~250 lines) but logically self-contained.

### Task 4.1: PaywallView (Variant A — annual default with toggle)

**Files:**
- Create: `SonicMerge/Features/Subscription/Views/PaywallView.swift`
- Create: `SonicMerge/Features/Subscription/Views/PaywallTrigger.swift`
- Create: `SonicMerge/Features/Subscription/Views/RestorePurchasesButton.swift`
- Test: `SonicMergeTests/Features/Subscription/Views/PaywallViewTests.swift`

Implements the paywall mockup approved during brainstorming (Variant A). Reads products via `StoreKitClient.loadProducts()`, pricing toggle controls which `SubscriptionProduct.tier` is selected, sticky CTA at bottom, Restore button + legal links in footer.

The testimonial slot for Sub-project 1 is a placeholder array of 3 hardcoded `TestimonialQuote` values (Sub-project 4 replaces these with real quotes).

- [ ] **Step 1: Write the failing render-only test**

```swift
import Testing
import SwiftUI
@testable import SonicMerge

@MainActor
struct PaywallViewTests {

    @Test func rendersInLightMode() {
        let view = PaywallView(reason: .settingsUpgrade)
            .environment(\.sonicMergeSemantic, .resolved(colorScheme: .light, preference: .light))
        let renderer = ImageRenderer(content: view.frame(width: 390, height: 800))
        renderer.scale = 1
        #expect(renderer.uiImage != nil)
    }

    @Test func rendersInDarkMode() {
        let view = PaywallView(reason: .settingsUpgrade)
            .environment(\.sonicMergeSemantic, .resolved(colorScheme: .dark, preference: .dark))
        let renderer = ImageRenderer(content: view.frame(width: 390, height: 800))
        renderer.scale = 1
        #expect(renderer.uiImage != nil)
    }

    @Test func rendersAllReasons() {
        let reasons: [PaywallReason] = [.endOfOnboarding, .hitDailyCap, .hitLengthCap, .watermarkExport, .settingsUpgrade, .trialExpired]
        for reason in reasons {
            let view = PaywallView(reason: reason)
                .environment(\.sonicMergeSemantic, .resolved(colorScheme: .dark, preference: .dark))
            let renderer = ImageRenderer(content: view.frame(width: 390, height: 800))
            renderer.scale = 1
            #expect(renderer.uiImage != nil, "Failed to render reason: \(reason)")
        }
    }
}
```

- [ ] **Step 2: Verify failing**

Run: `xcodebuild ... -only-testing:SonicMergeTests/PaywallViewTests test`
Expected: FAIL — `PaywallView` not in scope.

- [ ] **Step 3: Implement `RestorePurchasesButton.swift`**

```swift
import SwiftUI

/// Small text button used inside the paywall footer + Settings.
/// Calls `StoreKitClient.restore()`. Shows a brief inline spinner while
/// restoring. Apple guideline 3.1.1 requires this be visible on the
/// paywall and somewhere in Settings.
struct RestorePurchasesButton: View {

    @Environment(\.sonicMergeSemantic) private var semantic

    @Binding var isRestoring: Bool
    let onRestore: () async throws -> Void

    var body: some View {
        Button {
            Task {
                isRestoring = true
                defer { isRestoring = false }
                try? await onRestore()
            }
        } label: {
            if isRestoring {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color(uiColor: semantic.textSecondary))
            } else {
                Text("Restore Purchases")
                    .font(.footnote)
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
            }
        }
        .accessibilityLabel("Restore Purchases")
    }
}
```

- [ ] **Step 4: Implement `PaywallTrigger.swift` view modifier**

```swift
import SwiftUI

/// Convenience modifier: present a `PaywallView` as a sheet bound to a
/// `PaywallReason?`. Sub-projects 3+ add wrappers that consult the
/// `PaywallTriggerCoordinator` before calling the underlying paywall(reason:)
/// modifier. Sub-project 1 only needs the modifier itself (Settings calls it).
extension View {
    func paywall(reason: Binding<PaywallReason?>) -> some View {
        self.sheet(item: reason) { actual in
            PaywallView(reason: actual)
                .interactiveDismissDisabled(false)
        }
    }
}

extension PaywallReason: Identifiable {
    var id: String { rawValue }
}
```

- [ ] **Step 5: Implement `PaywallView.swift`**

The big one. ~250 lines. Structure mirrors the Variant A mockup approved in brainstorming.

```swift
import SwiftUI
import StoreKit

/// Variant A paywall: annual default + toggle. Approved in brainstorming
/// at `docs/superpowers/specs/2026-05-04-monetization-design.md` §"Paywall UI".
///
/// Apple requirements (guidelines 3.1.1, 3.1.2, 5.1.1):
/// - Restore Purchases visible
/// - Plain-language price + period + auto-renew + cancel-anytime
/// - Terms + Privacy links
struct PaywallView: View {

    let reason: PaywallReason

    @Environment(\.dismiss) private var dismiss
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(EntitlementService.self) private var entitlementService

    @State private var selectedTier: SubscriptionProduct.Tier = .yearly
    @State private var products: [SubscriptionProduct] = []
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var purchaseError: String?

    /// `StoreKitClient` is created here for Sub-project 1 simplicity. In
    /// Sub-project 3+ it should be hoisted to app-level via @Environment
    /// or a process-wide store.
    @State private var client: StoreKitClient?

    private static let testimonials: [TestimonialQuote] = [
        TestimonialQuote(stars: 5, quote: "Cleaned a 45-min interview in 30 seconds. My old workflow took 2 hours.", author: "Jamie, podcast editor"),
        TestimonialQuote(stars: 5, quote: "On-device means I can clean voice memos on a flight. Game-changing for journalists.", author: "Priya, freelance reporter"),
        TestimonialQuote(stars: 5, quote: "The fillers detection is shockingly accurate. Saved me hours.", author: "Alex, audiobook narrator")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    hero
                    featureRow
                    pricingBlock
                    checklist
                    testimonialSlot
                    Color.clear.frame(height: 100)  // sticky-CTA spacer
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            stickyCTA
        }
        .background(Color(uiColor: semantic.surfaceBase))
        .task { await loadProducts() }
        .alert("Purchase failed", isPresented: Binding(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(purchaseError ?? "")
        }
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(uiColor: semantic.textSecondary).opacity(0.5))
                }
                .accessibilityLabel("Close paywall")
            }
            SmartCutMark(size: .hero)
                .frame(width: 56, height: 56)
            Text("CleanCut Pro")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(LinearGradient(
                    colors: semantic.accentAIGradientStops.map { Color(uiColor: $0) },
                    startPoint: .leading,
                    endPoint: .trailing
                ))
            Text(reasonHeadline)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                .multilineTextAlignment(.center)
        }
    }

    private var reasonHeadline: String {
        switch reason {
        case .endOfOnboarding: return "Cut fillers. Clean noise. No limits."
        case .hitDailyCap: return "You've used your daily free quota. Pro = unlimited."
        case .hitLengthCap: return "This clip is longer than free supports. Pro = any length."
        case .watermarkExport: return "Pro removes the export watermark."
        case .settingsUpgrade: return "Cut fillers. Clean noise. No limits."
        case .trialExpired: return "Your trial ended. Keep unlimited access?"
        }
    }

    private var featureRow: some View {
        HStack(spacing: 8) {
            featurePill(icon: "infinity", label: "Unlimited\nsessions")
            featurePill(icon: "drop.fill", label: "No\nwatermark")
            featurePill(icon: "clock.fill", label: "Any\nlength")
        }
    }

    private func featurePill(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(uiColor: semantic.accentAI))
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: semantic.surfaceCard))
        )
    }

    private var pricingBlock: some View {
        VStack(spacing: 12) {
            Picker("Tier", selection: $selectedTier) {
                Text("Monthly").tag(SubscriptionProduct.Tier.monthly)
                Text("Yearly").tag(SubscriptionProduct.Tier.yearly)
                Text("Lifetime").tag(SubscriptionProduct.Tier.lifetime)
            }
            .pickerStyle(.segmented)

            if let p = products.first(where: { $0.tier == selectedTier }) {
                priceCard(for: p)
            } else {
                ProgressView().padding(.vertical, 30)
            }
        }
    }

    private func priceCard(for product: SubscriptionProduct) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(product.displayPrice)
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
                Text(product.periodLabel)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
            }
            Text(priceSubtext(for: product))
                .font(.caption)
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(
                    colors: semantic.accentAIGradientStops.map { Color(uiColor: $0).opacity(0.10) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color(uiColor: semantic.accentAction), lineWidth: 1.5)
                )
        )
        .overlay(alignment: .topTrailing) {
            if product.tier == .yearly {
                Text("SAVE 33%")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(LinearGradient(
                        colors: [Color(uiColor: SonicMergeTheme.ColorPalette.emberRed),
                                 Color(uiColor: SonicMergeTheme.ColorPalette.magentaAccent)],
                        startPoint: .leading, endPoint: .trailing
                    )))
                    .offset(x: -16, y: -8)
            }
        }
    }

    private func priceSubtext(for product: SubscriptionProduct) -> String {
        switch product.tier {
        case .monthly: return "7-day free trial · Cancel anytime · Auto-renews"
        case .yearly: return "$3.33/mo · 7-day free trial · Auto-renews"
        case .lifetime: return "One-time payment · No renewal"
        }
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 10) {
            checklistRow("Unlimited Smart Cut + Denoise")
            checklistRow("Files of any length")
            checklistRow("No export watermark")
            checklistRow("Custom filler libraries")
            checklistRow("Background processing + push")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func checklistRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: semantic.accentAIGradientStops.map { Color(uiColor: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(width: 18, height: 18)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
        }
    }

    private var testimonialSlot: some View {
        let quote = Self.testimonials.randomElement() ?? Self.testimonials[0]
        return VStack(alignment: .leading, spacing: 6) {
            Text(String(repeating: "★", count: quote.stars))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(uiColor: SonicMergeTheme.ColorPalette.emberOrange))
            Text("\u{201C}\(quote.quote)\u{201D}")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
            Text("— \(quote.author)")
                .font(.caption)
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: semantic.surfaceCard))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color(uiColor: semantic.accentAI))
                        .frame(width: 3)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
    }

    private var stickyCTA: some View {
        VStack(spacing: 8) {
            Button {
                Task { await purchaseSelected() }
            } label: {
                HStack {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(ctaLabel)
                            .font(.system(.body, design: .rounded, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(LinearGradient(
                    colors: semantic.accentAIGradientStops.map { Color(uiColor: $0) },
                    startPoint: .leading,
                    endPoint: .trailing
                )))
            }
            .disabled(isPurchasing || products.isEmpty)
            .accessibilityLabel(ctaLabel)

            HStack(spacing: 14) {
                RestorePurchasesButton(isRestoring: $isRestoring) {
                    try await client?.restore()
                }
                Text("·").foregroundStyle(Color(uiColor: semantic.textSecondary))
                Link("Terms", destination: URL(string: "https://cleancut.app/terms")!)
                    .font(.footnote)
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
                Text("·").foregroundStyle(Color(uiColor: semantic.textSecondary))
                Link("Privacy", destination: URL(string: "https://cleancut.app/privacy")!)
                    .font(.footnote)
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
            }
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            Color(uiColor: semantic.surfaceBase)
                .opacity(0.97)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var ctaLabel: String {
        switch selectedTier {
        case .monthly: return "Start 7-day free trial"
        case .yearly: return "Start 7-day free trial"
        case .lifetime: return "Buy Lifetime · \(products.first(where: { $0.tier == .lifetime })?.displayPrice ?? "$79.99")"
        }
    }

    // MARK: - Actions

    private func loadProducts() async {
        if client == nil {
            client = StoreKitClient(entitlementService: entitlementService)
        }
        do {
            products = try await client?.loadProducts() ?? []
        } catch {
            purchaseError = "Couldn't load products: \(error.localizedDescription)"
        }
    }

    private func purchaseSelected() async {
        guard let client else { return }
        guard let product = products.first(where: { $0.tier == selectedTier }) else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await client.purchase(productID: product.id)
            // Successful purchase — Transaction.updates listener has flipped
            // entitlement. Dismiss the paywall.
            dismiss()
        } catch StoreKitClient.StoreKitError.userCancelled {
            // No-op — user backed out.
        } catch {
            purchaseError = error.localizedDescription
        }
    }
}

private struct TestimonialQuote: Hashable {
    let stars: Int
    let quote: String
    let author: String
}
```

- [ ] **Step 6: Verify passing**

Run: `xcodebuild ... -only-testing:SonicMergeTests/PaywallViewTests test`
Expected: PASS (3 tests). If a render fails, check that `\.entitlementService` injection is happening — the test may need `.environment(EntitlementService.self, EntitlementService())` added.

- [ ] **Step 7: Run full suite**

Expected: `FAIL=5`.

- [ ] **Step 8: Commit**

```bash
git add SonicMerge/Features/Subscription/Views/RestorePurchasesButton.swift \
        SonicMerge/Features/Subscription/Views/PaywallTrigger.swift \
        SonicMerge/Features/Subscription/Views/PaywallView.swift \
        SonicMergeTests/Features/Subscription/Views/PaywallViewTests.swift
git commit -m "feat(subscription): PaywallView Variant A — annual default + toggle"
```

---

## Chunk 5: Settings sheet + wire it all together

**Why last:** Now we have the paywall + the services. Build the Settings sheet, wire the gear icon into all 3 home toolbars, and verify the end-to-end flow on the simulator.

### Task 5.1: SettingsToolbarButton + SettingsView shell

**Files:**
- Create: `SonicMerge/Features/Settings/Views/SettingsToolbarButton.swift`
- Create: `SonicMerge/Features/Settings/Views/SettingsView.swift`
- Test: `SonicMergeTests/Features/Settings/Views/SettingsViewTests.swift`

`SettingsToolbarButton` is the gear icon. `SettingsView` is the sheet content. Sub-project 1's `SettingsView` has 4 sections:
1. **Account** — current entitlement label (`Free` / `Pro · expires …` / `Pro · Lifetime`)
2. **Pro card** — when Free: "Upgrade to Pro" pill. When Pro: "Manage subscription" link to App Store.
3. **Restore Purchases** — small button
4. **Legal** — Terms / Privacy / About

Theme toggle stays in the home toolbar (NOT in Settings) per OQ-1 resolution.

- [ ] **Step 1: Implement `SettingsToolbarButton.swift`**

```swift
import SwiftUI

/// Gear icon in the home-view toolbar. Tap presents Settings as a sheet.
/// Lives in all 3 home views (SmartCut / Denoise / Merge).
struct SettingsToolbarButton: View {

    @Environment(\.sonicMergeSemantic) private var semantic
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(uiColor: semantic.accentAction))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color(uiColor: semantic.surfaceCard)))
        }
        .accessibilityLabel("Settings")
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                SettingsView()
            }
            .environment(EntitlementService.shared)
        }
    }
}
```

- [ ] **Step 2: Implement `ProStatusCard.swift`**

Create `SonicMerge/Features/Settings/Views/ProStatusCard.swift`:

```swift
import SwiftUI

/// Top of Settings: shows the user's Pro status. When Free, big
/// "Upgrade to Pro" CTA. When Pro, smaller "Manage subscription" link.
struct ProStatusCard: View {

    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(EntitlementService.self) private var entitlements

    @Binding var paywallReason: PaywallReason?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACCOUNT")
                .font(.caption.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
            HStack {
                Text(entitlements.currentEntitlement.displayLabel)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Spacer()
                if entitlements.isPro {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(LinearGradient(
                            colors: semantic.accentAIGradientStops.map { Color(uiColor: $0) },
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                }
            }

            if entitlements.isPro {
                Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                    HStack {
                        Text("Manage subscription")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: semantic.accentAction))
                }
            } else {
                Button {
                    paywallReason = .settingsUpgrade
                } label: {
                    HStack {
                        SmartCutMark(size: .toolbar, monochromeTint: .white)
                            .frame(width: 22, height: 22)
                        Text("Upgrade to Pro")
                    }
                    .font(.system(.body, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(LinearGradient(
                        colors: semantic.accentAIGradientStops.map { Color(uiColor: $0) },
                        startPoint: .leading,
                        endPoint: .trailing
                    )))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: semantic.surfaceCard))
        )
    }
}
```

- [ ] **Step 3: Implement `SettingsRowLink.swift`**

```swift
import SwiftUI

/// Standard disclosure-indicator row used for legal links + about.
struct SettingsRowLink: View {

    @Environment(\.sonicMergeSemantic) private var semantic
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack {
                Text(title)
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
    }
}
```

- [ ] **Step 4: Implement `SettingsView.swift`**

```swift
import SwiftUI

struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(EntitlementService.self) private var entitlements

    @State private var paywallReason: PaywallReason?
    @State private var isRestoring = false

    @State private var client: StoreKitClient?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProStatusCard(paywallReason: $paywallReason)

                VStack(spacing: 0) {
                    SettingsRowLink(title: "Privacy Policy", url: URL(string: "https://cleancut.app/privacy")!)
                    Divider().padding(.leading, 16)
                    SettingsRowLink(title: "Terms of Service", url: URL(string: "https://cleancut.app/terms")!)
                    Divider().padding(.leading, 16)
                    SettingsRowLink(title: "About", url: URL(string: "https://cleancut.app/about")!)
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(uiColor: semantic.surfaceCard))
                )

                HStack {
                    RestorePurchasesButton(isRestoring: $isRestoring) {
                        try await client?.restore()
                    }
                    Spacer()
                    Text("v\(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
                        .font(.caption2)
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                }
                .padding(.horizontal, 4)
                .padding(.top, 8)
            }
            .padding(20)
        }
        .background(Color(uiColor: semantic.surfaceBase))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(Color(uiColor: semantic.accentAction))
            }
        }
        .paywall(reason: $paywallReason)
        .task {
            if client == nil {
                client = StoreKitClient(entitlementService: entitlements)
            }
        }
    }
}

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
    var appBuild: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }
}
```

- [ ] **Step 5: Write the failing render test**

```swift
import Testing
import SwiftUI
@testable import SonicMerge

@MainActor
struct SettingsViewTests {

    @Test func rendersFreeTier() {
        let entitlements = EntitlementService()
        entitlements.setEntitlement(.free)
        let view = NavigationStack {
            SettingsView()
        }
        .environment(entitlements)
        .environment(\.sonicMergeSemantic, .resolved(colorScheme: .light, preference: .light))

        let renderer = ImageRenderer(content: view.frame(width: 390, height: 700))
        renderer.scale = 1
        #expect(renderer.uiImage != nil)
    }

    @Test func rendersProTier() {
        let entitlements = EntitlementService()
        entitlements.setEntitlement(.lifetime)
        let view = NavigationStack {
            SettingsView()
        }
        .environment(entitlements)
        .environment(\.sonicMergeSemantic, .resolved(colorScheme: .dark, preference: .dark))

        let renderer = ImageRenderer(content: view.frame(width: 390, height: 700))
        renderer.scale = 1
        #expect(renderer.uiImage != nil)
    }
}
```

- [ ] **Step 6: Run tests + full suite**

Run: `xcodebuild ... -only-testing:SonicMergeTests/SettingsViewTests test`
Expected: PASS (2 tests).

Run full: `set -o pipefail; xcodebuild ... -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3 && echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"`
Expected: `FAIL=5`.

- [ ] **Step 7: Commit**

```bash
git add SonicMerge/Features/Settings/Views/SettingsToolbarButton.swift \
        SonicMerge/Features/Settings/Views/SettingsView.swift \
        SonicMerge/Features/Settings/Views/ProStatusCard.swift \
        SonicMerge/Features/Settings/Views/SettingsRowLink.swift \
        SonicMergeTests/Features/Settings/Views/SettingsViewTests.swift
git commit -m "feat(settings): Settings sheet — account card + restore + legal links"
```

### Task 5.2: Wire SettingsToolbarButton into all 3 home views

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift`
- Modify: `SonicMerge/Features/Denoising/Views/Home/DenoiseHomeView.swift`
- Modify: `SonicMerge/Features/MixingStation/Views/MixingStationView.swift` (or whichever is the merge home view)

Existing toolbar in each home view: `.toolbar { ToolbarItem(placement: .topBarTrailing) { ThemeToggleButton() } }`. We add `SettingsToolbarButton` BEFORE the theme toggle so layout becomes `[gear] [theme]`.

- [ ] **Step 1: Re-grep current toolbar locations**

```bash
grep -n 'ThemeToggleButton\|.toolbar' \
  SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift \
  SonicMerge/Features/Denoising/Views/Home/DenoiseHomeView.swift \
  SonicMerge/Features/MixingStation/Views/MixingStationView.swift
```

Confirm line numbers — captured 2026-05-04 may have drifted.

- [ ] **Step 2: For each home view, add `SettingsToolbarButton` to the toolbar**

In each file, find the existing `ThemeToggleButton()` toolbar item and modify the toolbar block. Pattern:

```swift
// Before
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        ThemeToggleButton()
    }
}

// After
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        HStack(spacing: 8) {
            SettingsToolbarButton()
            ThemeToggleButton()
        }
    }
}
```

(Wrapping in `HStack` keeps both buttons in the same trailing slot — SwiftUI's `.toolbar` doesn't allow two `.topBarTrailing` items reliably across iOS 17/18.)

- [ ] **Step 3: Build + run**

Run: `set -o pipefail; xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manual smoke**

Launch on iPhone 17 simulator. On each tab, verify:
- Gear icon visible top-right
- Tap gear → Settings sheet appears
- Settings shows "Free" status
- Tap "Upgrade to Pro" → paywall sheet appears
- Tap × on paywall → returns to Settings
- Tap "Done" → Settings dismisses

- [ ] **Step 5: Commit**

```bash
git add SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift \
        SonicMerge/Features/Denoising/Views/Home/DenoiseHomeView.swift \
        SonicMerge/Features/MixingStation/Views/MixingStationView.swift
git commit -m "feat(settings): wire SettingsToolbarButton into all 3 home toolbars"
```

### Task 5.3: Inject EntitlementService at app level + scenePhase reset

**Files:**
- Modify: `SonicMerge/App/RootTabView.swift`
- Modify: `SonicMerge/SonicMergeApp.swift`

`EntitlementService.shared` exists as a process-wide singleton, but views need it injected via `.environment` so previews + tests can swap a fake. Also wire `PaywallTriggerCoordinator.resetSession()` to `scenePhase` transitions.

- [ ] **Step 1: In `RootTabView.swift`, inject `EntitlementService` + create the coordinator**

Add at the top of `RootTabView`:

```swift
@State private var paywallCoordinator = PaywallTriggerCoordinator()
```

Add `.environment(EntitlementService.shared)` and `.environment(paywallCoordinator)` to the body's TabView (after the existing `.environment(\.sonicMergeSemantic, ...)`).

- [ ] **Step 2: Reset session on scenePhase transitions**

In the existing `.onChange(of: scenePhase)` block, add:

```swift
if phase == .active {
    paywallCoordinator.resetSession()
}
```

(There's already an `.onChange(of: scenePhase)` block in RootTabView — extend it; don't add a second.)

- [ ] **Step 3: Build + smoke**

Run: build → expect BUILD SUCCEEDED. Open Settings, tap Upgrade, dismiss, tap Upgrade again — paywall should still show (because `.settingsUpgrade` bypasses throttling). Background the app and re-foreground; the session flag should reset.

- [ ] **Step 4: Commit**

```bash
git add SonicMerge/App/RootTabView.swift
git commit -m "feat(subscription): inject EntitlementService + PaywallTriggerCoordinator at root"
```

### Task 5.4: Final full-suite test + ship-readiness check

- [ ] **Step 1: Run full suite one last time**

```bash
set -o pipefail; xcodebuild -scheme SonicMerge \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
```

Expected: `FAIL=5` (baseline preserved). New tests for this sub-project: ~20 added, all passing.

- [ ] **Step 2: Manual end-to-end validation**

On simulator (iPhone 17):
1. Cold launch app → onboarding (or skip if `hasOnboarded == true`)
2. Tap any tab → see gear + theme toggle in toolbar
3. Tap gear → Settings sheet appears with "Free" status + "Upgrade to Pro" CTA
4. Tap "Upgrade to Pro" → paywall sheet (Variant A — annual default with toggle)
5. Toggle between Monthly / Yearly / Lifetime — pricing card updates
6. Tap "Start 7-day free trial" with Yearly selected → StoreKit Test sandbox prompt (because the scheme has `.storekit` config)
7. Approve sandbox purchase → paywall dismisses, Settings now shows "Pro · Lifetime" or "Pro · expires …"
8. Tap "Restore Purchases" → spinner briefly, status unchanged
9. Tap "Done" → Settings dismisses
10. Force-quit + relaunch → entitlement persists (Settings still shows Pro)

If anything fails in this checklist, identify root cause + fix BEFORE finishing.

- [ ] **Step 3: Final commit (if any docs need updating)**

If the manual smoke surfaced doc updates, commit them. Otherwise:

```bash
git status  # should be clean
```

### Task 5.5: Use @superpowers:finishing-a-development-branch

The branch is `main` per ongoing user direction; finishing-a-development-branch will likely just verify tests pass and confirm the work is complete (no merge step since we're already on main, no PR step unless the user specifically asks).
