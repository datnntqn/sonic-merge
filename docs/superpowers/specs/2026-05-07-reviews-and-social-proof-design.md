# CleanCut Monetization Sub-project 4 — Reviews + Social Proof

**Date:** 2026-05-07
**Status:** Spec — implementation-ready
**Author:** Claude (autonomous mode, user-approved decisions)
**Parent spec:** `docs/superpowers/specs/2026-05-04-monetization-design.md` §"Sub-project sequencing" #4
**Predecessors:** Sub-projects 1-3 shipped to `main` 2026-05-07

## Summary

Sub-project 4 wires the App Store review prompt at the right moments and filters out unhappy users from triggering it. After every successful export, the `ReviewPromptCoordinator` checks gating conditions; if eligible, it presents a `MoodCheckSheet` with three emoji choices. A 😊 tap routes through Apple's `SKStoreReviewController.requestReview(in:)` (Apple may then show its native rating prompt — capped at 3/year per app). 😐 or 😞 taps simply dismiss with no further action. Either path records `lastPromptDate`, locking the 90-day cooldown.

This sub-project deliberately omits the FeedbackForm + mailto: composer scoped in the parent design. The user-driven simplification: unhappy users get filtered out of Apple's rating system (preserving star average), but we don't burden them with "fill out this form" friction. If TestFlight feedback shows we're losing actionable user-pain signal, add a mailto: path back in a future iteration.

Testimonials in `PaywallView` (Sub-project 1, lines 26-30) are hardcoded TestFlight quotes for v1. No new testimonial work in this sub-project — replaced with App-Store-Connect-API-pulled real reviews post-launch.

## Goals

1. **Lift App Store rating average** by routing 😊 users to Apple's native rating prompt.
2. **Avoid 1-star reviews** by filtering 😐/😞 users out of the rating funnel entirely.
3. **Respect Apple's 3-prompts-per-year ceiling** — a 90-day cooldown leaves headroom for at most 4 prompts/year, well under Apple's hard limit.
4. **Stay invisible until value is delivered** — no prompt before user has experienced ≥3 successful exports across ≥3 days install age.
5. **Honor the paywall mutex contract** Sub-project 1 designed: never present a mood-check sheet in a session where the paywall has already shown.

## Non-Goals

- **No FeedbackForm.swift, no mailto: composer.** Removed per user decision — see Decisions §D-1.
- **No real-review pull from App Store Connect API.** v1 ships hardcoded TestFlight testimonials; live-pull deferred to post-launch.
- **No analytics on which mood the user picked.** Privacy-first brand promise rules out tracking. Apple's own dashboards aggregate the rating-prompt outcomes.
- **No custom "rate us" UI in app Settings.** Apple discourages "rate us" buttons; the only path to the App Store rating is via `SKStoreReviewController` after a 😊 tap. (Settings → "Manage subscription" exists; no separate "Rate the app" link.)
- **No paywall throttling changes.** Sub-project 3 already wired `PaywallTriggerCoordinator` with the necessary `hasShownPaywallThisSession` flag; we just consult it.

## Architecture

```
                                                      ┌──────────────────────────┐
                                                      │ PaywallTriggerCoordinator│
                                                      │  · hasShownPaywallThisSession │
                                                      └─────────┬────────────────┘
                                                                │ consults (mutex)
                                                                ▼
┌──────────────────┐                  ┌─────────────────────────────────┐
│ Smart Cut export │ ────────────►   │ ReviewPromptCoordinator         │
│ Denoise export   │ recordExport()  │  · shouldPromptNow()            │
│ Merge export     │                  │  · markPrompted()               │
└──────────────────┘                  │                                 │
                                      │ reads/writes via                │
                                      │ ReviewMetricsStore (UserDefaults)│
                                      └────────┬────────────────────────┘
                                               │ if shouldPromptNow → present
                                               ▼
                                   ┌────────────────────────────┐
                                   │ MoodCheckSheet             │
                                   │  😊 → SKStoreReviewController.requestReview(in:)│
                                   │  😐 → dismiss              │
                                   │  😞 → dismiss              │
                                   └────────────────────────────┘
```

### Components

1. **`ReviewMetricsStore`** — pure persistence layer. UserDefaults-backed. Exposes `installDate: Date`, `exportCount: Int`, `lastPromptDate: Date?`. `installDate` is initialized to `Date()` on first read if missing (so re-install resets the clock cleanly via `Erase All Content`). All writes are atomic (single key per write).

2. **`ReviewPromptCoordinator`** — `@Observable`, `@MainActor`. Composes `ReviewMetricsStore` + `PaywallTriggerCoordinator` (read-only access to `hasShownPaywallThisSession`). Provides:
   - `func recordExport()` — increments `exportCount`. Called by every successful export.
   - `func shouldPromptNow() -> Bool` — checks all gating conditions.
   - `func markPrompted()` — sets `lastPromptDate = Date()`. Called when MoodCheckSheet presents (regardless of which mood the user picks).

3. **`MoodCheckSheet`** — SwiftUI `.sheet`. Three large `Button` rows with emoji + label. Closure-driven: `onSelect: (Mood) -> Void` where `Mood` is a private enum. The sheet itself does NOT call `SKStoreReviewController` — that's the caller's responsibility (separation of concerns: sheet is pure UI).

### Gating thresholds (Profile B — balanced)

| Condition | Threshold |
|---|---|
| Days since `installDate` | ≥ 3 |
| `exportCount` | ≥ 3 |
| Days since `lastPromptDate` (if any) | ≥ 90 |
| `paywallCoordinator.hasShownPaywallThisSession` | == false |

All four must be true for `shouldPromptNow()` to return true. Order: cheapest checks first (paywall mutex is a Bool read; date arithmetic is more expensive).

### Wire-in points

Three export call sites need a one-line addition each (after successful export completes):

```swift
reviewCoordinator.recordExport()
if reviewCoordinator.shouldPromptNow() {
    showMoodCheckSheet = true
    reviewCoordinator.markPrompted()
}
```

Sites:
- `SmartCutStudioContainer.swift` — after Smart Cut export succeeds
- `DenoiseSessionView.swift` — after Denoise export succeeds
- `MixingStationView.swift` — after Merge export succeeds

Each site holds its own `@State var showMoodCheckSheet: Bool` and applies a `.moodCheckSheet(isPresented:)` modifier (analogous to `.paywall(reason:)` from Sub-project 3 — keeps wiring uniform).

## Data flow

### Flow A — happy user post-export

```
1. User taps Export on Smart Cut → export completes successfully
2. Caller writes:  reviewCoordinator.recordExport()
3. Caller writes:  if reviewCoordinator.shouldPromptNow() { showMoodCheckSheet = true }
4. shouldPromptNow checks:
   - days since installDate ≥ 3 ✓
   - exportCount ≥ 3 (just incremented to 4) ✓
   - lastPromptDate is nil (first time) ✓
   - !hasShownPaywallThisSession (no paywall today) ✓
   → returns true
5. MoodCheckSheet presents
6. User taps 😊
7. Sheet calls onSelect(.happy) → caller invokes SKStoreReviewController.requestReview(in: scene)
8. Apple may (its decision) show the system rating prompt
9. Sheet dismisses; markPrompted() already set lastPromptDate at step 5
```

### Flow B — paywall already shown this session

```
1. User has tripped .hitDailyCap earlier in session, paywall shown + dismissed
2. coordinator.hasShownPaywallThisSession == true
3. User does another export → recordExport() runs (still safe)
4. shouldPromptNow returns false (mutex gate)
5. MoodCheckSheet does NOT present
6. lastPromptDate untouched — review prompt is still "available" for next session
```

### Flow C — sad user

```
1-5: same as Flow A
6. User taps 😞
7. Sheet calls onSelect(.sad) → caller's onSelect closure does nothing extra (just dismiss)
8. lastPromptDate is set (from step 5's markPrompted call) — locks 90-day cooldown
   regardless of which mood was picked. This is intentional: if the user is sad
   today, they don't want us asking them again next week.
```

## Error handling

- **`SKStoreReviewController.requestReview(in:)` is no-op if Apple decides not to show.** No error to handle — Apple's API is fire-and-forget. We just call it; user may or may not see anything.
- **`UIWindowScene` not available** (rare — e.g., headless test environment). Guard with `if let scene = ... { requestReview(in: scene) }` — silently skip if no scene. Acceptable: user just sees the MoodCheckSheet dismiss.
- **UserDefaults read returns 0 / nil for missing keys.** That's the correct default: zero exports, no prior prompt date, no install date (initialize on first read).
- **Clock skew (user changed system date backward)** — `lastPromptDate` could be in the future relative to current `Date()`. Compute `Date().timeIntervalSince(lastPromptDate)`; if negative, treat as "elapsed = 0" (never expired) — conservative.
- **Concurrent recordExport() calls** — `@MainActor` constraint on coordinator serializes access; UserDefaults writes are atomic.

## Testing

### `ReviewMetricsStoreTests.swift`

```swift
@Test func freshStoreHasZeroExports() async
@Test func incrementExportPersists() async
@Test func installDateInitializedOnFirstRead() async
@Test func lastPromptDateNilByDefault() async
@Test func setLastPromptDatePersists() async
```

### `ReviewPromptCoordinatorTests.swift`

```swift
@Test func belowExportThresholdSuppresses() async  // 0 / 1 / 2 exports → false
@Test func threeExportsAndOldEnoughInstallAllows() async
@Test func recentInstallSuppresses() async  // installDate < 3 days ago
@Test func paywallShownSessionSuppresses() async
@Test func cooldownActiveSuppresses() async  // lastPromptDate within 90d
@Test func cooldownExpiredAllows() async  // lastPromptDate > 90d ago
@Test func recordExportIncrementsCount() async
@Test func markPromptedSetsLastPromptDate() async
```

### Manual smoke

1. **Fresh install** → simulate by erasing simulator. Run app. Make 3 successful exports across the same day → on the 3rd export, MoodCheckSheet does NOT present (installDate is today, < 3d threshold).
2. **Day-3 install simulation** — temporarily inject `installDate = Date.now.addingTimeInterval(-86400 * 4)` via debug toggle. Make 3 exports → on the 3rd, MoodCheckSheet presents.
3. **Tap 😊** → Apple's system rating prompt may appear (Apple's call). Tap "Not Now" or rate. Sheet dismisses.
4. **Tap 😐 or 😞** → sheet dismisses, no further action.
5. **Try another export same session** → MoodCheckSheet does NOT re-present (cooldown active).
6. **Trip a paywall first then export** → MoodCheckSheet does NOT present (paywall mutex).
7. **Background app → foreground → trip paywall mutex resets** (Sub-project 1 / 3 design) → MoodCheckSheet eligibility restored.

## Decisions log

- **D-1 — No FeedbackForm + mailto: composer.** User-driven simplification 2026-05-07. Original parent-spec design included a sad-path feedback collector via mailto:. Trade-off accepted: we lose actionable user-pain signal but reduce code surface ~80 LOC and avoid maintaining a feedback inbox. Revisit if TestFlight beta produces 1-star reviews citing reasons we'd want to address.
- **D-2 — `markPrompted()` fires regardless of mood selection.** A user who taps 😞 today does NOT want us asking again next week. The 90-day cooldown applies uniformly.
- **D-3 — Profile B gating thresholds (3d / 3 exports / 90d).** Industry-balanced default. CleanCut's audience (podcasters, journalists) is high-intent enough that aggressive (Profile A) wastes Apple's 3-yearly slots; conservative (Profile C) is overkill pre-data. Re-tunable based on TestFlight beta feedback.
- **D-4 — `MoodCheckSheet` is pure UI; rating-controller call lives at the call site.** Keeps the sheet test-isolatable (no SKStoreReviewController dependency in the View). Slightly more wiring at each call site, but better testability.
- **D-5 — `installDate` is initialized lazily on first read.** Equivalent to "the date you first opened the app." Matches user mental model better than "the date the binary was installed."

## Risks

- **Risk: Apple deprecates `SKStoreReviewController` in iOS 18+.** Mitigation: API is still current as of iOS 17. iOS 18 introduced the `requestReview` modifier in SwiftUI but `SKStoreReviewController` continues to work. Re-evaluate if/when iOS 18 becomes our minimum.
- **Risk: 90-day cooldown is too aggressive — we waste prompts on users who might respond positively to a re-ask later.** Mitigation: Profile B is mid-spectrum; 30 / 60 / 120 are alternates if data shows otherwise.
- **Risk: 3-export threshold means low-engagement users never see the prompt — no rating volume.** Mitigation: this is intentional (we want only happy users prompted). If Day-30 active users fall under 3-exports, lower the threshold.
- **Risk: 😞 user encounters the sheet, taps the emoji, sheet dismisses with no acknowledgement → feels dismissive.** Mitigation: include a short "Thanks for the feedback" toast on 😐/😞 dismiss (single line, non-blocking). Cheaper than mailto: form, more graceful than silent dismiss.

## Out of scope (future work)

- **FeedbackForm + mailto: composer** — see D-1; revisit on data.
- **In-app testimonial carousel pulling live App Store reviews** — needs Connect API integration.
- **A/B testing of mood-check copy** — no A/B framework in app.
- **Localized mood-check labels** — v1 English only; localization is a separate cross-cutting initiative.
- **"Rate us" Settings link** — Apple discourages it; no v1 entry.
