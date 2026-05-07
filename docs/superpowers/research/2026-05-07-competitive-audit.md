# CleanCut Competitive Feature Audit — Cleanvoice AI · Descript

**Date:** 2026-05-07
**Author:** Claude (autonomous research, hybrid mode)
**Method:** Training-data baseline + live web verification of feature lists and pricing (cleanvoice.ai/features, descript.com/pricing fetched 2026-05-07).
**Goal:** Identify roadmap-relevant gaps in CleanCut vs. its closest feature twin (Cleanvoice) and the maximalist incumbent (Descript). Each gap gets a verdict: **ship v1 / consider v1.1+ / skip**.

---

## TL;DR

CleanCut's moat is **100% on-device + iOS-native + privacy-first** — neither competitor offers this. The cost: a smaller feature surface. Specifically, Cleanvoice offers four cleanup features CleanCut doesn't (breath / mouth sounds / stutter / echo+reverb), and both competitors expose transcription + summary as top-level features while CleanCut buries transcription inside Smart Cut. Six concrete recommendations follow at the end of this doc.

---

## Positioning matrix

| Dimension | **CleanCut** | **Cleanvoice AI** | **Descript** |
|---|---|---|---|
| **Primary platform** | iOS (iPhone) native | Web app | macOS + Windows + web |
| **Mobile-native?** | ✅ | ❌ (responsive web) | ❌ (web only on mobile) |
| **Processing model** | 100% on-device (Core ML / DeepFilterNet3, Speech.framework) | Cloud-based AI | Cloud-based AI (some local features) |
| **Audio leaves device?** | ❌ Never | ✅ Uploaded to Cleanvoice servers | ✅ Uploaded to Descript servers |
| **Works offline?** | ✅ | ❌ | Partial (some features need cloud) |
| **Free tier** | 3 sessions/day · Smart Cut ≤ 5min · Denoise ≤ 3min · WAV-only export · watermark | 30 min one-shot trial, no credit card | 60 min/month · 100 AI credits one-time |
| **Entry price** | **$4.99/mo** | est. $10–20/mo (not on landing) | $16/mo Hobbyist |
| **Lifetime tier** | ✅ $79.99 (privacy-aligned alternative) | ❌ | ❌ |
| **Target audience** | iOS-first podcasters, journalists, voice-memo professionals | Podcasters (web-workflow) | Podcasters + video creators + teams |

**Reading the table:** CleanCut is the only entrant where audio never leaves the device. That's the *one* dimension no competitor can match without rebuilding their stack — protect this aggressively in marketing.

---

## Audio cleanup feature matrix

| Feature | **CleanCut** | **Cleanvoice** | **Descript** |
|---|---|---|---|
| Filler word removal ("um", "uh", custom list) | ✅ Smart Cut | ✅ | ✅ |
| Long silence trim | ✅ (configurable threshold) | ✅ ("deadair") | ✅ |
| Background noise removal (denoise) | ✅ DeepFilterNet3 + intensity slider + A/B | ✅ | ✅ "Studio Sound" |
| Audio merge / concat | ✅ Merge tab + crossfades + LUFS | ❌ (separate "Audio Joiner" free tool) | ✅ multitrack timeline |
| **Breath removal** | ❌ | ✅ | ❌ (Studio Sound smooths but doesn't target) |
| **Mouth sound removal** (clicks, smacks) | ❌ | ✅ | ❌ |
| **Stutter removal** (repeated word/phoneme) | ❌ | ✅ | Partial (manual edit) |
| **Echo / reverb removal** | ❌ | ✅ | Partial (Studio Sound) |
| Custom filler library (add words) | ✅ Pro-gated | ✅ | ✅ |
| Word-level transcript editing | ❌ | Partial | ✅ (text → timeline edit) |
| Multitrack support | ❌ (single source per session) | ❌ | ✅ |
| AI voice / regenerate / overdub | ❌ (off-strategy: privacy) | ❌ | ✅ |
| Transcription (top-level feature) | ❌ (used internally only) | ✅ | ✅ (25 langs) |
| Summary / show-notes generator | ❌ | ✅ | ✅ |
| Audiogram / video export | ❌ | ✅ (free tools) | ✅ |
| Podcast intro/outro mixing | ❌ | ✅ (free tool) | ✅ |
| iOS Share Extension | ✅ | ❌ | ❌ |
| Background processing + push notification | ✅ Pro | ❌ (web wait) | ❌ |

---

## Free-tier shape comparison

| Constraint | **CleanCut** | **Cleanvoice** | **Descript** |
|---|---|---|---|
| Time-based | 5min Smart Cut · 3min Denoise per file | 30 min total trial | 60 min/month media |
| Daily/quota | 3 sessions/day per feature | One-shot trial | 100 AI credits one-time |
| Watermark on free output | ✅ "Cleaned with CleanCut" voice tag | ❌ (or limited per credit) | ❌ |
| Output format limit | WAV only (no M4A/MP3) | Unknown | None stated |

**Reading:** CleanCut's free tier is more *recurring* (every day you get a fresh 3-session quota) but more *restricted per session*. Cleanvoice and Descript front-load free credit then push hard for upgrade. CleanCut's pattern fits "I clean voice memos every day" better; their pattern fits "let me try once before I commit."

---

## Gap analysis — what CleanCut should do about it

Each gap is scored on **(value to user)** × **(fit with privacy-first on-device strategy)** and bucketed into ship-v1 / v1.1 / skip.

### 🟢 SHIP v1 (high value, low effort, on-strategy)

**G-1. Expose transcription as a top-level feature.**
CleanCut already runs `SFSpeechRecognizer` for Smart Cut analysis — the transcript exists in memory. Both competitors expose this as a primary value prop. Cost to add: a "Copy transcript" / "Export .txt" button in Smart Cut Studio. No new ML, no new infra. Marketing win: "iOS audio cleaner *with* on-device transcription, no upload."

**G-2. Surface the privacy moat in App Store listing + paywall hero copy.**
Currently the privacy-first promise is implicit. Make it the headline. Example hero copy: *"Your audio never leaves your phone. Period."* Both competitors *can't* say this without lying.

### 🟡 CONSIDER v1.1 (medium value, on-strategy, more effort)

**G-3. Breath removal.**
Cleanvoice ships this as a distinct feature. Voice memo / interview users will notice the gap. Implementation path: detect short low-energy segments between phonemes (Speech.framework gives word timings; gaps < 250ms with low RMS = breath candidates). Could ship as a Smart Cut sub-toggle (`Remove breaths`). On-device, no new model needed.

**G-4. Show-notes / summary generator.**
With iOS 26+ Apple Intelligence Foundation Models, you can summarize the transcript fully on-device. Competitor parity at near-zero infra cost. Gate behind iOS 26 minimum or fallback to "transcript only" on iOS 17.

**G-5. Stutter removal.**
Cleanvoice has it. Speech.framework gives phoneme-ish granularity; consecutive identical word stems = stutter. More algorithmic work than G-3 but doable on-device. Lower priority than breaths because podcasters complain about breaths more than stutters.

### 🔴 SKIP — explicit non-goals

**G-6. Mouth sound removal (clicks, smacks).**
Difficult on-device without a dedicated ML model. Adobe Podcast does this with cloud DSP. Privacy-first stance means no cloud option. Defer until DeepFilterNet3-class on-device model exists for it.

**G-7. Echo / reverb removal.**
Same reasoning as G-6 — needs cloud-class DSP today, no good on-device path. Watch for future Apple frameworks.

**G-8. Multitrack timeline.**
Off-strategy. CleanCut is a "clean a single file" app, not a DAW. Descript owns multitrack; trying to compete there means a 10× scope increase. Stay focused.

**G-9. AI voice clone / regenerate / overdub.**
Voice cloning is fundamentally a privacy hazard *and* an ethics issue (deepfake risk). Doesn't fit the brand. Hard skip.

**G-10. Web/desktop port.**
Parent monetization spec line 25 explicitly rules this out. The on-device privacy moat *is* the iOS-only constraint. Honor it.

**G-11. Audiogram / video export, intro/outro mixers, podcast name generator.**
Cleanvoice's free-tools section is a marketing funnel (free utilities → trial conversion). CleanCut's funnel is the iOS App Store + the post-onboarding paywall. Don't replicate Cleanvoice's web-tool sprawl on iOS — different distribution channel.

---

## Pricing analysis

CleanCut at **$4.99/mo** is the cheapest entry point. Descript starts at **$16/mo**. Cleanvoice is mid-range and per-minute on top of subscription. Implications:

- CleanCut's price feels *cheap* relative to what the audience pays for similar value. Could justifiably move to $6.99 or $7.99/mo without losing competitive ground. Doing this post-launch from real conversion data is safer than guessing now.
- The lifetime tier ($79.99) is genuinely unique — neither competitor offers it. Privacy-conscious buyers (the bullseye audience) actively prefer "pay once" over "subscribe forever." Don't drop this tier even if conversion data shows lower take-rate than monthly — the tier *is* part of the brand.
- The yearly $39.99 (33% off) is the high-conversion target per industry data. Already aligns with paywall Variant A's annual default.

---

## Recommendations — what to do this week

In rough priority order:

1. **Ship G-1 (expose transcription).** Lowest cost, highest marketing leverage. Add a "Transcript" tab or sheet in Smart Cut Studio with copy/export. ~1-2 hours of work.

2. **Rewrite paywall + App Store hero copy to lead with privacy (G-2).** Headline: *"On-device. Always."* or similar. Currently the paywall headline says "Cut fillers. Clean noise. No limits." — that's a feature claim, not a moat claim. Both messages can coexist.

3. **Add G-3 (breath removal) to Sub-project 5 (Retention) or as a fast-follow in Sub-project 4.5.** Plan it now, ship within 2-3 weeks of launch. It's a near-direct check-the-box gap closure for the Cleanvoice comparison.

4. **Defer G-4 (summary).** Wait for iOS 26 floor decision. If you bump min to iOS 26 in 2026 H2, Foundation Models makes this a 1-day add. Today on iOS 17, it'd require a third-party LLM call — which violates the privacy moat.

5. **Don't engage G-6 through G-11.** Focus is the strategy. Cleanvoice and Descript own the cloud-feature surface; CleanCut owns iOS+privacy. Pick one fight.

6. **Set a 90-day post-launch review.** After 90 days of TestFlight + App Store data, revisit this audit with real conversion + retention numbers. If Day-30 retention beats 30% (good for utility apps), the focused-strategy bet is paying off; if it's under 20%, reconsider G-3/G-5 ship priority.

---

## Risks to this analysis

- **Competitor feature freshness.** This audit fetched cleanvoice.ai/features and descript.com/pricing on 2026-05-07. Either could have shipped new features yesterday that aren't reflected here. Lower-risk than relying on training data alone, but not real-time.
- **Pricing not fully retrieved for Cleanvoice** (their pricing page wasn't directly fetched; numbers above are estimated from training data). If exact tiers matter for the paywall comparison, fetch cleanvoice.ai/pricing directly.
- **Audience overlap is assumed.** "Podcasters who'd switch from Cleanvoice to CleanCut" is the assumed bullseye but not validated. If CleanCut's actual adopters are voice-memo journalists or audiobook narrators, gap priorities may shift (e.g., G-3 breaths matters more for narrators than podcasters).
- **No usage data yet.** This is a pre-launch audit. The strongest inputs (which features users actually want, which they ignore) come from beta + launch metrics. Treat this doc as a prior, not a verdict.
