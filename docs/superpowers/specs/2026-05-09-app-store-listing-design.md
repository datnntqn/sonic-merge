# App Store Listing — CleanCut v1.0 (Design Spec)

**Status:** Approved (sections 1–6, dialog log: `.superpowers/brainstorm/91060-1778318614/`)
**Date:** 2026-05-09
**Bundle ID:** `com.dtech.cleancut` · **Marketing version:** 1.0 · **Build:** 1
**Locale scope:** `en-US` primary. Other locales out of scope for v1.0 (deferred to a localization spec).

This spec is the single source of truth for every text field that goes into App Store Connect for the v1.0 submission. Implementation plan (separate doc) covers operational steps — ASC entry, screenshot rendering, encryption compliance, privacy nutrition label, build upload, TestFlight, App Review submission. This spec only locks the **content**.

The content was approved through an interactive brainstorm; the per-section dialog and the HTML preview that won approval live at `.superpowers/brainstorm/91060-1778318614/listing-preview.html`.

---

## 1. App Name + Subtitle

| Field | Value | Count |
|---|---|---|
| **App Name** (App Store + Home Screen) | `CleanCut: Cut, Clean & Merge` | 28 / 30 |
| **Subtitle** (under app name on storefront) | `Cleaner audio. On your iPhone.` | 30 / 30 |

**Indexing notes (used by Section 5 — Keywords):** Apple already indexes every word in App Name + Subtitle. Words that DO NOT need to appear again in the keyword field: `cut`, `clean`, `cleaner`, `merge`, `audio`, `iphone`.

**Why this name:** Keeps the brand mark `CleanCut` first (App Store search ranks the brand name highly), then the disambiguator `Cut, Clean & Merge` packs the three feature-verbs and matches the three-tab UI (Smart Cut / Denoise / Merge). The `:` separator is the iOS naming convention (Procreate Pocket, Things 3, Bear).

**Why this subtitle:** "Cleaner audio" telegraphs the moat (quality output) and "On your iPhone" is the privacy moat in plain English — it bypasses the loaded "on-device" jargon while saying the same thing. Reads as a benefit, not a spec.

---

## 2. Promotional Text

| Field | Value | Count |
|---|---|---|
| **Promotional Text** (top of Description, editable post-launch without re-review) | `Trim filler words, kill background noise, and stitch takes into one clean file. AI audio editing that runs entirely on iPhone — no cloud, no uploads, no waiting.` | 161 / 170 |

**Why this copy:** Three feature-verbs in the first 8 words (matches the three tabs and the App Name disambiguator). Second sentence collapses the moat (`AI` + `entirely on iPhone` + `no cloud`) into a single readable line. The "no waiting" is a side-benefit — on-device runs at local network speed, not server speed.

**Editable lever:** Promo Text can be updated without resubmitting for review. Use it to A/B copy after launch (e.g., react to a competitor announcement, surface a seasonal offer, change emphasis based on conversion data).

---

## 3. Description Body

Full body, ~3,400 chars / 4,000 max. Section blocks below are the order they appear in the body. App Store iOS shows the first ~5–8 lines of the Description above a "more" tap — the **HERO** block is engineered to be entirely above that fold.

### Block A — HERO (above the fold)

> **Cut filler words. Clean background noise. Merge takes into one file.**
>
> CleanCut is an audio editor for iPhone with three tools — Smart Cut, Denoise, and Merge. Every step runs on-device. **Your audio never leaves your phone.**

### Block B — SMART CUT — TRIM WHAT YOU DIDN'T MEAN TO SAY

> Smart Cut listens for filler words ("um," "uh," "like," and any word you teach it), long silences, and dead air, then proposes an edit. Every cut shows on a waveform timeline before export — nothing is removed without your review. Supports multiple recognition languages; set the locale per session. Includes an auto-generated transcript you can copy or export as .txt, .srt, or .vtt.

### Block C — DENOISE — PULL VOICE OUT OF THE ROOM

> Powered by DeepFilterNet3, an on-device neural network built for speech. An intensity slider lets you taste the result before committing. An A/B toggle plays the original next to the cleaned version so you can hear exactly what changed. Works on real-world audio: subway commutes, busy cafés, humming offices, the back seat of a moving car.

### Block D — MERGE — STITCH CLIPS INTO ONE FILE

> Drag clips onto a timeline, set crossfades, export as M4A or WAV. Loudness is auto-normalized to broadcast standard (BS.1770 LUFS) so volume jumps between clips disappear. Drag-to-reorder, scrub-to-preview, clean export sheet — no DAW, no learning curve.

### Block E — ON-DEVICE. ALWAYS.

> CleanCut runs entirely on your iPhone. No upload. No server. No analytics SDK. No third-party tracker. The transcription model, the noise-reduction model, and every edit you make stay on the device. Turn on airplane mode — CleanCut still works.

### Block F — FREE FOREVER, OR GO PRO

> Everything you need to clean a daily voice memo is free: 3 Smart Cut + 3 Denoise sessions a day, files up to 5 min (Smart Cut) or 3 min (Denoise), unlimited Merge with up to 3 clips, WAV export.
>
> CleanCut Pro removes every limit:
> · Unlimited sessions, any length
> · Export to M4A, MP3, or WAV
> · No watermark
> · Custom filler-word libraries
> · Background processing with push notifications

### Block G — PRICING

> · $4.99 / month
> · $39.99 / year (save 33%) — 7-day free trial included
> · $79.99 once — lifetime access, no renewal
>
> Restore Purchases lives in Settings. Cancel anytime.

### Block H — BUILT FOR iPHONE, NOT PORTED TO IT

> · iOS Share Extension — clean a voice memo from Voice Memos or Mail without leaving the app you're in
> · Background processing with system push notifications when long files finish
> · Files app and iCloud Drive support for import and export
> · Light and dark mode, both first-class

### Block I — Closing

> CleanCut is for iOS-first podcasters, journalists, and anyone who records voice and wants it to sound like the room sounded — minus the ums, hisses, and silences. Audio never leaves your phone. That's the only deal we make.

### Block J — Footer disclosures (Apple-required for IAP / subscriptions)

> Privacy Policy · Terms of Use · Support
>
> Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. Manage in Settings → Apple ID → Subscriptions.

**Sync requirement:** Block F (Free vs Pro) and Block G (Pricing) must EXACTLY match the in-app paywall (`PaywallView`) and the StoreKit products in `Configuration/CleanCut.storekit`. If pricing changes, this spec, the paywall, and ASC must update together. Mismatch is a common App Review rejection ("misleading metadata").

**Pricing audit (2026-05-09):**
- Spec says: `$4.99/mo · $39.99/yr · $79.99 lifetime`
- `Configuration/CleanCut.storekit` currently has: `$19.99/mo · $39.99/yr · $39.99 lifetime`
- **MISMATCH.** Resolution must happen in the implementation plan (decide which is canonical, then update the other). Flag for the plan author.

---

## 4. What's New (v1.0)

| Field | Value | Count |
|---|---|---|
| **What's New** (release notes) | (see below) | 213 / 4000 |

```
Day one.

Audio editing that doesn't ask for the cloud. Smart Cut, Denoise,
and Merge — the whole pipeline runs on your iPhone. Your audio
never leaves the device.

Welcome to CleanCut.
```

**Why this copy:** Manifesto direction (vs welcome-with-bullets or origin-story). Three lines of substance + one closer. The first three lines fit above the "more" fold on the iPhone update sheet. Echoes the hero "On-device. Always." (Block E) without literal repeat. The closer "Welcome to CleanCut." signals first-version (the convention is to use What's New as a welcome at v1.0; for v1.x updates the format will switch to bulleted changelog).

---

## 5. Keywords

| Field | Value | Count |
|---|---|---|
| **Keywords** (comma-separated, no spaces) | `ai,podcast,editor,denoise,noise,filler,silence,voice,memo,transcribe,recorder,offline,interview` | 96 / 100 |

**Reasoning per term:**

| Term | Why included |
|---|---|
| `ai` | Search head-term, high volume, high-intent for "AI audio" |
| `podcast` | Primary audience verb |
| `editor` | Combines: "podcast editor", "audio editor", "voice editor" |
| `denoise` | Brand-feature term (hits "denoise app", "denoise audio") |
| `noise` | High-volume search; Apple does not always stem `denoise` → `noise` |
| `filler` | Brand-feature term ("filler word remover" head-term) |
| `silence` | Combines: "remove silence", "silence detector" |
| `voice` | Combines: "voice memo", "voice cleaner", "voice editor" |
| `memo` | Combines with `voice` to rank for "voice memo" (Apple-app collision) |
| `transcribe` | Combines: "transcribe audio", "transcribe podcast", "transcribe voice" |
| `recorder` | Combines: "voice recorder", "audio recorder" |
| `offline` | Privacy moat in search vocabulary (people search "offline transcription") |
| `interview` | High-intent for journalist segment (low volume but converts) |

**Excluded and why:**
- `cut`, `clean`, `cleaner`, `merge`, `audio`, `iphone` — already indexed via App Name + Subtitle
- `private` — well-covered by `offline` for search behavior; `private` reads better in description copy than as a search term
- `cleanvoice`, `descript`, `riverside` — competitor names, App Review rejection risk (Apple guideline 2.3.7)
- `ums`, `uhs`, `hesitations` — too long-tail, won't rank
- `podcaster` — adds 1 char per use of the word but doesn't unlock new combos `podcast` doesn't already hit

---

## 6. Screenshots — captions & arc

5 frames, 1 brand arc. Render at iPhone 6.9" (required) and iPhone 6.5" (compatibility shim). Caption overlays use the brand display font; sublines use the brand body font. Backgrounds use the existing app's `PremiumBackground` gradient (indigo `#5856D6` → lime `#A7C957`) so the storefront preview reads as continuous with the app interior.

| # | Headline (≤40 chars) | Subline (≤55 chars) | Visual |
|---|---|---|---|
| **1** | **On-device. Always.** | AI audio editing that never leaves your iPhone. | Hero — app icon on indigo→lime gradient + tagline. Closer-to-cover tone, no UI shown. |
| **2** | **Cut filler words. Automatically.** | Detect ums, uhs, and silences. Review every cut. | Smart Cut studio — waveform with red strike-through bars over detected fillers, AI Orb at top. |
| **3** | **Pull voice out of the room.** | DeepFilterNet3, on your iPhone. | Denoise A/B view — original waveform left, denoised right, intensity slider visible. |
| **4** | **Stitch takes into one file.** | Crossfades + auto-loudness. No DAW. | Merge timeline — 3 clips with crossfade pills, "MERGE" CTA visible at bottom. |
| **5** | **Airplane mode? Still works.** | No cloud. No upload. No tracker. | Closer — Settings/About screen with airplane mode badge in status bar; processing progress bar shown to prove it's working offline. |

**Arc shape:** Frame 1 (moat declaration) → Frames 2-3-4 (one frame per tool, in tab order) → Frame 5 (moat proof). The arc opens with a claim and closes with the receipt. Pricing is intentionally NOT a screenshot — it's reachable in-app via Settings; putting price on the storefront leaves no room to reduce friction at conversion time and risks "misleading" rejection if the displayed price ever drifts from StoreKit (see Block G note).

**No App Preview video for v1.0.** Reason: producing a 15–30s App Preview video requires UI capture + audio bed + caption animation, and adds 2-3 days of motion work without measurable storefront-conversion lift for utility apps at launch. Revisit at v1.1 if storefront CVR is below 4%.

---

## ASC field map (for the implementation plan)

| ASC field | Source in this spec |
|---|---|
| App Information → App Name | §1 App Name |
| App Information → Subtitle | §1 Subtitle |
| App Information → Privacy Policy URL | (TBD — implementation plan must define the hosted URL; spec stops at content) |
| Pricing & Availability | §3 Block G (must reconcile with `Configuration/CleanCut.storekit`) |
| Version Information → Promotional Text | §2 |
| Version Information → Description | §3 Blocks A-J concatenated, in order |
| Version Information → Keywords | §5 |
| Version Information → Support URL | (TBD — implementation plan) |
| Version Information → Marketing URL (optional) | (skip for v1.0) |
| Version Information → What's New | §4 |
| Version Information → Screenshots (6.9" + 6.5") | §6 |
| In-App Purchases → Subscription metadata | §3 Block F + Block G (must reconcile prices) |
| App Review Information → Review notes | (TBD — implementation plan; must include "speech recognition runs on-device, no test account needed; for IAP test use sandbox tester [TBD]") |

---

## Out of scope for this spec

The following are necessary for the actual submission but are operational, not content:

1. **Encryption export compliance** — `ITSAppUsesNonExemptEncryption` is missing from `SonicMerge/Info.plist`. Without it, every upload prompts the App Store Connect compliance question. Implementation plan must add it (likely `false` since the app uses only Apple-system encryption — Speech, on-device CoreML, no custom crypto).
2. **Privacy Manifest (`PrivacyInfo.xcprivacy`)** — Apple-required since 2024 for any app that links a required-reason API. The app touches `UserDefaults`, `BGTaskScheduler`, and file timestamps; manifest must declare reasons. Implementation plan owns this.
3. **Privacy Nutrition Label** in App Store Connect → "Data Used to Track You" / "Data Linked to You" — for CleanCut both should be **None** (the on-device promise). Implementation plan owns the form-filling.
4. **Privacy Policy URL + Terms URL hosting** — the description footer (Block J) and the in-app paywall both link to these URLs; they must be live before submission. Spec does not own URL hosting.
5. **Screenshot rendering** — this spec defines captions; implementation plan owns the actual PNG generation (5 frames × 6.9" + 5 frames × 6.5" = 10 PNGs minimum).
6. **Pricing reconciliation** — see §3 Block G note. The mismatch between this spec ($4.99/mo, $79.99 lifetime) and `Configuration/CleanCut.storekit` ($19.99/mo, $39.99 lifetime) MUST be resolved in the implementation plan — open question OQ-1 below.
7. **TestFlight + App Review submission flow** — operational, owned by the implementation plan.
8. **Localization beyond en-US** — deferred. If the v1.0 plan adds localizations, each becomes its own listing-content spec (App Name and Keywords don't transliterate; Subtitle and Description need real translation).

---

## Open questions for implementation plan

- **OQ-1: Reconcile pricing.** Spec says `$4.99/mo · $39.99/yr · $79.99 lifetime`. `Configuration/CleanCut.storekit` says `$19.99/mo · $39.99/yr · $39.99 lifetime`. Yearly matches. Monthly and lifetime do not. Three resolution paths: (a) update `.storekit` and ASC products to spec prices; (b) update spec (this doc) to `.storekit` prices; (c) negotiate a third tier. Implementation plan must pick one BEFORE creating the IAP products in App Store Connect — IAP product price tiers are difficult to change after a product has been live.
- **OQ-2: Hosting for Privacy Policy + Terms URLs.** Implementation plan must designate where these are hosted (GitHub Pages? Personal domain? Notion published page?). Both URLs must be live before App Review can pass.
- **OQ-3: Demo / review notes.** Apple App Reviewer will not have a sandbox Apple ID with active Pro entitlement by default. Implementation plan must include exact review-notes copy that describes (a) speech recognition runs locally, no internet required; (b) IAP can be exercised in sandbox with no special setup; (c) the test path (open Settings → Upgrade to Pro → choose any tier).
