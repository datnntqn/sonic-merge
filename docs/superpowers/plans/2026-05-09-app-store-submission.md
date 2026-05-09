# CleanCut v1.0 — App Store Submission Plan

> **Spec source:** `docs/superpowers/specs/2026-05-09-app-store-listing-design.md`
> **Bundle ID:** `com.dtech.cleancut` · **Team:** `XX2XG7FF3F` · **Marketing:** `1.0` · **Build:** `1`
> **Goal:** ship CleanCut v1.0 to the App Store.
>
> Every block of copy that goes into App Store Connect is in a fenced code block below — click the copy icon in your editor.

---

## Section 0 — Paste-ready copy (App Store Connect fields)

### 0.1 — App Name (App Information → Name) · 28/30

```
CleanCut: Cut, Clean & Merge
```

### 0.2 — Subtitle (App Information → Subtitle) · 30/30

```
Cleaner audio. On your iPhone.
```

### 0.3 — Promotional Text (Version → Promotional Text) · 161/170

```
Trim filler words, kill background noise, and stitch takes into one clean file. AI audio editing that runs entirely on iPhone — no cloud, no uploads, no waiting.
```

### 0.4 — Description (Version → Description) · ~3.4k/4k

```
Cut filler words. Clean background noise. Merge takes into one file.

CleanCut is an audio editor for iPhone with three tools — Smart Cut, Denoise, and Merge. Every step runs on-device. Your audio never leaves your phone.

SMART CUT — TRIM WHAT YOU DIDN'T MEAN TO SAY
Smart Cut listens for filler words ("um," "uh," "like," and any word you teach it), long silences, and dead air, then proposes an edit. Every cut shows on a waveform timeline before export — nothing is removed without your review. Supports multiple recognition languages; set the locale per session. Includes an auto-generated transcript you can copy or export as .txt, .srt, or .vtt.

DENOISE — PULL VOICE OUT OF THE ROOM
Powered by DeepFilterNet3, an on-device neural network built for speech. An intensity slider lets you taste the result before committing. An A/B toggle plays the original next to the cleaned version so you can hear exactly what changed. Works on real-world audio: subway commutes, busy cafés, humming offices, the back seat of a moving car.

MERGE — STITCH CLIPS INTO ONE FILE
Drag clips onto a timeline, set crossfades, export as M4A or WAV. Loudness is auto-normalized to broadcast standard (BS.1770 LUFS) so volume jumps between clips disappear. Drag-to-reorder, scrub-to-preview, clean export sheet — no DAW, no learning curve.

ON-DEVICE. ALWAYS.
CleanCut runs entirely on your iPhone. No upload. No server. No analytics SDK. No third-party tracker. The transcription model, the noise-reduction model, and every edit you make stay on the device. Turn on airplane mode — CleanCut still works.

FREE FOREVER, OR GO PRO
Everything you need to clean a daily voice memo is free: 3 Smart Cut + 3 Denoise sessions a day, files up to 5 min (Smart Cut) or 3 min (Denoise), unlimited Merge with up to 3 clips, WAV export.

CleanCut Pro removes every limit:
· Unlimited sessions, any length
· Export to M4A, MP3, or WAV
· No watermark
· Custom filler-word libraries
· Background processing with push notifications

PRICING
· $4.99 / month
· $39.99 / year (save 33%) — 7-day free trial included
· $79.99 once — lifetime access, no renewal

Restore Purchases lives in Settings. Cancel anytime.

BUILT FOR iPHONE, NOT PORTED TO IT
· iOS Share Extension — clean a voice memo from Voice Memos or Mail without leaving the app you're in
· Files app and iCloud Drive support for import and export
· Light and dark mode, both first-class

(Background processing with push notifications is a CleanCut Pro feature — see "Free Forever, or Go Pro" above.)

CleanCut is for iOS-first podcasters, journalists, and anyone who records voice and wants it to sound like the room sounded — minus the ums, hisses, and silences. Audio never leaves your phone. That's the only deal we make.

Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. Manage in Settings → Apple ID → Subscriptions.
```

> ⚠ The PRICING block above must match Decision 1 (§1.1). If you choose the other path, edit the four price lines (`$4.99 / month` and `$79.99 once`) before pasting.

### 0.5 — Keywords (Version → Keywords, no spaces) · 95/100

```
ai,podcast,editor,denoise,noise,filler,silence,voice,memo,transcribe,recorder,offline,interview
```

### 0.6 — What's New in This Version · 185/4000

```
Day one.

Audio editing that doesn't ask for the cloud. Smart Cut, Denoise, and Merge — the whole pipeline runs on your iPhone. Your audio never leaves the device.

Welcome to CleanCut.
```

### 0.7 — Screenshot caption overlays (5 frames, both 6.9" + 6.5")

Frame 1 — Hero / brand promise:
```
On-device. Always.
```
```
AI audio editing that never leaves your iPhone.
```

Frame 2 — Smart Cut:
```
Cut filler words. Automatically.
```
```
Detect ums, uhs, and silences. Review every cut.
```

Frame 3 — Denoise:
```
Pull voice out of the room.
```
```
DeepFilterNet3, on your iPhone.
```

Frame 4 — Merge:
```
Stitch takes into one file.
```
```
Crossfades + auto-loudness. No DAW.
```

Frame 5 — Privacy closer:
```
Airplane mode? Still works.
```
```
No cloud. No upload. No tracker.
```

### 0.8 — App Review Information → Review Notes (paste before submitting)

```
CleanCut is an offline audio editor. Every AI step (filler-word detection via Apple Speech.framework, noise reduction via the on-device DeepFilterNet3 Core ML model) runs on the device. The app never makes network calls; you can verify by enabling Airplane Mode and using Smart Cut or Denoise — both still work end-to-end.

No demo account is needed. To exercise the full feature set:

1. Open the app.
2. Smart Cut tab → tap the large center button → pick any audio file (a 30-60s voice memo is ideal). The app transcribes on-device, marks filler words and long pauses, and shows the timeline. Tap "Apply Cuts" to export.
3. Denoise tab → tap the large center button → pick a noisy audio file. Drag the intensity slider, A/B-compare original vs cleaned, then export.
4. Merge tab → tap "+" → import 2-3 short clips → tap MERGE → export.
5. Settings (gear icon, top-right of any home tab) → "Upgrade to Pro" opens the paywall. Use any sandbox tester to test the 7-day free trial → monthly / yearly / lifetime purchase paths.

Speech recognition consent prompts appear once on first Smart Cut. Microphone consent appears only if you tap Record (not required for any of the above test flows).

Bundle ID: com.dtech.cleancut
App Group: group.com.dtech.cleancut
Background mode: BGProcessingTask `com.dtech.cleancut.smartcut.transcribe` (used when Smart Cut transcription is left running in background).

Contact: <YOUR-EMAIL>
```

> ✏ Replace `<YOUR-EMAIL>` with your support email before submitting.

### 0.9 — Privacy Nutrition Label (App Store Connect → App Privacy)

Fill the form like this:

```
Does this app collect data from this app?  → No
```

That single answer covers the whole label. Reasoning: the app stores audio + edit-state in the App Group container on the device only; StoreKit purchase records are handled by Apple's IAP infrastructure (not "collected by your app" per Apple's definition); no analytics SDK; no networking.

If ASC asks about third-party SDKs separately, declare none — the only embedded asset is the DeepFilterNet3 Core ML model file (a model weight file, not a tracking SDK).

### 0.10 — Age Rating (App Store Connect → Age Rating)

Answer all questions "None / Infrequent or Mild → No":
```
Cartoon or Fantasy Violence: None
Realistic Violence: None
Sexual Content or Nudity: None
Profanity or Crude Humor: None
… (all others)
Unrestricted Web Access: No
Gambling: No
```
Result: **4+**

### 0.11 — Content Rights / Encryption (Submit step)

- Content Rights → "Does your app contain, display, or access third-party content?" → **No** (you authored/recorded all sample/preview content; the DFN3 model is shipped with appropriate license — confirm DFN3 license below in §3.5)
- Export Compliance → covered by `ITSAppUsesNonExemptEncryption = false` in Info.plist (added in §2.1) — ASC will skip the prompt entirely

---

## Section 1 — Decisions you must make first

### Decision 1.1 — Pricing reconciliation (OQ-1)

Two truths in conflict today:

| Tier | Spec / Marketing copy | `Configuration/CleanCut.storekit` |
|---|---|---|
| Monthly | $4.99 | $19.99 |
| Yearly | $39.99 | $39.99 ✓ |
| Lifetime | $79.99 | $39.99 |

Yearly matches. Monthly and lifetime do not. **Pick one path before §2.3 and §4.4.**

**Path A (Recommended) — align code + ASC to the marketing copy.**
Change `.storekit` and ASC product prices to `$4.99 / mo · $39.99 / yr · $79.99 lifetime`. Marketing copy stays as-shipped in §0.4. The PaywallView in-app pricing strings get updated in §2.3.

**Path B — align marketing to code.**
Change the four price lines in §0.4 to `$19.99 / month` and `$39.99 once`. `.storekit` and PaywallView stay. Edit the §0.4 block before pasting.

Write your choice here, then proceed:
```
Decision 1.1: ___ (A or B)
Final monthly price:  $______
Final yearly price:   $39.99
Final lifetime price: $______
```

### Decision 1.2 — Hosting for Privacy Policy + Terms URLs (OQ-2)

ASC requires both as live, public URLs that anyone (no login) can fetch.

**Recommended:** GitHub Pages on a tiny new repo (e.g. `github.com/<you>/cleancut-legal`). Free, instant, no domain needed (`<you>.github.io/cleancut-legal/privacy.html`).

Alternates: Notion published page, Carrd, your own domain.

A bare-minimum Privacy Policy + Terms template suitable for "we collect nothing" is provided in §3.1 and §3.2 below — copy, host, and paste the resulting URLs here:
```
Privacy Policy URL: __________________________
Terms of Use URL:   __________________________
Support URL:        __________________________  (can be a mailto: like mailto:support@yourdomain.com OR a static page)
```

### Decision 1.3 — Launch path

**Recommended (Internal TestFlight → App Review):** archive once, push to Internal TestFlight (≤100 Apple IDs, no Beta App Review, instant), smoke-test on your own device + 1-2 friends for 1-2 days, then submit the same build to App Review. Catches IAP sandbox bugs without slowing you by a week.

Alternates:
- Direct submit (skip TestFlight): faster if you're 100% sure, but rejection costs 3-7 days.
- External TestFlight first (more testers, requires a one-time Beta App Review ~24h): only valuable if you have a real beta cohort lined up.

Write your choice here:
```
Decision 1.3: Internal TestFlight → App Review
```

---

## Section 2 — Code-side compliance changes (Xcode)

### 2.1 — Add encryption export-compliance flag

**File:** `SonicMerge/Info.plist`

Add this key inside the top-level `<dict>` (anywhere — convention is alphabetical, but Apple doesn't care):

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

Why `false`: the app uses only Apple-provided encryption (HTTPS via system frameworks, on-device CoreML). No custom crypto. Setting this avoids the export-compliance question on every TestFlight upload.

Do the same for `SonicMergeShareExtension/Info.plist` (the share extension also needs it).

- [ ] Add the key to `SonicMerge/Info.plist`
- [ ] Add the key to `SonicMergeShareExtension/Info.plist`
- [ ] Build still green:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -5
  ```
- [ ] Commit:
  ```bash
  git add SonicMerge/Info.plist SonicMergeShareExtension/Info.plist
  git commit -m "feat(submission): declare non-exempt encryption flag for ASC"
  ```

### 2.2 — Add Privacy Manifest

**File:** create `SonicMerge/PrivacyInfo.xcprivacy` (Xcode auto-picks up via PBXFileSystemSynchronizedRootGroup — no pbxproj edit needed).

Paste this exact content (the app uses UserDefaults for theme/daily-counter/paywall state and reads/writes file timestamps in the App Group container; both are required-reason APIs since 2024):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryDiskSpace</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>E174.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

Reason-code legend (paste-comment for your reference, do NOT include in the plist):
- `CA92.1` — UserDefaults: read/write info accessible only to this app
- `C617.1` — File timestamp: inspect timestamps of files inside the app/group container
- `E174.1` — Disk space: write user-generated content (audio exports) to disk

- [ ] Create `SonicMerge/PrivacyInfo.xcprivacy` with the content above
- [ ] Build still green (same command as §2.1)
- [ ] Commit:
  ```bash
  git add SonicMerge/PrivacyInfo.xcprivacy
  git commit -m "feat(submission): add PrivacyInfo.xcprivacy for required-reason APIs"
  ```

> If App Review rejects with "missing reason for API X", come back and add the missing entry. The 3 above cover what the codebase touches today, but Apple expands this list periodically.

### 2.3 — Sync in-app pricing strings to Decision 1.1

**Only do this section if Decision 1.1 = Path A.** If Path B, skip — code already matches.

Files likely to touch (use the search to confirm):
```bash
grep -rn '"\$19.99"\|"\$39.99"\|"\$79.99"\|"\$4.99"' SonicMerge/Features/Subscription/ 2>/dev/null
```

The two files that almost certainly hold display strings:
- `Configuration/CleanCut.storekit` — change `displayPrice` for `com.cleancut.pro.monthly.v2` from `19.99` → `4.99`, and `com.cleancut.pro.lifetime.v2` from `39.99` → `79.99`
- `SonicMerge/Features/Subscription/Views/PaywallView.swift` (or wherever pricing strings are hardcoded if not pulling from `StoreKit.Product.displayPrice`)

Steps:

- [ ] Update `Configuration/CleanCut.storekit`:
  - In the `subscriptions` array, locate `"productID" : "com.cleancut.pro.monthly.v2"` → set `"displayPrice" : "4.99"`
  - In the top-level `products` array, locate `"productID" : "com.cleancut.pro.lifetime.v2"` → set `"displayPrice" : "79.99"`
- [ ] Confirm PaywallView pulls prices from `Product.displayPrice` (StoreKit 2) rather than hardcoded strings:
  ```bash
  grep -n 'displayPrice\|"\$' SonicMerge/Features/Subscription/Views/PaywallView.swift
  ```
  If it uses `displayPrice`, you're done — StoreKit will surface the new prices automatically.
  If it has hardcoded strings, replace them.
- [ ] Run pricing-related tests if any exist:
  ```bash
  xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:SonicMergeTests/Features/Subscription test 2>&1 | tail -10
  ```
- [ ] Full test run, expect FAIL=5:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3
  echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
  ```
- [ ] Commit:
  ```bash
  git add Configuration/CleanCut.storekit SonicMerge/Features/Subscription
  git commit -m "feat(submission): reconcile pricing to spec ($4.99/mo, $79.99 lifetime)"
  ```

### 2.4 — Bump build number (always do this before any upload)

**File:** `SonicMerge.xcodeproj/project.pbxproj` — find every `CURRENT_PROJECT_VERSION = 1;` line and change to `2` (or whatever the next integer is).

Marketing version stays at `1.0` for v1.0 submission. Build number must monotonically increase with every upload — TestFlight rejects re-using a build number.

- [ ] Search:
  ```bash
  grep -n "CURRENT_PROJECT_VERSION" SonicMerge.xcodeproj/project.pbxproj
  ```
- [ ] Edit each occurrence (all targets must match: app + share extension + tests)
- [ ] Verify still builds:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -5
  ```
- [ ] Commit (commit at end of Section 2 after all of §2.1-§2.4):
  ```bash
  git add SonicMerge.xcodeproj/project.pbxproj
  git commit -m "chore(submission): bump build to 2 for first ASC upload"
  ```

---

## Section 3 — Hosted assets (web-side) and screenshots

### 3.1 — Privacy Policy template

Host this at the URL you put in Decision 1.2. Copy into `privacy.html` (or `privacy.md` if your hoster renders Markdown):

```markdown
# Privacy Policy — CleanCut

_Last updated: 2026-05-09_

CleanCut ("we", "the app") is built to keep your audio on your device. This policy describes what data the app does and does not handle.

## Data we collect

**None.** CleanCut does not collect, store, or transmit any personal data, audio data, transcripts, usage analytics, device identifiers, or location information. The app contains no third-party analytics SDK and no third-party tracker.

## Data the app processes locally

To do its job, the app reads and writes the following on your device only:
- Audio files you import or record (stored in the app's private container; never uploaded).
- Transcripts produced by Apple's on-device Speech framework (also stored locally; never uploaded).
- Subscription entitlement state, theme preference, and daily-usage counters (stored in `UserDefaults`; never uploaded).

You can delete all of this data at any time by uninstalling CleanCut.

## Apple-handled data

If you purchase a CleanCut Pro subscription or lifetime upgrade, Apple's In-App Purchase system processes your payment. CleanCut never sees your payment details. Apple's privacy policy applies: <https://www.apple.com/legal/privacy/>.

## Permissions

CleanCut requests two iOS permissions:
- **Speech Recognition** — used by Smart Cut to detect filler words on your device. You can revoke this in Settings → CleanCut.
- **Microphone** — used only if you record audio inside the app. You can revoke this in Settings → CleanCut.

## Children

CleanCut is rated 4+ and does not knowingly collect data from anyone, including children under 13.

## Contact

Questions about this policy: <YOUR-EMAIL>
```

- [ ] Replace `<YOUR-EMAIL>` with your real support email
- [ ] Host it (GitHub Pages is fastest):
  ```bash
  # Example, in a new repo:
  mkdir cleancut-legal && cd cleancut-legal
  git init
  # save privacy.md here
  git add privacy.md
  git commit -m "Add privacy policy"
  # push to GitHub, enable Pages in Settings → Pages → main / root
  ```
- [ ] Verify URL loads in incognito browser (proves it's truly public)

### 3.2 — Terms of Use template

```markdown
# Terms of Use — CleanCut

_Last updated: 2026-05-09_

By using CleanCut you agree to these terms.

## License

CleanCut grants you a personal, non-transferable, non-exclusive license to use the app on devices you own or control, subject to the [Apple Standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/), which governs all App Store apps unless replaced by a custom EULA.

## CleanCut Pro subscriptions

CleanCut Pro is offered as an auto-renewing monthly subscription, an auto-renewing yearly subscription (with a 7-day free trial for first-time users), or a one-time lifetime purchase. Subscriptions auto-renew at the end of each period unless cancelled at least 24 hours before the end of the period. Manage or cancel in iOS Settings → Apple ID → Subscriptions.

The 7-day free trial converts to a paid subscription if not cancelled before the trial ends.

## Refunds

Refunds are handled by Apple. Request one at <https://reportaproblem.apple.com>.

## Acceptable use

You agree not to:
- Reverse-engineer or decompile the app beyond what local law permits.
- Use CleanCut to process audio you do not have the right to process.

## Disclaimer

CleanCut is provided "as is". On-device AI may not catch every filler word or fully remove every type of background noise; always review output before publishing.

## Contact

<YOUR-EMAIL>
```

- [ ] Replace `<YOUR-EMAIL>`
- [ ] Host (same hoster as §3.1)
- [ ] Verify URL loads

### 3.3 — Support page (or mailto)

The simplest acceptable Support URL is a `mailto:` link or a one-paragraph "Contact" page. Apple just needs *something* a frustrated user can reach. Either of these works:

```
mailto:support@yourdomain.com
```

Or a one-page site at e.g. `<you>.github.io/cleancut-legal/support.html`:

```markdown
# CleanCut — Support

Need help? Email <YOUR-EMAIL> and we'll reply within a few business days.

Common questions:

**My subscription didn't unlock features.**
Open Settings (gear icon, top-right) → Restore Purchases.

**Cancel my subscription.**
iOS Settings → Apple ID (top of Settings) → Subscriptions → CleanCut Pro → Cancel.

**Smart Cut isn't detecting my filler words.**
Make sure you've set the right recognition language for the session. Smart Cut works best on clear speech recorded close to the microphone.
```

- [ ] Pick one (mailto or page)
- [ ] If page: host alongside §3.1/§3.2

### 3.4 — Render screenshots (5 frames × 2 sizes = 10 PNGs)

App Store Connect requires at least one of (6.9" iPhone, 6.5" iPhone). Upload both to maximize coverage. Per spec §6 the arc is fixed: Hero → Smart Cut → Denoise → Merge → Privacy.

**Required dimensions (portrait):**
- 6.9" (iPhone 16 Pro Max / 17 Pro Max class) — `1290 × 2796` px
- 6.5" (iPhone 11 Pro Max / 14 Plus class) — `1242 × 2688` px

Workflow (any one of the three works — pick what you have):

**Workflow A — Simulator + Keynote/Figma overlay (lowest tooling cost):**

1. Run the app in iPhone 17 Pro Max simulator at 1290×2796.
2. Set up the screen for each frame:
   - Frame 1 (Hero): no UI shown — just the launch state OR a clean Smart Cut empty state. (Or skip simulator entirely and design Frame 1 in Keynote/Figma using the indigo→lime gradient + app icon.)
   - Frame 2 (Smart Cut): Open a sample audio file in Smart Cut, let detection complete so the waveform shows red filler markers.
   - Frame 3 (Denoise): Open the Denoise A/B view with both waveforms visible and the intensity slider mid-range.
   - Frame 4 (Merge): MixingStation with 3 sample clips loaded showing crossfade pills.
   - Frame 5 (Privacy): Settings/About sheet open with Airplane Mode enabled in status bar.
3. ⌘S in simulator to save each screenshot.
4. In Keynote/Figma, create a 1290×2796 canvas. Layer top-down:
   - Background: indigo→lime gradient (`#5856D6 → #A7C957`, 135°)
   - Top 35%: headline (caption from §0.7) in your brand display font (white, large) + subline (white, smaller)
   - Bottom 65%: the screenshot, framed in a phone bezel mockup OR floated with subtle drop shadow
5. Export each as PNG.
6. Repeat for 6.5" by re-rendering at 1242×2688 (just resize the canvas, the layout reflows or you re-export from Keynote at the smaller size).

**Workflow B — Fastlane snapshot (more setup, fully reproducible):**

If you anticipate frequent screenshot updates, set up `fastlane snapshot`. One-time cost ~2-3 hours; future regenerations are one command. Out of scope for this v1.0 submission unless you choose to invest.

**Workflow C — Online tools (e.g., screenshots.pro, AppMockUp):**

Paste your raw simulator screenshot, type the caption, choose a template, export. Fastest if you don't already have Keynote/Figma in your workflow.

- [ ] Capture 5 raw screens from simulator (or design Frame 1 from scratch)
- [ ] Compose 5 final 6.9" PNGs (1290×2796)
- [ ] Compose 5 final 6.5" PNGs (1242×2688)
- [ ] Save to `marketing/screenshots/v1.0/6.9/` and `marketing/screenshots/v1.0/6.5/` (any folder works, just keep them organized)

### 3.5 — Confirm DeepFilterNet3 model license

Open `temp-dfn/` and `speech-swift/` for any LICENSE file. DFN3 ships under MIT/Apache (commercial-friendly), but ASC may ask "does your app contain third-party content?" — if you can confirm the license is permissive, answer "No" to that question (you have rights to ship). If unsure, answer "Yes" and add a one-line attribution in §0.4 description body or in an in-app About screen.

- [ ] Confirm license type:
  ```bash
  find temp-dfn speech-swift -iname "LICENSE*" -o -iname "COPYING*" 2>/dev/null
  ```
- [ ] Decide: "No" (most likely, MIT/Apache) or "Yes" + add attribution

---

## Section 4 — App Store Connect web setup

Do all of this at <https://appstoreconnect.apple.com>.

### 4.1 — Create the app record (My Apps → "+" → New App)

```
Platform:        iOS
Name:            CleanCut
Primary language: English (U.S.)
Bundle ID:       com.dtech.cleancut  (must already be registered in developer.apple.com)
SKU:             cleancut-ios-v1     (any string, never visible to users)
User Access:     Full Access
```

- [ ] Create
- [ ] Confirm app appears under "My Apps"

### 4.2 — App Information page

| Field | Value source |
|---|---|
| Name | §0.1 |
| Subtitle | §0.2 |
| Privacy Policy URL | Decision 1.2 |
| Category Primary | **Music** (matches the listing-preview tag) |
| Category Secondary | Productivity |
| Content Rights | "Does your app contain, display, or access third-party content?" → see §3.5 |

- [ ] Paste Name, Subtitle
- [ ] Paste Privacy Policy URL
- [ ] Set categories
- [ ] Set Content Rights answer
- [ ] Save

### 4.3 — Pricing & Availability

```
Price: Free
Availability: All countries/regions (default) — or trim if you have a reason
```

The app itself is free; revenue comes from IAP (configured in §4.4).

- [ ] Set price tier to Free
- [ ] Confirm availability
- [ ] Save

### 4.4 — Create the 3 IAP products (App → Monetization → In-App Purchases & Subscriptions)

Match the IDs already in `Configuration/CleanCut.storekit`. **Use Decision 1.1 prices.**

**Product 1 — Subscription Group: "CleanCut Pro"**

First create the subscription group:
```
Reference Name: CleanCut Pro
```

Then add the two subscriptions inside that group:

```
Product 1A: Monthly
  Reference Name:  CleanCut Pro Monthly
  Product ID:      com.cleancut.pro.monthly.v2
  Subscription Duration: 1 Month
  Price:           Decision 1.1 monthly  (set per region; "Apple's recommended" suffices for v1.0)
  Family Sharing:  ON
  Localization (en-US):
    Display Name: CleanCut Pro · Monthly
    Description:  Unlimited Smart Cut and Denoise. No watermarks. Files of any length.
  Introductory Offer: none for monthly (the 7-day free trial lives on Yearly)

Product 1B: Yearly
  Reference Name:  CleanCut Pro Yearly
  Product ID:      com.cleancut.pro.yearly.v2
  Subscription Duration: 1 Year
  Price:           $39.99 (Decision 1.1 yearly)
  Family Sharing:  ON
  Localization (en-US):
    Display Name: CleanCut Pro · Yearly
    Description:  Unlimited Smart Cut and Denoise. Save 33% vs monthly. 7-day free trial.
  Introductory Offer:
    Type:        Free Trial
    Duration:    1 week
    Eligibility: New Subscribers
```

**Product 2 — Non-Consumable IAP (lifetime)**

```
Reference Name:  CleanCut Pro Lifetime
Product ID:      com.cleancut.pro.lifetime.v2
Type:            Non-Consumable
Price:           Decision 1.1 lifetime
Family Sharing:  ON
Localization (en-US):
  Display Name: CleanCut Pro · Lifetime
  Description:  Unlock all CleanCut Pro features forever — no recurring charge.
```

**Each IAP needs a 1024×1024 review screenshot** (Apple wants to see the paywall as it appears in-app). Capture from simulator and upload.

- [ ] Create subscription group
- [ ] Create monthly subscription with 0 intro offer
- [ ] Create yearly subscription with 7-day free-trial intro
- [ ] Create lifetime non-consumable
- [ ] Capture paywall screenshot from simulator (1024×1024 or any large size)
- [ ] Upload to all 3 IAP review-screenshot fields
- [ ] Submit each IAP for review (they review IAP separately from the app, in parallel)

### 4.5 — Create a sandbox tester (Users and Access → Sandbox → Testers → "+")

```
First Name: Test
Last Name:  Cleancut
Email:      cleancut-sandbox-1+<random>@yourdomain.com   (must be a UNIQUE email never used as an Apple ID)
Password:   <strong password — save in a password manager>
Country:    United States   (storefront for IAP testing)
```

You'll use this in §5.4 TestFlight smoke testing. The email does NOT need to receive mail — Apple just needs a unique string.

- [ ] Create sandbox tester
- [ ] Save credentials in your password manager

### 4.6 — App Privacy (Privacy Nutrition Label)

App → App Privacy → "Get Started" → answer per §0.9: **"Data is not collected from this app."**

- [ ] Click "Get Started"
- [ ] Answer "No, we do not collect data from this app"
- [ ] Save → label generates as "Data Not Collected"

---

## Section 5 — Build, upload, version setup, TestFlight, submit

### 5.1 — Archive the app

In Xcode:

1. Top bar: select scheme `SonicMerge`, destination `Any iOS Device (arm64)`.
2. Menu: Product → Archive. Wait for the build to finish (~2-5 min).
3. The Organizer window opens with the archive listed.

- [ ] Archive completes without errors

### 5.2 — Upload to App Store Connect

In Xcode Organizer (the window that opened after Archive):

1. Select the new archive → click **Distribute App** (top right).
2. Choose **App Store Connect** → **Upload** → **Next**.
3. Distribution options: keep defaults (Upload symbols ON, Manage version & build number OFF — you already bumped in §2.4).
4. Re-sign: **Automatically manage signing** (this is what `CODE_SIGN_STYLE = Automatic` in pbxproj uses).
5. Click **Upload**.

ASC will process the build for ~10-30 minutes. You'll get an email when processing finishes.

- [ ] Upload succeeds
- [ ] Email "App Store Connect: Build available" arrives

### 5.3 — Create the v1.0 version in ASC

App Store Connect → your app → **iOS App → 1.0** (auto-created when you create the app record; if not, click "+ Version or Platform" → 1.0).

This page is where you paste everything from §0.

- [ ] Paste Promotional Text (§0.3)
- [ ] Paste Description (§0.4) — verify it matches Decision 1.1 prices
- [ ] Paste Keywords (§0.5)
- [ ] Paste Support URL (Decision 1.2) and Marketing URL (skip — leave blank)
- [ ] Paste Version (`1.0`) and What's New (§0.6)
- [ ] Upload Screenshots (§3.4) for both 6.9" and 6.5"
- [ ] Set Build: pick the build that finished processing in §5.2
- [ ] Save

### 5.4 — Add to Internal TestFlight + smoke-test (Decision 1.3)

App Store Connect → your app → **TestFlight** tab → wait for the build's "missing compliance" warning to clear (it should — you set `ITSAppUsesNonExemptEncryption=false`).

1. Internal Testing group: click **+** → create "Smoke Testers" → add your own Apple ID (and 1-2 friends if you want). Internal testers use their real Apple ID; no Beta App Review needed.
2. Each tester gets an email; install TestFlight app on iPhone, accept invite, install CleanCut.
3. Smoke-test on real device:
   - Open app → cold start works
   - Smart Cut → import → review cuts → export
   - Denoise → import → A/B → export
   - Merge → import 2 clips → export
   - Settings → Restore Purchases (should report "no prior purchases" since you're not signed in as the sandbox tester yet)
   - Sign in with the §4.5 sandbox tester (Settings → Apple ID → Sign Out, then sign in with sandbox creds when prompted by IAP), open paywall, run a test purchase on monthly → confirm Pro unlocks → Settings → Restore Purchases works
4. Fix any blockers found here. If you find one:
   - Fix in code
   - Bump build number (§2.4)
   - Re-archive (§5.1) and re-upload (§5.2)
   - In ASC TestFlight, point Internal group at the new build
- [ ] Internal testing group created
- [ ] Self-test on device passes the 6 checks above
- [ ] No blocker bugs

### 5.5 — Submit for App Review

App Store Connect → your app → **Distribution → 1.0**.

1. Scroll to **App Review Information**.
2. Sign-in required: **No** (no demo account needed, but if your sandbox tester is meaningful, paste credentials here as a courtesy — sandbox tester credentials, NOT a real Apple ID).
3. Notes: paste §0.8.
4. Attachment: optional — skip for v1.0 unless something is non-obvious.
5. **Version Release** section: pick one:
   - **Manually release this version** (recommended for v1.0 — gives you a moment to celebrate / write social posts)
   - Automatically release after approval
   - Phased release for automatic updates (irrelevant at v1.0)
6. Scroll to top, click **Add for Review** → **Submit for Review**.
7. ASC asks the "Export Compliance" question one last time (or doesn't, if `ITSAppUsesNonExemptEncryption` was read correctly): answer **No** (does not use non-exempt encryption).
8. Wait. App Review for first-submissions typically takes 24-72 hours.

- [ ] Add for Review → Submit
- [ ] Status changes to "Waiting for Review"

### 5.6 — Respond to App Review

Three possible outcomes:

- **Approved** → if you chose "Manually release", click **Release this version**. App goes live within ~30 min. ✅
- **In Review → Approved** without questions → see above.
- **Metadata Rejected** (most common first-time issue): Apple Reviewer leaves a message. Common rejections + responses:
  - "Privacy Policy URL doesn't work" → fix URL in §4.2, resubmit (no new build needed).
  - "We couldn't test In-App Purchase" → re-paste §0.8 with explicit instructions and the sandbox tester credentials.
  - "Description mentions a feature not in app" → reconcile §0.4 with actual app behavior.
- **Binary Rejected**: code change required. Fix → bump build → re-archive → re-upload → re-submit.

The "Resolution Center" in ASC is the chat thread with Apple. Reply within 1-2 business days; rejections that age past a week sometimes get auto-closed and you have to start a new submission.

- [ ] Receive review decision
- [ ] If approved + manual release: click Release
- [ ] If rejected: respond in Resolution Center within 24h

---

## Section 6 — Post-launch hygiene (Day 0 - Day 7)

Not blocking submission, but lock these in your calendar:

- [ ] Day 0 (release day): screenshot the App Store listing on your iPhone for your records
- [ ] Day 1: run the full app on a fresh device-installed-from-App-Store build (catches sandbox-vs-prod IAP bugs)
- [ ] Day 3: check App Store Connect → Sales & Trends for first install + IAP numbers
- [ ] Day 7: read every review (App Store Connect → Activity → Ratings and Reviews); reply to anything constructive
- [ ] Day 7: revisit Promotional Text — it's editable without a re-review, so you can A/B without resubmitting

---

## Glossary of fields you'll see in ASC

| ASC label | What it actually is |
|---|---|
| Promotional Text | Top-of-description copy you can edit without re-review (§0.3) |
| Description | The body shown when user taps "more" on the storefront (§0.4) |
| Keywords | Comma-separated, 100-char ASO field, never visible to users (§0.5) |
| What's New | Release notes shown on the iPhone "Updates" tab (§0.6) |
| Marketing URL | Optional link to a marketing page; skip for v1.0 |
| Support URL | Required; can be a mailto: (§3.3) |
| Privacy Policy URL | Required; live web URL (§3.1) |
| App Review Notes | Plain text shown only to Apple Reviewer (§0.8) |
| Version Release | When the approved build goes live; default is "automatically" |

---

## What this plan does NOT cover

- Marketing site / landing page (separate project; skip until after launch)
- ASO post-launch tuning (revisit at Day 30 with real install data)
- Localization beyond en-US (each locale is a separate listing-content spec)
- App Preview video (skipped per spec §6 rationale)
- macOS / iPad-optimized builds (current scheme is iPhone-only)

---

## Open question carryovers from spec

- OQ-1: resolved here as Decision 1.1
- OQ-2: resolved here as Decision 1.2
- OQ-3: resolved here as §0.8 (Review Notes copy)
