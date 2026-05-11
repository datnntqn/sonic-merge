# CleanCut v1.0 — Marketing Copy

**Last updated:** 2026-05-11
**Status:** Working draft, ready to lift
**Pricing baseline:** $3.99 / month · $19.99 / year (Save 58%) · $39.99 lifetime
**OS support:** iPhone, iOS 17+ (long-form streaming + live transcript on iOS 26+)
**Anchor audience:** solo podcasters
**Tone:** plain-spoken, technical, on-device-first

This doc collapses two surfaces into one source:

1. **Press kit / landing page** (sections 1–7 below)
2. **Social posts** (section 8)

Sections 1–7 can drop straight into a one-pager (Notion / GitHub Pages / cleancut.app). Section 8 is ready to paste into X/Threads/LinkedIn.

---

## 1. The 1-line pitch

> **CleanCut is an iPhone audio editor that trims filler words, kills background noise, and merges takes — entirely on-device. Your audio never leaves your phone.**

**90-character version** (for bios, app store, OG tags):
> Cut filler words, denoise, merge takes — all on iPhone. Audio never leaves your phone.

**Spoken-aloud version** (for podcast plugs, demos):
> CleanCut is the iPhone audio editor for solo podcasters. It listens for ums and uhs, pulls voice out of the room, and stitches your takes — all on your phone. Nothing uploads anywhere.

---

## 2. Hero (landing page above-the-fold)

```
Cut filler words. Clean background noise. Merge takes.
All on your iPhone.

CleanCut is a podcast-grade audio editor with three tools — Smart Cut,
Denoise, and Merge. Every step runs on-device. Your audio never leaves
your phone.

[ Download on the App Store ]    [ See how it works ]
```

**Hero alternates** (pick one when testing):

| Variant | Headline | Sub |
|---|---|---|
| **A — Outcome** | A 30-minute recording becomes a 22-minute edit. In one tap. | Filler words, background noise, dead air — gone. On your iPhone, never the cloud. |
| **B — Moat** | Your voice. Your iPhone. No cloud. | Three on-device tools for podcasters: cut fillers, kill noise, merge takes. Airplane mode still works. |
| **C — Anti-tool** | The audio editor that doesn't have an account. | No signup, no sync, no upload. CleanCut runs entirely on your iPhone. |

---

## 3. The three tools (feature blocks)

Each block is a self-contained card. Use as-is on a landing page or split into separate social posts.

### Smart Cut — trim what you didn't mean to say

Smart Cut listens for **filler words** (`um`, `uh`, `like`, and any word you teach it), long silences, and dead air. It proposes an edit. Every cut shows on a waveform timeline before export — nothing is removed without your review.

- Auto-generated transcript you can copy or export as `.txt`, `.srt`, or `.vtt`
- Per-session language picker — pick the recognition language each session
- iOS 26+: long-form streaming via Apple's new SpeechAnalyzer, with a live transcript pane that updates as it processes
- Background processing — start an analysis, lock your phone, get a notification when it's done

**Time math:** a 30-minute solo recording at a normal speaking pace contains ~120 detected fillers + 90 seconds of dead air on average. Smart Cut surfaces all of it in about 90 seconds.

### Denoise — pull voice out of the room

Powered by **DeepFilterNet3**, an on-device neural network built specifically for speech. Not a generic noise gate — it understands the difference between a fan and a fricative.

- **Intensity slider** to taste the result before committing — full bypass on one end, aggressive on the other
- **A/B toggle** — switches between original and cleaned at the exact same playback position, so you can hear what changed
- Works on real-world audio: subway commutes, busy cafés, humming offices, the back seat of a moving car

### Merge — stitch takes into one file

Drag clips onto a timeline. Set crossfades. Export as M4A or WAV.

- **Auto-loudness normalization** to broadcast standard (BS.1770 LUFS), so volume jumps between clips disappear
- Drag-to-reorder, scrub-to-preview
- iOS Share Extension — clean a voice memo straight from the Voice Memos app or Mail, without leaving the app you're in

---

## 4. The privacy moat (positioning paragraph)

This is the section to lift verbatim when a journalist asks "what makes this different from Descript/Riverside/Cleanvoice."

> **Every comparable tool uploads your audio to a server.** Descript, Riverside, Cleanvoice, Adobe Podcast — all of them ship your voice to a data center, run AI on it, and ship the result back. That's how it's been because the models were too big to run on a phone.
>
> CleanCut runs entirely on your iPhone. The transcription model is Apple's on-device SpeechAnalyzer (or `SFSpeechRecognizer` on iOS 17–25). The denoise model is DeepFilterNet3, a small neural network built for embedded inference. The merge timeline is `AVFoundation`. No analytics SDK, no third-party tracker, no account. Turn on airplane mode — CleanCut still works.
>
> That's not a marketing claim we can hide behind. It's a structural property: there's no server to send it to.

---

## 5. Pricing (single source of truth)

| Tier | Price | What you get |
|---|---|---|
| **Free** | $0 | 3 Smart Cut + 3 Denoise sessions per day · files up to 5 min (Smart Cut) or 3 min (Denoise) · unlimited Merge with up to 3 clips · WAV export |
| **Pro Monthly** | **$3.99 / month** | Everything below, billed monthly. 7-day free trial. |
| **Pro Yearly** | **$19.99 / year** *(Save 58%)* | Same Pro features, billed yearly. 7-day free trial. |
| **Lifetime** | **$39.99 once** | Same Pro features, never billed again. No subscription. |

**Pro removes every limit:**
- Unlimited Smart Cut + Denoise sessions, any file length
- Export to M4A, MP3, or WAV
- No watermark
- Custom filler-word libraries (teach it new words)
- Background processing with push notifications

Restore Purchases lives in Settings → Subscription. Cancel anytime.

---

## 6. Founder note (for press kit + Product Hunt first comment)

> Hi, I'm Đạt (`@datnnt`). I built CleanCut because I record voice notes constantly — drafts, demos, talking-to-myself thinking sessions — and I wanted to clean them up without uploading them anywhere.
>
> Every audio tool I tried sent my audio to a server. Some had decent privacy policies. None of them were as good as "the audio just never leaves your phone." So I built that.
>
> Smart Cut runs on Apple's SpeechAnalyzer (iOS 26) and `SFSpeechRecognizer` (iOS 17–25). Denoise uses DeepFilterNet3, a 1.7M-parameter neural network compiled to Core ML. Merge is straight `AVFoundation`. No backend. No analytics. Three tools, on the phone.
>
> Free tier is generous (3 sessions a day forever — enough for a daily voice memo). Pro is $3.99/mo or $19.99/yr if you want it unlimited; one-time $39.99 if you hate subscriptions (I do too).
>
> Feedback welcome — reply here or email me directly.

---

## 7. FAQ (drop into landing page or PH first reply)

**Does Smart Cut work without internet?**
Yes. Both Smart Cut (transcription) and Denoise run on-device. You can put your phone in airplane mode and CleanCut works.

**Which languages does Smart Cut support?**
Whatever your iPhone's Speech framework supports — typically English, Spanish, Portuguese, French, German, Italian, Japanese, Korean, Chinese, and ~20 more. You pick a language per session. No bilingual auto-detect at launch (single language per recording).

**How does the iOS 26 version differ from iOS 17?**
iOS 26 uses Apple's new `SpeechAnalyzer` for long-form streaming with a live transcript pane that updates as the analysis runs. iOS 17–25 uses `SFSpeechRecognizer` in 30-second chunks — same accuracy, just shown as a progress bar instead of streaming text.

**How long does a recording take to process?**
Roughly 2.5× faster than real time on iPhone 15 Pro and newer. A 30-minute recording takes ~12 minutes of foreground processing, or you can hit "Run in BG" and lock your phone.

**Why is the free tier limited?**
The free tier covers a daily voice memo (3 Smart Cut + 3 Denoise sessions a day, ≤5 min each). Beyond that, the on-device models use real CPU/battery, so the economics need to net out. Pro is the unlock for unlimited processing.

**Does CleanCut export to my podcast host?**
Indirectly — export to M4A or MP3 (Pro), then upload from the Files app or Voice Memos to whatever host you use (Anchor, Buzzsprout, Transistor, etc.). No direct integrations at v1.0.

**Is there a Mac version?**
Not at launch. The on-device models are tuned for iPhone first. macOS Catalyst is on the roadmap but not v1.x.

**Where do I email you?**
[support@cleancut.app](mailto:support@cleancut.app)

---

## 8. Social posts

Five for X/Threads (each ≤280 chars), three for LinkedIn (longer, more story-shaped). All written for the indie iOS / podcaster audience.

### X / Threads

**Post 1 — Launch (lead with the moat)**

```
Today I'm shipping CleanCut.

It's an iPhone audio editor for podcasters that trims filler words,
denoises, and merges takes — all on-device. Your audio never leaves
your phone.

Airplane mode still works.

$3.99/mo, $19.99/yr, or $39.99 lifetime.
```

**Post 2 — The pitch in one outcome**

```
30-minute solo podcast recording.

Open CleanCut → Smart Cut → wait 90 seconds → review 120 detected
fillers + 8 dead-air pauses on the waveform → tap Apply → export.

22-minute clean episode. Nothing uploaded.

iPhone-only. iOS 17+.
```

**Post 3 — Engineering credibility (for HN / indie crowd)**

```
CleanCut ships on iOS 26 with three on-device models:

• Apple SpeechAnalyzer (transcription, long-form streaming)
• DeepFilterNet3 in Core ML (denoise, 1.7M params)
• AVFoundation + BS.1770 LUFS (merge, auto-loudness)

No backend. No analytics SDK. No third-party trackers.
```

**Post 4 — Anti-tool framing**

```
The audio editor that doesn't have an account.

No signup. No sync. No upload. Just three tools on your iPhone:
- Smart Cut (cut fillers + silences)
- Denoise (pull voice out of the room)
- Merge (stitch takes, auto-LUFS)

7-day free trial. $19.99/yr or $39.99 lifetime.
```

**Post 5 — Demo GIF caption (paired with a screen recording)**

```
Smart Cut, in real time:

▶ recording plays
🔵 ums + uhs auto-detected
🔵 long pauses flagged
👁 every cut is reviewable before it commits

All running on the phone. No cloud round-trip.
```

**Post 6 — Reply-to-"how does it compare to Descript"**

```
Descript runs in the cloud. Riverside runs in the cloud. Cleanvoice
runs in the cloud.

CleanCut runs on your iPhone.

Same three jobs (filler-cut, denoise, merge) — different shape of
deal. Your audio stays on the device. Always.
```

**Post 7 — Pricing reveal**

```
CleanCut pricing:

$3.99 / month
$19.99 / year (save 58%, 7-day trial)
$39.99 lifetime — no subscription, ever

Free tier is generous (3 Smart Cut + 3 Denoise sessions/day forever)
so you can decide whether you want to upgrade.
```

### LinkedIn

**LinkedIn 1 — Launch announcement**

```
Today I'm shipping CleanCut — an iPhone audio editor I've been building
for podcasters who don't want to upload their audio to a server.

The three jobs every podcaster does after recording:
  1. Cut filler words ("um," "uh," dead air)
  2. Denoise background noise
  3. Merge takes into one file

CleanCut does all three on your phone. No cloud, no account, no
analytics SDK. Apple's on-device SpeechAnalyzer (iOS 26) handles
transcription. DeepFilterNet3, compiled to Core ML, handles denoise.
AVFoundation handles the merge.

Free forever for daily voice memos (3 sessions/day). Pro is $3.99/mo,
$19.99/yr, or $39.99 lifetime.

App Store: [link]

Built by one person on the side. Reply or DM with questions.
```

**LinkedIn 2 — The "why I built it" angle (longer-form, founder voice)**

```
Every audio editor I tried as a part-time podcaster shipped my voice
to a data center. Most of them had reasonable privacy policies. None
of them were as good as the audio simply not leaving the device.

So I built CleanCut.

It does what Descript and Cleanvoice do (auto-cut filler words, kill
background noise, merge takes), but every step runs on your iPhone.
No server. No upload. No account.

Why this matters for podcasters:
  • You can edit in airplane mode (planes, trains, cafés)
  • Sensitive recordings (interviews, drafts, anything pre-release)
    never touch a third party
  • Battery + bandwidth costs zero on someone else's data center

Why this matters as an engineering proof:
  • Apple's on-device speech models in iOS 26 are accurate enough
    for long-form transcription
  • DeepFilterNet3 (1.7M-param speech denoiser) compiles to Core ML
    and runs at ~2.5× real-time on iPhone 15 Pro
  • The whole pipeline is AVFoundation + Core ML + ~6k lines of Swift

If on-device AI is interesting to you — as a podcaster, an iOS dev,
or a privacy-curious user — I'd love your feedback.

App Store: [link]
```

**LinkedIn 3 — Solo-podcaster targeting (problem-first)**

```
A 30-minute solo podcast recording contains, on average:
  • 100–150 filler words (um, uh, like, you know)
  • 60–120 seconds of dead air between thoughts
  • 5–15 dB of room noise that wasn't there in your headphones

Hand-editing that in Logic or GarageBand takes 60–90 minutes. The
cloud tools (Descript, Cleanvoice, Adobe Podcast) cut that to 10–15
minutes but require uploading the entire recording.

CleanCut does it in under 5 minutes, on your iPhone, without uploading.

Smart Cut surfaces every filler + pause on a waveform — you review,
then apply. Denoise uses DeepFilterNet3 with an intensity slider and
an A/B toggle. Merge auto-normalizes loudness (BS.1770 LUFS).

7-day free trial. $19.99/yr or $39.99 lifetime.

App Store: [link]
```

---

## 9. Asset / link checklist (fill in before publishing)

| Asset | Status |
|---|---|
| App Store link (after submission approval) | TBD |
| Product Hunt page URL | TBD |
| Landing page (cleancut.app or GitHub Pages) | TBD |
| 3 × hero screenshot (1290×2796) | TBD |
| 1 × 6–10s demo GIF (Smart Cut waveform → apply) | TBD |
| 1 × 15s App Preview video (optional v1.0) | Deferred to v1.1 |
| Founder headshot (for press kit) | TBD |
| Press contact email | TBD |

---

## 10. Words to use / words to avoid

**Use** — they reinforce the moat:
- "on your iPhone"
- "on-device"
- "your audio never leaves your phone"
- "airplane mode still works"
- "no cloud, no upload, no account"

**Avoid** — they sound generic or oversold:
- "AI-powered" (everything is now; doesn't differentiate)
- "revolutionary," "game-changing," "next-gen"
- "seamless," "frictionless" (banned in iOS-indie writing — meaningless)
- "magic" (specifically: don't call the AI "magic")

**Avoid** — they create review/legal risk:
- Naming competitors directly in App Store metadata (Apple guideline 2.3.7)
- Claiming "100% accuracy" or "perfect" anything (regulators flag this)
- Comparing prices to a competitor in ad copy without a footnote
