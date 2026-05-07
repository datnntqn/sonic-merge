# CleanCut Monetization Sub-project 3 — Conversion Moments

**Date:** 2026-05-07
**Status:** Spec — implementation-ready
**Author:** Claude (autonomous mode, user-approved decisions)
**Parent spec:** `docs/superpowers/specs/2026-05-04-monetization-design.md` §"Sub-project tabs" #3
**Predecessor:** `docs/superpowers/plans/2026-05-06-monetization-feature-gates.md` (Sub-project 2 — shipped to `main` 2026-05-07)

## Summary

Sub-project 2 wired six reactive paywall gates (`.hitDailyCap`, `.hitLengthCap`, `.watermarkExport`, `.settingsUpgrade`, `.customFillerLibrary`, `.backgroundProcessing`) but bypassed the `PaywallTriggerCoordinator` — every gate trip currently surfaces a paywall every time. Sub-project 3 closes that loop by (a) routing all paywall presentations through the coordinator's existing throttling rules (once-per-session, 5-dismiss permanent stop, `.settingsUpgrade` bypass) and (b) adding the **post-onboarding conversion moment** — the highest-ROI trigger per RevenueCat industry data, currently a no-op in the codebase.

The work is mechanically small (~170 LOC new, ~50 modified, 3 new test suites) but UX-significant: it transforms the paywall from a "fires every time" annoyance into a "fires once when it matters" conversion surface, and adds the single most-converting moment any iOS utility app ships.

## Goals

1. **Make `PaywallTriggerCoordinator` actually authoritative.** Every paywall presentation in the app must consult `shouldPresent(_:)` before mounting the sheet.
2. **Add the post-onboarding paywall.** When a new user finishes onboarding, present the paywall ONCE with celebratory framing.
3. **Preserve all Sub-project 2 gate semantics.** No call site change; throttling is added inside the modifier so the existing 6 gate sites pick it up "for free."
4. **Maintain the FAIL=5 baseline.** No new flaky tests; existing 206-test suite stays passing modulo the 5 known-baseline failures.

## Non-Goals

- **No new `PaywallReason` cases beyond `.postOnboarding`.** `.hitClipCountCap` was discussed for Merge in Sub-project 2 and deferred — same here.
- **No confetti animation.** A 1-line celebratory header inside `PaywallView` is sufficient; full ceremony is YAGNI.
- **No new `PaywallView` variant or hero imagery.** Single conditional header at the top, same body underneath.
- **No changes to `Settings/ProStatusCard.swift`.** Already wired to `.settingsUpgrade` correctly.
- **No backend / receipt validation work.** Sub-project 1 territory.
- **No `.trialExpired` wiring.** The reason exists in the enum but the trigger (StoreKit subscription expiration listener) is deferred to Sub-project 4 / post-launch.

## Free vs Pro feature matrix

Unchanged from Sub-project 2. See parent spec §"Free vs Pro feature matrix".

## Architecture

```
                                                         ┌─────────────────────────────┐
                                                         │ PaywallTriggerCoordinator   │
                                  ┌────────────────────► │  · shouldPresent(_:)        │
                                  │                      │  · markPresented(_:)        │
                                  │  consults            │  · recordDismiss(_:)        │
                                  │                      └─────────────────────────────┘
┌──────────────────────┐  sets   ┌─┴────────────────────┐
│ Gate site (Sub-proj 2)│ ─────► │ .paywall(reason:)    │  ◄── coordinator-aware
│ paywallReason = .X    │        │   modifier           │      modifier (NEW behavior)
└──────────────────────┘         └─┬────────────────────┘
                                   │ presents
                                   ▼
                         ┌──────────────────────┐
                         │ PaywallView          │
                         │  + celebratory header │  ◄── conditional on
                         │    if .postOnboarding │      reason == .postOnboarding
                         └──────────────────────┘
                                   ▲
                                   │ sets paywallReason = .postOnboarding
┌──────────────────────────────────┴─┐
│ OnboardingFlow.onCompleted()        │  ◄── NEW call site (#9)
│   → PostOnboardingPaywallHost holds │
│     @State paywallReason            │
│   → modifier presents               │
└─────────────────────────────────────┘
```

### Two pieces of new wiring

1. **Coordinator-aware `.paywall(reason:)` modifier.** Same call signature as today (`viewBody.paywall(reason: $paywallReason)`), but inside the modifier we now consult `coordinator.shouldPresent(_:)`, suppress the sheet when blocked, and call `markPresented` / `recordDismiss` at the right lifecycle points. All six existing Sub-project 2 gate sites pick this up "for free" with no code change.

2. **Onboarding completion → paywall trigger.** At `OnboardingFlow.swift` line 507 (`onCompleted(editList, cleanedURL)`), a new `PostOnboardingPaywallHost` wrapper holds `@State var paywallReason: PaywallReason?`, sets it to `.postOnboarding` after the onboarding completion handler runs, and the coordinator-aware modifier presents the sheet. New `PaywallReason.postOnboarding` case added to the enum.

### Throttling implications

- **Hit `.hitDailyCap` 10 times in one session** → paywall fires ONCE; subsequent attempts in same session are suppressed silently.
- **Dismiss any reason 5 times across all sessions** → that reason stops firing entirely (UserDefaults-persisted counter).
- **`.settingsUpgrade` always shows** — bypass for explicit user intent.
- **`.postOnboarding` participates in normal throttle** (does NOT bypass) — onboarding-replay-on-reinstall could re-trigger it, but the dismiss-count would eventually stop it.
- **Session reset** — `coordinator.resetSession()` fires on `scenePhase` `.background → .active` transition (already wired in Sub-project 1).

## Components & file changes

### New files (3)

| Path | Purpose | LOC est |
|---|---|---|
| `SonicMerge/Features/Onboarding/Views/PostOnboardingPaywallHost.swift` | Tiny wrapper view that holds `@State paywallReason: PaywallReason?`, listens for onboarding completion, sets reason to `.postOnboarding`, applies `.paywall(reason:)`. Lets us inject paywall presentation **outside** `OnboardingFlow` itself (keeps onboarding logic pure). | ~40 |
| `SonicMergeTests/Features/Subscription/PaywallTriggerCoordinatorIntegrationTests.swift` | Covers the new modifier path: `shouldPresent` suppresses session-2nd attempt, dismiss-count crosses threshold, `.settingsUpgrade` bypass works, `.postOnboarding` participates in throttle. | ~80 |
| `SonicMergeTests/Features/Onboarding/PostOnboardingPaywallHostTests.swift` | Verifies onboarding completion sets `.postOnboarding` exactly once; coordinator integration smoke. | ~50 |

### Modified files (5)

| Path | Change |
|---|---|
| `SonicMerge/Features/Subscription/Views/PaywallReason.swift` | **Add** `case postOnboarding` (rawValue `"post-onboarding"`). `bypassesThrottle = false`. |
| `SonicMerge/Features/Subscription/Views/PaywallTrigger.swift` | **Rewrite** the `.paywall(reason:)` modifier to consult `EnvironmentValues.paywallCoordinator` (new env key). Pseudo-flow: `onChange(of: reason)` → if non-nil, ask `coordinator.shouldPresent(reason)` → if `false`, set `reason = nil` (suppress); if `true`, call `markPresented` and let the sheet present; on sheet dismiss, call `recordDismiss`. |
| `SonicMerge/Features/Subscription/Views/PaywallView.swift` | **Add** a conditional celebratory header at the top of the body: `if reason == .postOnboarding { CelebratoryHeader() }` — single VStack row, ~12 lines (icon + headline copy "🎉 You're all set."). |
| `SonicMerge/App/RootTabView.swift` | **Inject** `PaywallTriggerCoordinator` into the environment via new `EnvironmentValues.paywallCoordinator` key. (Coordinator already exists as state on `RootTabView` post-Sub-project 1; we expose it via `.environment(\.paywallCoordinator, coordinator)`.) |
| `SonicMerge/App/SonicMergeApp.swift` | **Wrap** the onboarding root in `PostOnboardingPaywallHost` so completion triggers the new paywall sheet. |

## Data flow

### Flow A — existing gate site (Sub-project 2 callsite, unchanged code, new behavior)

```
1. User imports 4th Smart Cut audio same day
2. SmartCutHomeView.ImportDecision.gate(...) returns .hitDailyCap
3. Caller writes:  paywallReason = .hitDailyCap     ◄── unchanged
4. .paywall(reason: $paywallReason) modifier sees binding flip nil → .hitDailyCap
5. Modifier asks coordinator.shouldPresent(.hitDailyCap)
   ├─ if hasShownPaywallThisSession == true   → modifier sets paywallReason = nil (suppress)
   ├─ if dismissCount(.hitDailyCap) ≥ 5      → modifier sets paywallReason = nil (suppress)
   └─ otherwise                              → coordinator.markPresented(.hitDailyCap), present sheet
6. User dismisses sheet → coordinator.recordDismiss(.hitDailyCap), increment UserDefaults counter
```

### Flow B — new post-onboarding paywall (NEW callsite, new behavior)

```
1. User completes onboarding step 5 ("Smart Cut applied" wow)
2. OnboardingFlow.onCompleted(editList, cleanedURL) fires (existing line 507)
3. SonicMergeApp's wrapping PostOnboardingPaywallHost intercepts completion:
   - calls original onCompleted side effects (mark hasCompletedOnboarding=true, etc.)
   - sets paywallReason = .postOnboarding
4. .paywall(reason:) modifier triggers Flow A from step 4 onward
5. PaywallView body checks reason == .postOnboarding → renders CelebratoryHeader at top
6. User taps "Start 7-day trial" → existing StoreKitClient flow → entitlement updates → sheet dismisses
   OR
   User taps "Maybe later" → coordinator.recordDismiss(.postOnboarding), sheet dismisses
7. User lands on Smart Cut home tab (the wow's natural destination)
```

### Throttle decision matrix

| Scenario | shouldPresent return | Why |
|---|---|---|
| First trip of any reason in session | `true` | Default path — neither throttle applies |
| Second trip of any non-bypass reason in same session | `false` | `hasShownPaywallThisSession == true` |
| `.settingsUpgrade` after another paywall already shown this session | `true` | Explicit user intent — bypass |
| Reason dismissed 5× across all sessions | `false` | Permanent per-reason stop |
| App backgrounded → foregrounded → first trip | `true` | `resetSession()` clears `hasShownPaywallThisSession` |
| First-time onboarding completion | `true` | Same as any first trip — natural fire |
| Onboarding completes again (re-install + replay) | `true` first time, throttle thereafter | Same rules as any reason |

## Error handling

- **Modifier called outside an environment with `paywallCoordinator`** — runtime fatal error in DEBUG builds, fall back to "always present" in RELEASE (graceful degradation). Add a default `EnvironmentValues.paywallCoordinator` of `PaywallTriggerCoordinator()` so even unwired paths get a fresh coordinator instance — preserves correctness if a developer forgets to inject.
- **`onCompleted` called twice** — guard the host's `paywallReason` assignment with `if paywallReason == nil` so a double-fire (rare, but safe) doesn't bypass throttle by re-flipping the binding.
- **UserDefaults dismiss-counter corruption** — `defaults.integer(forKey:)` returns 0 on missing/corrupt key, so the counter naturally resets to "no dismissals yet"; not a real failure mode.
- **PaywallReason rawValue collision in dismiss-count keys** — already namespaced as `"PaywallTriggerCoordinator.dismissCount.\(reason.rawValue)"`; new `.postOnboarding` rawValue `"post-onboarding"` doesn't collide with existing.

## Testing

### `PaywallTriggerCoordinatorIntegrationTests.swift`

```swift
@Test func firstTripPresents() async  // shouldPresent → true, markPresented sets flag
@Test func secondTripInSessionSuppressed() async
@Test func settingsUpgradeBypassesSessionThrottle() async
@Test func postOnboardingDoesNOTBypassSessionThrottle() async
@Test func dismissThresholdReachedSuppresses() async  // record 5 dismisses → 6th shouldPresent returns false
@Test func dismissCounterPersistsAcrossInstances() async  // reload coordinator with same UserDefaults
@Test func resetSessionRehydratesPresentation() async  // resetSession() then trip → shouldPresent → true
```

### `PostOnboardingPaywallHostTests.swift`

```swift
@Test func completionSetsReasonToPostOnboarding() async
@Test func doubleCompletionDoesNotResetReason() async  // idempotent guard
@Test func reasonClearsAfterDismiss() async
```

### Manual smoke

1. **Fresh install** → run through onboarding → after step 5 wow, paywall sheet rises with celebratory header → "Maybe later" dismisses → land on Smart Cut tab.
2. **Free user post-onboarding dismiss** → import a 4th Smart Cut session same day → paywall does NOT fire (session throttle held from onboarding paywall).
3. **Backgrounded post-dismiss** → background app, foreground → import 4th SC → paywall fires (session reset).
4. **Pro user post-onboarding** → temporarily set `.lifetime` entitlement before onboarding completion → paywall does NOT fire (gate doesn't trigger because `.postOnboarding` is post-onboarding-only and Pro users can also see it; design choice: yes they should see it but the trial messaging looks weird; acceptable v1 behavior).

   **Note:** A future refinement could check `if !entitlements.isPro` before setting `paywallReason = .postOnboarding`. Acceptable to ship v1 without — Pro users seeing the celebratory paywall once at onboarding is mildly weird but not broken.

5. **5x dismiss .hitDailyCap** → 6th cap-trip silently does nothing (no paywall, no error). User can verify by tripping cap, reading console for the `[PaywallTrigger] suppressed` log.

## Decisions log

- **D-1 — Modifier-based wiring vs explicit per-call.** Chose modifier (Q4/A) — zero churn at 6 existing call sites, matches design-doc directive "wrap the binding in a coordinator-aware modifier."
- **D-2 — Conditional header vs full PaywallView variant.** Chose header (Q3/B) — preserves brand discipline (one PaywallView variant), small code lift, sufficient celebratory differentiation.
- **D-3 — Sheet vs replacement screen for post-onboarding paywall.** Chose sheet over last onboarding screen (Q2/A) — preserves onboarding step count stability, matches spec line 174 ("Confetti animation → paywall" sheet semantics).
- **D-4 — `.postOnboarding` participates in throttle vs bypasses.** Chose participates — onboarding's natural one-shot character means throttling doesn't matter for first install, but reinstall scenarios get correct throttle behavior.
- **D-5 — No confetti / new ceremony.** YAGNI — header carries the celebratory weight; full animation work would be ~150 lines for marginal lift.
- **D-6 — `.postOnboarding` does NOT check Pro status before firing.** Mild edge case (Pro user reinstalling sees celebratory paywall once) but not worth gating logic. Revisit if beta feedback flags it.

## Risks

- **Risk: modifier change introduces subtle regression in Sub-project 2 gate behavior.** Mitigation: comprehensive integration tests covering all 7 throttle-decision-matrix scenarios; manual smoke validates each gate site fires correctly post-change.
- **Risk: `EnvironmentValues.paywallCoordinator` default instance creates state silos.** If two views accidentally hit the default rather than the injected one, dismiss counts diverge. Mitigation: default coordinator logs a warning in DEBUG; `RootTabView` injection is the only intended path.
- **Risk: post-onboarding paywall shows when user has just installed app — feels rushed.** Mitigation: spec design (Q2/A) places it AFTER the wow moment, not before, so users have experienced value first.
- **Risk: Pro-user-on-reinstall sees celebratory paywall.** Acceptable v1 — see D-6.

## Out of scope (future work)

- **`.trialExpired` trigger** — needs StoreKit `Transaction` expiration listener, deferred to Sub-project 4 or post-launch.
- **Pro-user gate at `.postOnboarding`** — see D-6 risk; revisit on beta data.
- **`.hitClipCountCap` PaywallReason split** — flagged in Sub-project 2 plan; revisit if beta confusion data warrants.
- **A/B testing of celebratory header copy** — no A/B framework in app; if needed, build separately.
- **In-app analytics for paywall conversion** — privacy-first brand promise rules out network telemetry; rely on App Store Connect aggregate data + manual TestFlight feedback.
