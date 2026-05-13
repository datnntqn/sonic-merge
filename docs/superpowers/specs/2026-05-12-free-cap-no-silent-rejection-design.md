# Free-cap "no silent rejection" — design

**Status:** Draft
**Date:** 2026-05-12
**Owner:** —
**Related work:** `2026-05-04-monetization-design.md` (Sub-projects 1 & 2 introduced `ProFeature`, `GateResult`, `PaywallReason`, and the import-time gating at `SmartCutHomeView` / `DenoiseHomeView`).

## 1. Problem

A Free user reported: "I uploaded an audio longer than 8 minutes. The app didn't show any notification telling me it's a Free-tier restriction." Investigation surfaced three concrete user-visible gaps and one bypass:

1. **Silent rejection when the paywall is throttled.** `PaywallTriggerCoordinator.shouldPresent(_:)` returns `false` when (a) any paywall has been shown in the current session, or (b) the user has dismissed the same `PaywallReason` ≥ 5 times. The current `PaywallTrigger` modifier reacts to that by clearing the binding (`reason = nil`), which means the import is rejected and the temp file is cleaned up but **no UI is shown**. To the user this is indistinguishable from "nothing happened."
2. **Share Extension bypasses every gate.** `SonicMergeShareExtension/ShareExtensionViewController` writes the imported file directly to the App Group with no length/quota check. Free users get unrestricted access by sharing from another app.
3. **No pre-emptive disclosure.** Free caps exist only inside `EntitlementService.FreeCap`. The user has no way to discover them until they cross one.
4. **Same silent-rejection problem also applies to the daily 3-session quota** (`.hitDailyCap`), via the same throttled-paywall path.

This spec covers all four gaps. It does **not** modify the cap numbers themselves (5 min Smart Cut, 3 min Denoise, 3 clips Merge, 3 sessions/day).

## 2. Goals

- **G1.** A Free user who hits any cap always sees feedback explaining why — never silent rejection.
- **G2.** The Share Extension enforces the same length cap as in-app import.
- **G3.** A Free user can discover the cap on the home screen before tapping import.
- **G4.** Apple-guideline-friendly: the full-screen paywall keeps its current session throttle. Repeat feedback is delivered through a less intrusive top-of-screen toast.
- **G5.** Pro users see zero additional UI and pay zero performance cost.

## 3. Non-goals

- Changing cap values, daily counter logic, or the paywall product list.
- Onboarding redesign or proactive paywall scheduling (already specced in `2026-05-04-monetization-design.md`).
- Watermark / export-format gating — those paywall reasons (`.watermarkExport`, `.settingsUpgrade`) are not cap-hits and stay on the existing path.
- Network-based entitlement validation — the existing `Transaction.updates` flow is the source of truth.

## 4. Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Main app                                                    │
│                                                             │
│  EntitlementService ──writes isPro──▶  App Group defaults   │
│         │                                       ▲           │
│         │ gate(.smartCutLength)                 │           │
│         ▼                                       │           │
│  Home views (SmartCut/Denoise/Merge)            │           │
│    ├─ FreeCapCaption  (new)  ──reads cap────────┘           │
│    └─ paywall(reason:) modifier                             │
│           │                                                 │
│           ▼ asks                                            │
│       PaywallTriggerCoordinator.decide(_:)                  │
│           │                                                 │
│       ┌───┴─── .present  ──▶  PaywallView (sheet)           │
│       │                                                     │
│       ├─── .fallbackToast  ──▶  CapLimitToast (new)         │
│       │                                                     │
│       └─── .suppress                                        │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │ read isPro + caps
┌─────────────────────────────┴───────────────────────────────┐
│ ShareExtension                                              │
│    ShareExtensionViewController                             │
│        ├─ probe duration via AVURLAsset                     │
│        ├─ read isPro from App Group defaults                │
│        └─ if Free && over-cap → error HUD, abort copy       │
└─────────────────────────────────────────────────────────────┘
```

Key decisions:
- The coordinator returns a 3-state `PresentDecision` (`.present | .fallbackToast | .suppress`) instead of a `Bool`. Cap-hit reasons flag themselves as needing fallback feedback; proactive reasons stay quiet when throttled.
- Pro state is mirrored to App Group `UserDefaults` at `setEntitlement(_:)` time so the Share Extension can read it synchronously without bringing StoreKit into the extension target.
- `FreeCap` moves from `EntitlementService.FreeCap` to `AppConstants.FreeCap` (already mirrored per CLAUDE.md). `EntitlementService.FreeCap` becomes a typealias for source-compatibility — no callsite changes.

## 5. Components

### 5.1 `PaywallTriggerCoordinator.decide(_:)`

Replaces the existing `shouldPresent(_:) -> Bool`. Every callsite (currently only `PaywallTriggerModifier`) is updated; `shouldPresent` is deleted.

```swift
enum PresentDecision: Equatable, Sendable {
    case present       // open the paywall sheet
    case fallbackToast // throttled, but reason needs feedback
    case suppress      // throttled, proactive reason — stay quiet
}

func decide(_ reason: PaywallReason) -> PresentDecision {
    if reason.bypassesThrottle { return .present }
    let throttled = hasShownPaywallThisSession
                 || dismissCount(for: reason) >= Self.dismissThreshold
    if !throttled { return .present }
    return reason.requiresFallbackFeedback ? .fallbackToast : .suppress
}
```

On `.present`, the coordinator calls `markPresented` internally — callers no longer remember to call it after `shouldPresent`. (This is a small API simplification; the existing `markPresented` becomes private.)

### 5.2 `PaywallReason.requiresFallbackFeedback`

```swift
extension PaywallReason {
    /// True when a throttled trigger should still surface a toast so the
    /// user isn't silently rejected. Cap-hits qualify; proactive reasons
    /// (onboarding, trial-expired) do not — those are by-design quiet.
    var requiresFallbackFeedback: Bool {
        switch self {
        case .hitLengthCap, .hitDailyCap: return true
        case .endOfOnboarding, .trialExpired, .watermarkExport, .settingsUpgrade:
            return false
        }
    }
}
```

### 5.3 `CapLimitToast`

New SwiftUI view + view modifier. Lives at the `paywall(reason:)` modifier site so it shares the existing `@State var paywallReason: PaywallReason?` plumbing.

- Rendered via `.overlay(alignment: .top)` on the home view's outer container, driven by a `@State var toastMessage: ToastMessage?` flag. Slides in with `.transition(.move(edge: .top).combined(with: .opacity))` keyed off that flag. `.overlay` (not `.safeAreaInset`) so the toast floats above content and never reflows the layout when it appears/dismisses.
- One line + chevron CTA: `⚠️ This 7:14 clip exceeds the Free 5-min cap.  Upgrade →`
- Auto-dismisses after 5 s. Tappable region opens the paywall via `.settingsUpgrade` (bypasses throttle — the user is explicitly asking).
- Indigo chrome (`semantic.accentAction`). Lime is reserved for AI moments per CLAUDE.md color discipline.
- Accessibility: `.accessibilityIdentifier("CapLimitToast")`. On appear, post a screen-reader announcement via `UIAccessibility.post(notification: .announcement, argument: message.text)` from the toast's `.onAppear`.
- Duration formatting (`7:14`) uses a tiny private helper on the home view: `formatMMSS(_ seconds: TimeInterval) -> String` returning `m:ss` with zero-padded seconds. Same helper is already used by `SmartCutRecentRow` (see `SmartCutHomeView.swift:381`) — reuse, don't re-implement.

Toast copy is parameterized by reason and source:

| Reason | Copy |
|---|---|
| `.hitLengthCap` (Smart Cut) | "This `X:XX` clip exceeds the Free 5-min cap." |
| `.hitLengthCap` (Denoise) | "This `X:XX` clip exceeds the Free 3-min cap." |
| `.hitLengthCap` (Merge) | "Free is limited to 3 clips." |
| `.hitDailyCap` | "You've used today's 3 free sessions." |

The home view that triggered the rejection knows the duration. Toast content is **constructed at the gate site** as a `ToastMessage` value (`struct ToastMessage: Equatable { let text: String; let reason: PaywallReason }`) and assigned to the home view's `@State var toastMessage: ToastMessage?`. The coordinator's `.fallbackToast` decision is the **gate**; the **content** is supplied by the caller.

For Merge, the gate happens inside `MixingStationViewModel.importFiles(...)` and surfaces as `PaywallReason?` to the view. The Merge toast copy is reason-only ("Free is limited to 3 clips.") — no count interpolation — so the existing reason-only return-path is sufficient and the VM does **not** need to also return a `ToastMessage`. The view constructs the static string from the reason alone.

### 5.4 `FreeCapCaption(feature:)`

New SwiftUI view. Renders under the hero/pinned `CircularImportButton` on each home screen.

```swift
struct FreeCapCaption: View {
    enum Feature { case smartCut, denoise, merge }
    let feature: Feature
    @Environment(EntitlementService.self) private var entitlements

    var body: some View {
        if entitlements.isPro { EmptyView() }
        else { /* caption text + tap → paywall */ }
    }

    /// Pure-function test seam. Returns the caption string for a given state.
    /// `count` is consumed only for `.smartCut` and `.denoise`; ignored for `.merge`.
    static func captionString(for feature: Feature, isPro: Bool, count: Int) -> String? { … }
}
```

Copy:

| Feature | Caption |
|---|---|
| `.smartCut` | `Free: up to 5 min · N of 3 today` |
| `.denoise` | `Free: up to 3 min · N of 3 today` |
| `.merge` | `Free: up to 3 clips` |

- Live-updates because `EntitlementService` (and `DailyUsageTracker`) are `@Observable`.
- Tappable → opens paywall via `.settingsUpgrade` (bypasses throttle).
- Inserted in three locations:
  - `SmartCutHomeView` — under the hero `EmptyState` (empty case) and under the pinned `CircularImportButton` (populated case).
  - `DenoiseHomeView` — same pattern, both cases.
  - `MixingStationView` — under the pinned `CircularImportButton` at the top of the timeline area in both the empty timeline and populated states. The Merge tab is a single-workspace tab (not a list per CLAUDE.md), so there's no list-vs-empty branch — one caption position.
- **Daily count access**: `DailyUsageTracker` is `private let` inside `EntitlementService`. Add a public method `func dailyCount(for feature: DailyUsageTracker.Feature) -> Int { usageTracker.count(for: feature) }` on `EntitlementService`. The caption calls this directly (no tracker injection into the view).
- For `.merge` the caption renders the static `Free: up to 3 clips` — no daily count is read, so the `count` parameter is unused.

### 5.5 Mirrored Pro state in App Group defaults

```swift
// EntitlementService.setEntitlement(_:) — runs on EVERY state transition,
// not only Pro→Free or Free→Pro. Idempotent so duplicate writes are harmless.
let defaults = sharedDefaults ?? UserDefaults(suiteName: AppConstants.appGroupID)
defaults?.set(entitlement.isPro, forKey: Self.isProMirrorKey)
```

`Self.isProMirrorKey = "EntitlementService.isPro"` — namespaced to avoid collision with other App Group keys.

Tests inject a custom `UserDefaults` via a new initializer parameter `sharedDefaults: UserDefaults? = nil` so they don't touch the real App Group suite. Production code passes `nil` and the runtime resolves the suite by ID.

### 5.6 `AppConstants.FreeCap`

Move the existing `EntitlementService.FreeCap` enum into `AppConstants.swift`. Both target copies of `AppConstants` (main app + Share Extension, per CLAUDE.md "keep both copies in sync") gain the same values:

```swift
enum FreeCap {
    static let smartCutSessionsPerDay = 3
    static let denoiseSessionsPerDay = 3
    static let smartCutMaxSeconds: TimeInterval = 300
    static let denoiseMaxSeconds: TimeInterval = 180
    static let mergeMaxClips = 3
}
```

`EntitlementService.FreeCap` becomes `typealias FreeCap = AppConstants.FreeCap` — keeps the existing call sites (`FreeCap.smartCutMaxSeconds`) source-compatible.

### 5.7 Share Extension gate

`ShareExtensionViewController` and its tested helper `ShareHUDModel` change as follows.

**`HUDState` shape.** Today `ShareHUDModel.HUDState` has bare cases (`.copying`, `.success`, `.error`). Add a new top-level case `.freeLimitReached(durationSeconds: Double)` rather than refactoring `.error` into an enum-with-payload — minimizes churn for existing call sites and existing `.error` rendering in `ShareHUDView` stays unchanged. New case carries the duration so the view can format `m:ss`.

```swift
enum HUDState: Equatable {
    case copying
    case success
    case error
    case freeLimitReached(durationSeconds: Double)  // new
}
```

**Gate flow** in `ShareExtensionViewController`:
1. After `provideItem(forTypeIdentifier:)` yields the URL, load `AVURLAsset(url:).load(.duration).seconds` before the existing copy step.
2. Read `UserDefaults(suiteName: AppConstants.appGroupID)?.bool(forKey: "EntitlementService.isPro")` (default `false`).
3. If `!isPro && duration > AppConstants.FreeCap.smartCutMaxSeconds`, set `ShareHUDModel.state = .freeLimitReached(durationSeconds: duration)`, skip the copy, never write the `pending` key.

**`ShareHUDView`** gains a single new `switch` branch for `.freeLimitReached(let seconds)`:
- Title: "Free limit reached"
- Subtitle: `"This \(format(seconds)) clip exceeds the Free 5-min cap. Open CleanCut to upgrade."`
- Done button (existing button — same dismiss action as `.error`).

**Theme.** `ShareHUDView` is a separate-process surface and does **not** have access to `\.sonicMergeSemantic`. Per the existing `AppConstants` mirror pattern (CLAUDE.md), inline the indigo hex as a Share-Ext-local constant: `private let accentIndigo = Color(red: 0x58/255, green: 0x56/255, blue: 0xD6/255)` (matches `accentAction` `#5856D6`). This is the same intentional cross-target duplication CLAUDE.md already calls out for `AppConstants`. The existing palette constants (`accentBlue`, `backgroundGray`) stay; the new error variant uses `accentIndigo` for the title and Done button tint to align with the main app's chrome color.

The cap used in the Share Extension is `smartCutMaxSeconds` (5 min — the more permissive of Smart Cut and Denoise). The Share Extension doesn't know which workspace the user will route to. Worst case: a 4-min clip is admitted via Share Ext, the user picks Denoise (3-min cap) inside the app, and the in-app gate catches it on tap-to-open with the same toast-or-paywall UX. This matches behavior of an in-app import from Files.

## 6. Data flow

### 6.1 In-app import — Free user, over cap, **first attempt this session**
1. User picks a 7-min file in `SmartCutHomeView`.
2. `ImportDecision.gate(...)` returns `.hitLengthCap`. View deletes temp file, sets `paywallReason = .hitLengthCap`.
3. `paywall(reason:)` modifier calls `coordinator.decide(.hitLengthCap)` → `.present`. Paywall sheet opens.

### 6.2 In-app import — Free user, over cap, **second attempt this session**
1. Same flow until `decide`.
2. `decide` returns `.fallbackToast` (already shown this session; `.hitLengthCap` requires feedback).
3. Modifier sets `toastMessage = .init(text: "This 7:14 clip exceeds the Free 5-min cap.")` and clears `paywallReason`. `CapLimitToast` appears, auto-dismisses in 5 s.

### 6.3 In-app import — Free user, over the **daily 3-session quota**
1. `ImportDecision.gate` returns `.hitDailyCap` (`.smartCutLength` passed; `.smartCutSession` failed).
2. Same `.present` → `.fallbackToast` cascade as 6.1/6.2. Toast copy is "You've used today's 3 free sessions."

### 6.4 Share Extension — over cap, Free user
1. `provideItem` returns the URL.
2. Duration probe (`AVURLAsset.load(.duration)`).
3. `isPro=false` from App Group defaults; `duration > 300`. `ShareHUDModel.state = .freeLimitReached(durationSeconds: duration)`. No copy, no `pending` key. User taps Done.

### 6.5 Pro user, any path
- All gates return `.allowed` immediately. `FreeCapCaption` renders `EmptyView`. Share Ext reads `isPro=true` and skips the duration probe. Zero overhead and zero added UI.

## 7. Edge cases

### 7.1 Pro state stale in App Group defaults
- `Transaction.updates` is the only path to enter or leave Pro. Both paths land in `setEntitlement(_:)`, which writes the flag synchronously. No race.
- Inverse (Pro → Free, e.g. expired): if the device is offline and StoreKit hasn't fired the revoke event yet, the extension may admit one over-cap import. Accepted (rare, low-stakes; the in-app gate will catch the next attempt).

### 7.2 Share Ext duration probe fails
- `AVURLAsset.load(.duration)` throws → fall through to the existing "Couldn't import" error HUD. Don't block on probe failure; a corrupt file would fail in-app anyway.

### 7.3 User dismisses fallback toast 100 times then taps Upgrade in Settings
- Toast is ephemeral, no dismiss counter. Paywall opens via `.settingsUpgrade` (bypasses throttle). Behavior unchanged.

### 7.4 `EditFillerListStudioSheet` and `MixingStation` paywall callsites
- `.customFillerLibrary` and `.backgroundProcessing` already map to `.settingsUpgrade` reason — not a cap-hit, no fallback feedback needed. Unchanged.
- `.mergeClipCount` already reuses `.hitLengthCap` (per the in-code comment in `EntitlementService.swift:79`). It inherits the toast-fallback automatically. The toast copy variant for Merge (`"Free is limited to 3 clips."`) is selected at the gate site because the home view knows it's the Merge workspace.

### 7.5 Existing test injection seams
- `PaywallTriggerCoordinator` tests instantiate the coordinator with a custom `UserDefaults`. The new `decide` keeps the same constructor signature and adds no new dependencies. **Three** existing test files currently use the public `markPresented(...)` as a fixture-setup helper:
  - `SonicMergeTests/Features/Subscription/Services/PaywallTriggerCoordinatorTests.swift`
  - `SonicMergeTests/Features/Subscription/Services/PaywallTriggerCoordinatorIntegrationTests.swift`
  - `SonicMergeTests/Features/Reviews/ReviewPromptCoordinatorTests.swift:19`

  Since `decide(.present)` now calls `markPresented` internally, the setup pattern in those tests is updated from `coord.markPresented(.X); coord.shouldPresent(.Y)` to `_ = coord.decide(.X); coord.decide(.Y)`. All three files are rewritten in this work.
- `EntitlementService.shared` (the legacy singleton, marked "Do not use in app code") gains the same App Group write; tests that use it are unaffected because the write is a side effect to a real `UserDefaults` suite, which they don't read.

### 7.6 Background transcription resume on over-cap session
- A previously-imported (and therefore previously-gated) session resuming background transcription is by definition already under the cap from the import-time check. No new check needed.

## 8. Testing

### 8.1 Unit
- `PaywallTriggerCoordinatorTests` (rewritten from existing `shouldPresent` tests):
  - `decide(.hitLengthCap)` → `.present` first time.
  - `decide(.hitLengthCap)` → `.fallbackToast` after `decide(.hitLengthCap)` returned `.present` once (session-throttle hit).
  - `decide(.endOfOnboarding)` → `.suppress` after session-throttle hit.
  - `decide(.settingsUpgrade)` → `.present` regardless of throttle.
  - `decide(.hitLengthCap)` → `.fallbackToast` after 5 dismisses recorded (dismiss-count threshold).
- `EntitlementServiceMirrorTests` (new): `setEntitlement(.pro(...))` writes `true` to the injected `UserDefaults`; `setEntitlement(.free)` writes `false`.
- `ShareExtensionImportGatingTests` (new): with mocked `UserDefaults` and a fixture audio file —
  - Pro + over cap → admits.
  - Free + under cap → admits.
  - Free + over cap → produces `.freeLimitReached(durationSeconds:)`, never copies.
- `FreeCapCaptionTests` (new): the view's internal `captionString(for:isPro:count:)` pure function returns the right copy per feature/state.

### 8.2 Manual QA
- Toast appears on second in-app over-cap import in a session.
- Toast tap opens paywall.
- `FreeCapCaption` reflects live quota changes after a Smart Cut import (`N of 3 today` increments).
- Share Extension shows error HUD when sharing an 8-min clip on a Free account.
- Pro upgrade hides `FreeCapCaption`, lets Share Ext through.

Manual-QA doc: `docs/superpowers/qa/2026-05-12-free-cap-no-silent-rejection-manual-qa.md` (filled in during implementation).

## 9. Implementation chunks (preview — full plan is the writing-plans output)

1. `AppConstants.FreeCap` move + typealias; both target copies updated.
2. `PaywallReason.requiresFallbackFeedback` + `PaywallTriggerCoordinator.decide(_:)` + `PresentDecision` enum. Existing tests rewritten.
3. `CapLimitToast` view + `paywall(reason:)` modifier update to handle `.fallbackToast`. Toast message threaded through.
4. `FreeCapCaption` view + insertions at three home screens.
5. `EntitlementService` App Group mirror write.
6. Share Extension: duration probe + new `ShareHUDModel.HUDState.freeLimitReached(durationSeconds:)` case + `ShareHUDView` branch for it.
7. Tests for all of the above. Manual QA doc.

Each chunk is independently mergeable; chunks 1–2 unlock everything else.

## 10. Open questions

- Should the in-app `FreeCapCaption` for the Merge tab also show "N of unlimited today" if Pro has no daily cap? Currently `EmptyView` for Pro — confirm the intent is "nothing", not "a positive Pro affirmation."
- Share Extension deep-link to paywall — **closed**: stays Done-button-only. URL-scheme deep-linking from an extension to a specific in-app sheet adds surface area for negligible UX gain; the user opening the main app and seeing the in-app caption + the existing `Upgrade` chrome is sufficient.

## 11. Out of scope (documented for traceability)

- Adjusting the FillerDetector crash fix landed at the start of this session. Already shipped via a surgical guard.
- Onboarding paywall scheduling (`.endOfOnboarding`) — covered in `2026-05-04-monetization-design.md`.
