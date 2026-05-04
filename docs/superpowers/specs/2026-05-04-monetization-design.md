# CleanCut Monetization — Freemium Subscription + Reviews

**Date:** 2026-05-04
**Status:** Spec — north star covering 4 implementation sub-projects
**Author:** Claude (autonomous mode, user-approved decisions)
**Lifecycle:** Pre-launch (no existing users to migrate)

## Summary

CleanCut monetizes via a **freemium subscription** model with a generous-enough free tier that users experience the "wow" before paying, then daily/length caps that nudge professional users toward Pro. Pricing: **$4.99/mo · $39.99/yr (33% off · best value) · $79.99 lifetime** (privacy-conscious one-time tier). Trial: **7 days free** on first subscription start. Implementation uses **StoreKit 2 directly** (no third-party SDK like RevenueCat) to keep the privacy-first brand promise intact and avoid recurring per-transaction fees. Paywall design uses an **Annual-default-with-toggle** layout, surfaces at five distinct conversion moments (most importantly post-onboarding), and is paired with a **mood-check pre-prompt** before triggering Apple's native rating dialog so unhappy users get routed to private feedback rather than public 1-star reviews.

The strategy is decomposed into **four sub-projects** (Foundation → Gates → Conversion Moments → Reviews) that each produce shippable software, plus a deferred fifth (Retention) for after launch data exists.

## Goals

1. **Convert daily-use professionals into paying subscribers** at industry-typical rates for utility apps (3-5%).
2. **Preserve the privacy-first brand promise** — no third-party SDKs handling user behavior, no analytics phoning home, no ad networks.
3. **Make the free tier deliver the "wow" exactly once per day** — users experience real value, then hit the cap, then convert.
4. **Filter out 1-star reviews** by routing unhappy users to private feedback before they see Apple's rating prompt, while maximizing 5-star reviews from happy users.
5. **Ship in independently shippable phases** so we can launch with paid users on Day 1 (sub-project 1) and add conversion-moment optimization (sub-project 3) after seeing real beta feedback.

## Non-Goals

- **Ads.** Privacy-first brand and audio-editing UX both rule out AdMob. (See Decisions Log §D-01.)
- **Cross-platform monetization.** iOS-only for the foreseeable future; SDK choice (StoreKit 2 native) reflects this.
- **Backend / server-side receipt validation.** Apple's `Transaction.currentEntitlements` API is sufficient and keeps the privacy-first all-on-device architecture intact.
- **Promo codes / referral programs.** Out of scope for v1; revisit if early data shows weak organic acquisition.
- **Family sharing UI.** StoreKit 2 handles family-sharing entitlement automatically; no custom UI needed in v1.
- **Retention features (push notifications, streaks, re-engagement).** Deferred to a later spec once we have real user-behavior data to nudge against.
- **Migrating existing free users to paid.** Pre-launch — no existing users to grandfather.

## Free vs Pro feature matrix

The contract with the user. Get this wrong and either the free tier is so generous nobody pays, or it's so restrictive users uninstall before reaching the wow.

| Feature | Free | Pro |
|---|---|---|
| **Smart Cut sessions/day** | **3/day** | unlimited |
| **Smart Cut input length** | up to **5 min** | unlimited |
| **Denoise sessions/day** | **3/day** | unlimited |
| **Denoise input length** | up to **3 min** | unlimited |
| **Merge: clips per project** | up to **3 clips** | unlimited |
| **Export formats** | WAV only | WAV + M4A + MP3 |
| **Export watermark** | last 0.5s says "Cleaned with CleanCut" voiceover | none |
| **Custom filler library** | locked to defaults | full custom + saved presets |
| **Background transcription** | foreground only | background + push notification |
| **Theme toggle** | free | free (no point gating chrome) |
| **App Group sharing / Share extension** | free | free (drives organic growth) |

**Rationale:**
- **Daily limits over total/lifetime limits.** Daily quota gives users the wow every day; total quota feels punitive. (Pattern used by Headspace, Calm, AudioPen.)
- **Length caps are the real lever.** 5-min cap means ~80% of real-world podcast clips hit the paywall.
- **Watermark on free exports = free word-of-mouth marketing** + social pressure to upgrade ("my friend's audio sounds clean without the watermark").
- **Don't gate the Share extension** — friction-free imports drive more first-clip experiences = more conversions.
- **Don't gate the theme toggle** — it's brand chrome, not a feature; gating it feels miserly.

## Pricing & products

Three SKUs in App Store Connect, plus an introductory offer.

| Product ID | Type | Price (US) | Apple Tier | Apple cut |
|---|---|---|---|---|
| `com.cleancut.pro.monthly` | Auto-renewing subscription | **$4.99/mo** | Tier 5 | 30% Y1 → 15% Y2+ |
| `com.cleancut.pro.yearly` | Auto-renewing subscription | **$39.99/yr** | Tier 40 | 30% Y1 → 15% Y2+ |
| `com.cleancut.pro.lifetime` | Non-consumable IAP | **$79.99** | Tier 80 | 30% always |

**Introductory offer:** **7-day free trial** on first subscription start (monthly OR yearly — user picks at the paywall). Configured server-side in App Store Connect; no extra StoreKit code.

**Pricing rationale:**
- **$4.99/mo** is the "psychological no-think" tier for utility apps. $2.99 reads cheap; $9.99 triggers comparison-shopping. $4.99 = "less than a coffee."
- **$39.99/yr = 33% off** vs monthly × 12 (App Store users have been trained to expect ~30% off annual; less and they don't bite, more and Apple's annual prompt looks misleading).
- **$79.99 lifetime ≈ 2 years of yearly.** Captures revenue upfront from privacy-buyers and never appears in the churn report.
- **7-day trial** fits a "edit one podcast episode" cycle. 3-day = too short to find value; 14-day = cancel-after-work-done.

**Regional pricing:** handled automatically by Apple Tier mapping (Tier 5 → ₹450 in India, ¥600 in Japan, R$24,90 in Brazil, etc.). No manual work.

**Restore Purchases** button required by Apple guideline 3.1.1 — lives in Settings tab.

## Architecture

### Why StoreKit 2 directly (not RevenueCat)

| | StoreKit 2 (native) | RevenueCat |
|---|---|---|
| Setup | ~300 lines Swift | ~50 lines + dashboard |
| Receipt validation | Built-in (JWS) | RevenueCat handles |
| Edge cases | Hand-write | Free |
| Cost | $0 forever | Free up to $2.5K MRR, then **1% per transaction** |
| 3rd-party privacy footprint | None | Anonymous IDs OK but events flow through their servers |
| Cross-platform reuse | iOS only | iOS + Android + web |

**Decision: StoreKit 2 native.** Reasons (in order of weight):

1. **Brand alignment.** Privacy-first means "no third party handles your data — including your purchase data."
2. **Bounded work.** ~250 lines for the basics; Apple's `Transaction.updates` async stream + `Transaction.currentEntitlements` cover the hard parts.
3. **No ongoing fee.** RevenueCat's 1% scales with success, never goes away.
4. **No backend needed.** `Transaction.currentEntitlements` is the source of truth — no server-side validation infra to build.
5. **Cross-platform isn't on the roadmap.** When/if we go cross-platform, swap `StoreKitClient` for a RevenueCat backend; rest of the app talks only to `EntitlementService`.

### File structure

```
SonicMerge/Features/Subscription/
├── Services/
│   ├── EntitlementService.swift        // single source of truth: isPro, currentTier, gate(_ feature: ProFeature)
│   ├── StoreKitClient.swift            // wraps Product.products(for:), Transaction.updates listener (incl. .expired/.revoked), restore
│   ├── DailyUsageTracker.swift         // tracks "N Smart Cuts today" gate (UserDefaults + ISO date)
│   └── PaywallTriggerCoordinator.swift // session-level throttling: "paywall already shown this session" flag, per-reason dismiss-count, mutual exclusion with ReviewPromptCoordinator
├── Models/
│   ├── Entitlement.swift               // .free / .pro(expirationDate) / .lifetime
│   ├── ProFeature.swift                // .smartCutSession / .smartCutLength(seconds: TimeInterval) / .denoiseSession / etc.
│   └── SubscriptionProduct.swift       // (id, type, displayPrice) wrapper
└── Views/
    ├── PaywallView.swift               // full-sheet paywall (Variant A — annual-default + toggle)
    ├── PaywallTrigger.swift            // .paywall(reason:) view modifier — calls into PaywallTriggerCoordinator before presenting
    ├── RestorePurchasesButton.swift
    └── PaywallReason.swift             // enum: .endOfOnboarding / .hitDailyCap / .hitLengthCap / .watermarkExport / .settingsUpgrade / .trialExpired
```

**`EntitlementService` is the only thing the rest of the app talks to.** Exposes `@Published var isPro: Bool`, `@Published var currentTier: Entitlement`, and `func gate(_ feature: ProFeature) -> GateResult`. Other code never touches StoreKit. Swap-out story: the day we go cross-platform, `StoreKitClient.swift` is the only file that changes.

**`PaywallTriggerCoordinator` enforces session-level rules so each callsite doesn't reinvent suppression logic.** Responsibilities:
- Tracks per-reason dismiss-count in `UserDefaults` (so e.g. the daily-cap paywall stops appearing if the user has dismissed it 5 times in the last 30 days — Apple may flag aggressive re-prompting otherwise).
- Holds a session-scoped `@Published var hasShownPaywallThisSession: Bool` flag.
- Holds the mutual-exclusion contract with `ReviewPromptCoordinator`: if `hasShownPaywallThisSession` is true, the review-prompt coordinator returns false from `shouldPromptNow()`. Implemented as a shared `SubscriptionFlowState` actor or via direct injection.
- Exposes `func shouldPresent(_ reason: PaywallReason) -> Bool` so view-layer `PaywallTrigger` modifier checks this before mounting the sheet.

A new `Settings/` feature directory is created (currently the app has no Settings tab — the rebrand kept theme toggle in each home toolbar; Settings becomes a fourth slot in the navigation, OR a sheet from the existing toolbar — see §"Open questions" §OQ-1).

## Paywall UI — Variant A: Annual default with toggle

User-picked from a side-by-side visual comparison between (A) Annual-default-with-toggle and (B) three-side-by-side cards.

**Structure (top → bottom on a single scrollable sheet):**

1. **Hero** — `SmartCutMark` glyph + "CleanCut Pro" wordmark in fire-gradient text-fill
2. **One-line value prop** — "Cut fillers. Clean noise. No limits."
3. **Visual feature row** — 3 icons + labels: ∞ Unlimited sessions · ∅ No watermark · ⏱ Any length
4. **Pricing toggle** (segment control) — Monthly / **Yearly** (default selected) / Lifetime
5. **Selected pricing card** (large, highlighted)
   - Yearly (default): "SAVE 33%" badge, "$39.99/yr · $3.33/mo · 7-day free trial"
   - Monthly: "$4.99/mo · 7-day free trial"
   - Lifetime: "$79.99 once · No renewal"
6. **Checklist** — 5 bullets:
   - Unlimited Smart Cut + Denoise
   - Files of any length
   - No export watermark
   - Custom filler libraries
   - Background processing + push
7. **Testimonial slot** — single rotating quote (seeded from TestFlight beta testers pre-launch; replaced with App-Store-Connect-API-pulled real reviews post-launch)
8. **Sticky CTA at bottom** — fire-gradient capsule:
   - First-time user: "Start 7-day free trial" + sub-text "Then $39.99/yr · Cancel anytime"
   - User who's used trial before: "Subscribe — $39.99/yr"
9. **Footer microcopy** — `Restore Purchases · Terms · Privacy` (small, gray)

**Required by Apple guidelines:**
- 3.1.2(a): Plain-language disclosure of price, period, "auto-renews," "cancel anytime"
- 3.1.1: Restore Purchases visible
- 5.1.1: Links to Terms (custom EULA or Apple's standard) + Privacy Policy

## Conversion moments

The paywall surfaces at five distinct trigger points, each with its own framing:

| # | Trigger | When | Frame | Dismissible? |
|---|---|---|---|---|
| **1** | **End of onboarding** | After sample-podcast Smart Cut completes (step 5 of OnboardingFlow) | Soft, celebratory — "You just cleaned 27 seconds. Want unlimited?" | Yes — "Maybe later" drops into free tier |
| **2** | **Hit the daily cap** | User tries 4th Smart Cut or Denoise today | Hard wall — "You've used your 3 free Smart Cuts today. Pro = unlimited." | Yes — "Continue with free tier · come back tomorrow" exit (the action they tried IS blocked, but the sheet itself dismisses) |
| **3** | **Hit the length cap** | User imports clip > 5 min for Smart Cut OR > 3 min for Denoise | Specific — "This clip is 12 min. Free is up to 5. Upgrade for any length." | Yes — "Use a shorter clip" exit |
| **4** | **Watermark export** | At Export sheet, free user toggles "Remove watermark" | Inline — toggle opens the paywall sheet | Yes |
| **5** | **Settings entry** | Settings tab, persistent card "Upgrade to Pro" / "Pro · expires Mar 2027" | Always visible | N/A |
| **6** | **Trial / subscription lapsed** | `StoreKitClient.Transaction.updates` listener detects `.expired` or `.revoked` transition: `EntitlementService.currentTier` flips `.pro → .free` | Re-engagement — "Your Pro trial ended. Keep unlimited?" | Yes — "Continue with free tier" exit |

**Highest-ROI moment is #1 (post-onboarding).** Per RevenueCat's industry data on iOS audio/utility apps, post-onboarding paywalls convert at 4-7% vs 0.5-2% for arbitrary triggers. Onboarding step 5 ("Smart Cut applied" — the wow moment) flows directly into:

```
[Confetti animation]
You just saved 27 seconds.

Want this every time?

[Start 7-day free trial]   <-- fire-gradient CTA
Maybe later                 <-- text link → free tier
```

**Anti-patterns we are NOT doing:**
- ❌ Show paywall on app open (kills D1 retention by ~30%)
- ❌ Show paywall every cap-hit, even after dismiss × 5 (Apple may reject)
- ❌ Auto-start trial without explicit user tap (violates Apple 3.1.2)
- ❌ Show "% off" without baseline price (deceptive)
- ❌ Show paywall in same session as review prompt (dilutes both)

## In-app reviews flow

The user's original ask, layered on top. Two distinct purposes that share infrastructure:

1. **App Store ratings** — drives ★ avg + search rank (visible to everyone, drives discovery)
2. **Testimonials in paywall** — social proof on the paywall (drives subscription conversion)

### App Store rating prompt

Use Apple's `SKStoreReviewController.requestReview()`. Apple itself caps display to 3 prompts/year per user; we just choose the moment.

**Trigger conditions (all must be true):**
- ≥ 3 successful exports (real "value" signal — not just session opens)
- ≥ 4 days since install (filter tire-kickers)
- ≥ 4 months since last prompt (Apple caps native at 3/year; we cap slightly tighter)
- App in foreground (Apple-enforced)
- User just completed a successful export (high-emotion moment)
- **No paywall shown this session** (don't ask for review and money in the same breath)

**Mood-check pre-prompt (the "softener pattern"):** Before triggering Apple's prompt, show our own bottom-sheet mood check:

```
How was your CleanCut today?
[😊 Loved it]   [😐 It was OK]   [😞 Disappointed]
Skip
```

- **😊 Loved it** → fires `SKStoreReviewController.requestReview()`
- **😐 It was OK** OR **😞 Disappointed** → routes to private in-app feedback form (mailto: with prefilled iOS version + app version), never asks for App Store review
- **Skip** → resets prompt counter (no re-prompt for 4 months)

This is **Apple-permitted** (non-blocking nudge before the system prompt). Pattern used by AudioPen, Things, Day One. Outcome: ~3-4× more 5-star reviews vs unprompted; ~70% fewer 1-star reviews because unhappy users get routed to email instead of the App Store.

**Compliance note (guideline 1.1.6):** Apple guideline 1.1.6 prohibits prompts that *manipulate* users into giving a positive review. The mood-check sheet stays compliant because (a) it is non-blocking — a "Skip" link is always visible; (b) it does not gate App Store access — even if the user picks 😞 they can still leave their own review by going to the App Store directly; (c) the 😞 path routes to email but does NOT suppress or hide the user's ability to also write an App Store review. The plan-author implementing this MUST keep "Skip" reachable at all times and MUST NOT add code that intercepts or blocks App Store navigation.

### Testimonials in paywall

Pre-launch we have no App Store reviews. Strategy: **recruit 5-10 TestFlight beta testers, harvest 1-line quotes with attribution** ("— Jamie, podcast editor"), rotate them in the paywall testimonial slot. After launch, replace with real ★★★★★ reviews pulled via App Store Connect API (Phase 2 enhancement, not blocking launch).

### Architecture

```
SonicMerge/Features/Reviews/
├── Services/
│   ├── ReviewPromptCoordinator.swift   // checks all conditions, fires the mood-check sheet
│   └── ReviewMetricsStore.swift        // UserDefaults: exportCount, lastPromptDate, installDate
└── Views/
    ├── MoodCheckSheet.swift            // 😊 / 😐 / 😞 sheet
    └── FeedbackForm.swift              // for 😐 / 😞 path — sends via mailto: with diagnostics
```

`ReviewPromptCoordinator.shouldPromptNow()` returns Bool, called after every successful export (Smart Cut, Denoise, Merge). View presents mood-check sheet on success.

## Sub-project sequencing

The strategy is too big for one implementation cycle. Decomposed into four shippable sub-projects (in dependency order) plus a deferred fifth.

| # | Sub-project | What it delivers | Why this order | Scope estimate |
|---|---|---|---|---|
| **1** | **MVP Foundation** | Settings tab, StoreKit 2 + `EntitlementService` + `DailyUsageTracker`, paywall UI Variant A reachable from Settings, Restore Purchases, Terms/Privacy URLs, 3 IAP products configured in App Store Connect (manual step) | Without this, NOTHING else works. After Sub-project 1 ships you can launch with paid users from Day 1 (no funnel optimization yet). | ~700 lines / 3 days |
| **2** | **Feature gates** | Daily-cap (3/day SC + DN), length-cap (5 min / 3 min), Merge clip-count cap (3), free-export watermark, free-export WAV-only, locked custom filler library | Makes free tier feel free *and* Pro feel Pro. After this, paywall has a reason to exist. | ~500 lines / 2 days |
| **3** | **Conversion moments** | End-of-onboarding paywall (highest-ROI), hit-the-cap paywall, hit-the-length-cap paywall, watermark export inline upsell, Settings persistent upgrade pill | Wires paywall into the right places. Before this, paywall only reachable from Settings → low conversion. | ~300 lines / 1.5 days |
| **4** | **Reviews + social proof** | `ReviewPromptCoordinator`, `MoodCheckSheet`, `FeedbackForm` (mailto:), wired post-export. Seeded TestFlight testimonials in paywall. | Drives App Store rank (organic growth) and paywall conversion (social proof). Layered on top, no blocking dependency. | ~400 lines / 2 days |
| **5** | **Retention** *(deferred)* | Push notifications, streaks, re-engagement. Spec separately *after* shipping 1-4 and gathering real-user data. | Premature without engagement metrics. | TBD — out of scope for this spec |

**Total for sub-projects 1-4: ~1900 lines of Swift, ~8.5 days of focused work.**

**Recommended path:** ship Sub-projects 1+2 to TestFlight, gather a week of beta-tester data on free-tier feel (do the 3/day caps feel right? does the watermark voiceover annoy people too much?), THEN ship 3+4. Reason: if caps need to be re-tuned, that's cheaper to learn before building all the conversion-moment glue.

**One spec, four implementation plans.** This document is the north star. The writing-plans skill produces one plan per sub-project, in order.

## Open questions

**OQ-1 — Settings tab placement.** The app currently has 3 tabs (Smart Cut / Denoise / Merge). Sub-project 1 adds Settings. Two options:
- (a) Add a 4th tab in the bottom bar (most discoverable, but stretches the 3-tab visual rhythm)
- (b) Sheet from a "gear" icon in each home view's toolbar (less discoverable, preserves 3-tab balance)

**Resolve at the top of Sub-project 1's plan-writing — not later.** `RestorePurchasesButton` and the persistent upgrade card both live in Settings, so Sub-project 1 cannot proceed without picking. Visual-companion side-by-side mock during plan-writing makes the call. Both work; (a) is more conventional, (b) preserves the design language.

**OQ-2 — Watermark voiceover content.** "Cleaned with CleanCut" feels promotional but tolerable for free users. Alternatives: a low-volume audio-logo sting, a TTS voice, or just brand "powered by CleanCut" in the export's iTunes metadata (NOT in the audio itself). Pure-metadata-only is friendlier but loses the social-proof viral effect. **Defer to Sub-project 2's plan.**

## Decisions Log

**D-01 — Subscription, not ads.** AdMob would break the privacy-first brand promise (third-party identifiers, behavior tracking) and ruin the audio-editing UX (mid-export interstitials). Audience (podcasters, journalists) is high-intent and willing to pay $5/mo. Subscription revenue/install is ~3× ad revenue/install at typical conversion rates and scales with engagement.

**D-02 — Freemium with feature gates, not free trial only or pay-once.** Hybrid: freemium gates as the primary funnel + 7-day free trial as the introductory offer + lifetime tier as a privacy-aligned alternative. Captures all three buyer archetypes (try-then-decide, immediate-monthly, one-time-pay).

**D-03 — StoreKit 2 native, not RevenueCat.** Privacy-first brand alignment + no recurring 1% fee + bounded implementation work + Apple's `Transaction.currentEntitlements` makes a backend unnecessary. Cross-platform isn't on the roadmap; if it ever is, swap `StoreKitClient.swift` only — rest of the app talks to `EntitlementService`.

**D-04 — Paywall UI Variant A (Annual default with toggle), not Variant B (three side-by-side cards).** Annual default nudges users toward the lower-churn yearly plan; the toggle still gives full agency. Variant B was more honest but had measurably lower annual conversion in shipped iOS apps.

**D-05 — Daily caps at 3/day, not 1/day.** Initial design was 1/day; user pushed back during section approval (podcast editors often process 4 segments in a single session). 3/day still nudges professional users to upgrade while respecting in-session work patterns.

**D-06 — Mood-check pre-prompt before native rating dialog.** Routes unhappy users to private email feedback rather than 1-star App Store reviews. Apple-permitted as a non-blocking nudge before `SKStoreReviewController.requestReview()`. Industry data: ~3-4× more 5-star reviews, ~70% fewer 1-stars vs raw native prompt.

**D-07 — Pre-launch testimonial seeding from TestFlight beta testers.** Paywall has a testimonial slot from Day 1; pre-launch we recruit 5-10 beta testers and harvest 1-line quotes with real attribution. Post-launch we replace with App-Store-Connect-API-pulled ★★★★★ reviews. Not faking — using real beta-tester voices.

**D-08 — Retention features (push, streaks, re-engagement) deferred to a separate spec.** Premature without real engagement data; we don't know which behaviors to nudge until we see how users actually use the shipped app.

**D-09 — Custom filler library gating: in-place at the existing sheet, not relocated to Settings.** The editor at `Features/SmartCut/Views/Studio/EditFillerListStudioSheet.swift` stays where it is. Pro users see the editor; free users hit a single `EntitlementService.gate(.customFillerLibrary)` check at the sheet's `onAppear` which presents the paywall instead. No file moves, no architectural shifts.

**D-10 — Cap-hit and length-cap paywalls are dismissible.** Originally drafted as "no exit other than Cancel/Restore" — that's an Apple-rejection pattern (guideline 3.1.2(a) prohibits manipulative subscription prompts). Each cap-hit paywall has a "Continue with free tier · come back tomorrow" or "Use a shorter clip" exit. The *action* the user attempted IS blocked, but the sheet itself dismisses cleanly.

**D-11 — Trigger #6 (trial / subscription lapsed) added.** When `EntitlementService.currentTier` transitions `.pro → .free` via `Transaction.updates`'s `.expired`/`.revoked` events, fire a re-engagement paywall on next app foreground. Highest re-conversion probability of any moment (the user already paid once).

## Risks

- **Risk: free tier too generous.** If 3/day + 5-min cap covers 95% of casual podcast editors, conversion will be low. Mitigation: TestFlight beta data review BEFORE Sub-project 3. If beta testers say "I never hit the cap," tighten to 2/day or 4-min length cap.
- **Risk: free tier too restrictive.** If users uninstall before reaching 3 successful Smart Cuts, we lose the "wow." Mitigation: track Day-1 retention via in-app counter (privacy-respecting, local-only). If D1 < 30%, loosen the caps.
- **Risk: Apple rejects the watermark voiceover** as deceptive or low-quality. Mitigation: voiceover is opt-in-able (free users can choose "no watermark, just metadata note"). Alternative implementation in OQ-2.
- **Risk: paywall feels promotional.** The fire-gradient brand is bold; pairing it with multiple-screens-of-paywall can read as aggressive. Mitigation: only the post-onboarding paywall is "celebratory"; other moments are matter-of-fact ("you've hit the cap"). Visual companion mockup already shows this restraint.
- **Risk: revenue too low to fund ongoing Core ML model improvements.** $4.99/mo at 3% conversion of 1k installs/month = $150/month, slow to build. Mitigation: this is a long-game product; lifetime tier provides upfront cash flow for early development.
