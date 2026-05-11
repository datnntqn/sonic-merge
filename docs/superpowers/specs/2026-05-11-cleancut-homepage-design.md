# CleanCut Homepage — Design Spec

**Status:** Approved (visual companion mockups: `.superpowers/brainstorm/8973-1778513837/`)
**Date:** 2026-05-11
**Repo:** `~/Desktop/DatNNT/App/cleancut-legal/` (GitHub Pages, origin `github.com:datnntqn/clearcut-legal.git`)
**Scope:** Replace `cleancut-legal/index.html` with a full product landing page; update `cleancut-legal/style.css` to the v1.1 fire palette; add the real app icon as `cleancut-logo.png` referenced by all four pages.

---

## 1. Goal & non-goals

**Goal:** Turn `cleancut-legal/index.html` from a minimal "About" page into a full product landing page that introduces CleanCut to solo podcasters and the indie-iOS / Product Hunt audience. The page must read as continuous with the app's v1.1 fire-palette brand identity, present the three tools, anchor on the on-device privacy moat, and surface pricing.

**Non-goals (explicitly out of scope):**

- A new domain or hosting setup — this is the existing GitHub Pages repo, served from the same origin.
- App Preview video or animated GIF demos — deferred to v1.1 per the App Store listing spec.
- Customer testimonials — none exist at v1.0; adding hypothetical ones is FTC-risky.
- Email signup forms / mailing-list integration — adds backend (Buttondown/ConvertKit) for low pre-launch ROI.
- Internationalization — `en-US` only at v1.0 (matches the App Store listing spec).
- Re-architecting the legal pages themselves (`privacy.html`, `terms.html`, `support.html`) — they inherit the palette cascade but their structure / copy are untouched.
- Backend, analytics, A/B testing — none. The site stays static HTML + CSS.

---

## 2. File touch list

```
cleancut-legal/
├── index.html        # FULL REWRITE — new landing page
├── style.css         # UPDATE — fire palette + new section classes
├── cleancut-logo.png # NEW — copy of SonicMerge/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
├── privacy.html      # MINIMAL EDIT — favicon + brand-mark <img> swap (palette cascades from style.css)
├── terms.html        # MINIMAL EDIT — favicon + brand-mark <img> swap (palette cascades from style.css)
└── support.html      # MINIMAL EDIT — favicon + brand-mark <img> swap (palette cascades from style.css)
```

`privacy.html`, `terms.html`, `support.html` get **two** edits each: (a) add `<link rel="icon" href="cleancut-logo.png">`, (b) replace `<span class="brand-mark"></span>` with `<img src="cleancut-logo.png" alt="CleanCut" class="brand-mark">`. Body copy unchanged.

---

## 3. Visual identity — the v1.1 fire palette

Source of truth: `SonicMerge/DesignSystem/SonicMergeTheme.swift` + `SonicMergeTheme+Appearance.swift:78-100` (lightClassic).

```css
:root {
  /* Brand */
  --action: #EA580C;           /* Burnt orange — chrome, nav, primary CTAs */
  --ai: #F0506E;               /* Magenta — AI moments, flat single color */
  --ai-grad-1: #FF4E50;        /* Ember red */
  --ai-grad-2: #F9A66C;        /* Ember orange */
  --ai-grad-3: #F0506E;        /* Magenta (same as --ai) */
  --ai-grad-4: #6F2DBD;        /* Deep violet */

  /* Surfaces */
  --bg: #FBFBFC;               /* Canvas (matches app `surfaceBase`) */
  --bg-soft: #ffffff;          /* Card (matches app `cardSurface`) */
  --bg-dark: #0A0A18;          /* Deep navy (matches app dark `surfaceBase`) */
  --bg-dark-card: #15172B;     /* Deep navy card */

  /* Text */
  --text: #1C1C1E;
  --text-soft: #5a5a63;
  --text-dim: #9a9aa3;

  /* Lines */
  --border: #e5e5ea;

  --max: 880px;                /* Was 720px — landing page is wider than legal pages */
}

/* Fire gradient — for the brand mark, hero-text accent, card top stripe, AI CTAs */
.ai-gradient-bg {
  background: linear-gradient(90deg, var(--ai-grad-1) 0%, var(--ai-grad-2) 30%, var(--ai-grad-3) 60%, var(--ai-grad-4) 100%);
}

.ai-gradient-text {
  background: linear-gradient(90deg, var(--ai-grad-1) 0%, var(--ai-grad-2) 30%, var(--ai-grad-3) 60%, var(--ai-grad-4) 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}
```

**Token usage rules (must mirror the in-app color-discipline doctrine):**

| Element | Token | Why |
|---|---|---|
| Header brand text "CleanCut" | `--text` | Brand-name reads as content, not chrome accent |
| Nav links (`About`, `Privacy`, `Terms`, `Support`) hover/active | `--action` | Navigation = chrome = burnt orange |
| Primary CTA "Get on App Store →" | `--action` background, white text | Primary action |
| Pricing card highlight (the Yearly / "Save 58%" card) | `--action` border | Highlight card via primary-action color |
| Feature card top stripe (Smart Cut / Denoise / Merge) | Fire gradient `.ai-gradient-bg` | Cards represent AI features |
| Hero text accent: "All on your iPhone." | Fire gradient `.ai-gradient-text` | The phrase is the brand-AI promise; gradient anchors it |
| Phone-frame "7:32 saved" big number | Fire gradient `.ai-gradient-text` | The savings number is the AI outcome |
| Phone-frame "Apply Cuts" capsule | Fire gradient `.ai-gradient-bg` | Mirrors in-app Smart Cut Apply CTA |
| Privacy-moat section eyebrow ("On-device. Always.") | `--ai` flat magenta | Single-color AI moment in a dark context |
| Privacy-moat section background | `--bg-dark` linear-gradient to `--bg-dark-card` | Contrasts the light page; signals "this is the moat" |
| FAQ summary chevron / "$" pricing digit | `--text` | Plain content |
| Footer | `--border` top, `--text-soft` body | Documentation-aesthetic footer (matches legal pages) |

**Anti-patterns (do NOT do):**

- Don't put the fire gradient on the header brand mark image — the image is already gradient. Adding gradient again would double-stack.
- Don't tint the FAQ section AI-color — it's plain content.
- Don't use the fire gradient on the App Store CTA — that's the primary action (chrome), uses `--action` burnt orange. Reserve the gradient for AI moments only.
- Don't use both `--ai` flat magenta AND the fire gradient in the same section — pick one. Single section = one AI treatment.

---

## 4. Layout — section structure

The page is a single scroll-through document, 880px max content width (legal pages were 720px; the wider hero deserves more breathing room). Sticky header. Each section is wrapped in a `<section>` semantic element. Mobile breakpoint at 720px collapses the hero from two-column to one-column (text → phone).

### Section 1 — Sticky header (unchanged structure, restyled)

```html
<header class="site">
  <div class="inner">
    <a href="index.html" class="brand">
      <img src="cleancut-logo.png" alt="CleanCut" class="brand-mark">
      <span>CleanCut</span>
    </a>
    <nav class="site">
      <a href="index.html" class="active">About</a>
      <a href="privacy.html">Privacy</a>
      <a href="terms.html">Terms</a>
      <a href="support.html">Support</a>
    </nav>
  </div>
</header>
```

The only HTML change vs. today's `index.html`: `<span class="brand-mark"></span>` → `<img src="cleancut-logo.png" alt="CleanCut" class="brand-mark">`. The styling change is in `style.css`: `.brand-mark` was a `display:inline-block` with `linear-gradient` background; now it's an `<img>` with `border-radius: 7px` and explicit `width/height: 28px`.

### Section 2 — Hero

Two-column on desktop, stacked on mobile.

**Left column** (`max-width: 460px`):

- Eyebrow: `A 30-MIN RECORDING → 22-MIN EDIT` (burnt orange, uppercase, letter-spaced)
- H1: three-line headline
  - Line 1: `Cut filler words.`
  - Line 2: `Clean noise. Merge takes.`
  - Line 3: `All on your iPhone.` ← fire-gradient text accent
- Lede paragraph: `An on-device audio editor for podcasters. Your audio never leaves your phone.`
- Primary CTA: `Get on App Store →` (burnt orange pill, white text, drop shadow)
- Sub-CTA line: `7-day free trial · $19.99/yr or $39.99 lifetime` (dim text)

**Right column** (centered, ~260px wide):

- iPhone-frame mockup of the Smart Cut **results state** (CSS-rendered, see §5 below for full specification)

**Background:** soft radial gradient anchored at top-left, fading from `rgba(255,78,80,0.07)` through `rgba(240,80,110,0.05)` through `rgba(111,45,189,0.04)` to transparent. Lifts the hero without competing with the phone frame.

**Note on the App Store CTA:** the App Store URL doesn't exist pre-launch. CTA `<a>` uses `href="#"` plus a hidden-on-mobile disclaimer (`<p class="cta-disclaimer">App Store link goes live at launch.</p>`) under the sub-CTA line. Post-launch, replace `href="#"` with the App Store URL and delete the disclaimer.

### Section 3 — Three feature cards

Single section with three cards in a grid. Same content as today's `index.html`, lightly expanded:

**Smart Cut card:**
```
SMART CUT
Auto-detect filler words ("um," "uh," "like"), long silences, and
dead air. Every cut shows on a waveform timeline before export —
nothing is removed without your review.

Auto-transcript export to .txt, .srt, or .vtt. Per-session language
picker. iOS 26: long-form streaming via Apple's SpeechAnalyzer with
a live transcript pane during analysis.
```

**Denoise card:**
```
DENOISE
DeepFilterNet3 on iPhone — a neural network built for speech.
Intensity slider to taste the result, A/B toggle to hear exactly
what changed. Works on subway commutes, busy cafés, humming offices.
```

**Merge card:**
```
MERGE
Drag clips onto a timeline, set crossfades, export as M4A or WAV.
Loudness auto-normalized to broadcast standard (BS.1770 LUFS) —
volume jumps between clips disappear.
```

Each card has:
- Fire-gradient top stripe (4px tall, full card width, `.ai-gradient-bg`)
- Card label (uppercase, 13px, weight 700, color `--text`)
- Card body (14px, color `--text`, line-height 1.55)
- White background, 1px `--border`, 12px radius, subtle shadow (`0 2px 6px rgba(0,0,0,0.04)`)
- Grid: 3 columns at ≥720px, 1 column below

### Section 4 — Privacy moat (dark strip)

Full-bleed dark section, content centered to 720px. Background: `linear-gradient(135deg, var(--bg-dark) 0%, var(--bg-dark-card) 100%)`.

- Eyebrow: `ON-DEVICE. ALWAYS.` (magenta `--ai`, uppercase, letter-spaced)
- H2: `Your voice. Your iPhone. No cloud.`
- Body paragraph: the verbatim "every comparable tool uploads your audio…" paragraph from the marketing copy doc (`docs/marketing/cleancut-v1-marketing-copy.md` §4):

```
Every comparable tool uploads your audio to a server. Descript, Riverside,
Cleanvoice, Adobe Podcast — all of them ship your voice to a data center,
run AI on it, and ship the result back. That's how it's been because the
models were too big to run on a phone.

CleanCut runs entirely on your iPhone. The transcription model is Apple's
on-device SpeechAnalyzer (or SFSpeechRecognizer on iOS 17–25). The denoise
model is DeepFilterNet3, a small neural network built for embedded
inference. The merge timeline is AVFoundation. No analytics SDK, no
third-party tracker, no account. Turn on airplane mode — CleanCut still
works.

That's not a marketing claim we can hide behind. It's a structural
property: there's no server to send it to.
```

Text color: white at 0.92 opacity for body, white at 1.0 for emphasized phrases.

> **Note:** Listing competitor names in marketing copy is acceptable; the App Store guideline 2.3.7 against naming competitors applies to App Store *metadata* (the app listing on ASC), not to the marketing website. Verified by reviewing Apple's developer guidelines.

### Section 5 — Pricing

Three-card grid. Free / Pro Yearly (highlighted, default) / Pro Monthly / Lifetime → actually four cards (Free is the leftmost, then three Pro tiers); grid is `auto-fit` so it wraps cleanly on narrow widths.

Card structure:

```
┌──────────────────────────┐
│ FREE                     │  ← tier label, uppercase, --text-soft
│                          │
│ $0                       │  ← price, 28px, weight 800
│ free forever             │  ← period, --text-soft
│                          │
│ • 3 Smart Cut / day      │  ← bullets, 13px
│ • 3 Denoise / day        │
│ • Files ≤ 5 / 3 min      │
│ • Unlimited Merge ≤ 3    │
│                          │
│ [ Download →     ]       │  ← CTA: ghost (border, no fill) for Free
└──────────────────────────┘
```

The **Yearly card** is highlighted with a `--action` 2px border and a "MOST POPULAR" ribbon at top-right. Yearly card displays:

```
PRO YEARLY
$19.99
per year (Save 58%)
[ 7-day trial, then $19.99/yr ]

• Everything in Free, unlimited
• Export to M4A, MP3, WAV
• No watermark
• Custom filler libraries
• Background processing
```

Monthly + Lifetime cards mirror Yearly's content with appropriate price/period swaps. All Pro CTAs are filled burnt-orange buttons.

**Pre-launch note:** all 4 CTAs point at `href="#"` until App Store URL exists; the hero's CTA-disclaimer covers all of them ("App Store link goes live at launch").

### Section 6 — FAQ

`<details>` / `<summary>` collapsible elements (HTML-native, no JS). Each item:

```html
<details>
  <summary>Does Smart Cut work without internet?</summary>
  <p>Yes. Both Smart Cut (transcription) and Denoise run on-device. You can put your phone in airplane mode and CleanCut works.</p>
</details>
```

Six FAQ items (verbatim from `docs/marketing/cleancut-v1-marketing-copy.md` §7):

1. Does Smart Cut work without internet?
2. Which languages does Smart Cut support?
3. How does the iOS 26 version differ from iOS 17?
4. How long does a recording take to process?
5. Why is the free tier limited?
6. Is there a Mac version?

Styling:
- `summary` cursor pointer, weight 600, color `--text`, 16px padding, border-bottom `--border`
- `summary::-webkit-details-marker { display: none }` to hide the default triangle
- Custom chevron via `summary::after` with `content: "+"` (rotates to "×" via CSS-only `[open]` selector)
- `<p>` inside `<details>` gets 0 16px 16px padding, color `--text-soft`

### Section 7 — Founder note

Brief inline section, no card chrome. ~3 short paragraphs. Verbatim from marketing copy doc §6 ("Hi, I'm Đạt…"). Closes with `<a href="mailto:support@cleancut.app">support@cleancut.app</a>`.

The footer's `<p>...&copy; 2026 CleanCut...</p>` already exists — keep it as-is. Section 7 sits above that footer.

### Section 8 — Footer

Existing footer is fine, just inherits the new palette:

```html
<footer class="site">
  <p>&copy; 2026 CleanCut · <a href="privacy.html">Privacy</a> · <a href="terms.html">Terms</a> · <a href="support.html">Support</a></p>
</footer>
```

No structural change. Color tokens cascade from the new palette.

---

## 5. The phone-frame mockup (technical detail)

Rendered as pure CSS + inline SVG — no PNG asset. Total weight: ~3KB of markup. Designed so it can be replaced with a real screenshot at any future date by swapping the inner `.phone-screen` div's contents for `<img src="hero-screenshot.png">`.

```html
<div class="phone-frame">
  <div class="phone-notch"></div>
  <div class="phone-screen">
    <!-- Status bar -->
    <div class="status-bar">
      <span>9:41</span>
      <span class="battery">▮▮▮▯ 98%</span>
    </div>

    <!-- Nav bar -->
    <nav class="phone-nav">
      <span class="back">‹ Sessions</span>
      <span class="title">Smart Cut</span>
      <span class="edit">Edit</span>
    </nav>

    <!-- Summary card: "7:32 saved · 124 fillers · 8 pauses" -->
    <div class="phone-card phone-summary">
      <div class="row"><span class="label">Saved</span><span class="meta">in 90s</span></div>
      <div class="big-num ai-gradient-text">7:32</div>
      <div class="chips">
        <span class="chip chip-ai">124 fillers</span>
        <span class="chip chip-action">8 pauses</span>
      </div>
    </div>

    <!-- Waveform with strikethroughs -->
    <div class="phone-card phone-waveform">
      <div class="card-label">Waveform</div>
      <svg viewBox="0 0 220 50">...</svg>
    </div>

    <!-- Filler category row -->
    <div class="phone-card phone-category">
      <div>
        <div class="cat-title">Hesitations</div>
        <div class="cat-sub">um, uh, ah · 47 found</div>
      </div>
      <div class="toggle toggle-on"></div>
    </div>

    <!-- Apply Cuts CTA at bottom -->
    <div class="phone-cta ai-gradient-bg">Apply Cuts</div>
  </div>
</div>
```

**Phone frame styling:**

- Width 260px (260px is intentional — small enough not to dominate the hero, large enough to read the inner UI; on mobile breakpoint the frame scales to ~220px)
- Height 530px
- Background `--bg-dark`, 38px border-radius, 10px padding (creates the bezel)
- Box-shadow stack: `0 0 0 1.5px #1a1a24` (bezel highlight), `0 30px 60px -20px rgba(111,45,189,0.35)` (violet ambient glow), `0 18px 40px -10px rgba(255,78,80,0.18)` (red ambient glow). The two-color shadow stack mirrors the fire gradient.

**Inner screen styling:**

- Background `--bg`
- 30px border-radius (matches the phone frame minus padding)
- All inner cards: white background, 14px radius, 0 1px 3px shadow

**Waveform SVG:**

- viewBox 220×50
- ~54 vertical bars, height 6–34, x-spacing 4, fill `--text` at 0.85 opacity
- 4 magenta filler-strikethrough overlays at variable widths/positions
- 2 burnt-orange pause-region overlays at 0.25 opacity
- Bar heights are hand-tuned to look like "natural speech rhythm" — not perfectly random, but not uniform. Already drafted in the visual companion mockup.

**Future migration to real screenshot:**

When a real Smart Cut results screenshot is available:

```html
<div class="phone-screen">
  <img src="hero-screenshot.png" alt="Smart Cut results showing 7:32 saved with 124 fillers detected">
</div>
```

The `.phone-screen` container handles `border-radius` clipping; the `<img>` fills the screen. Resolution: 540×1170 (2.25× the rendered 240×520 to handle Retina).

---

## 6. Style.css cascade impact on legal pages

`style.css` is shared across all four pages. Three concrete changes affect the legal pages:

1. **Colors change.** Today: indigo `#5856D6` + lime `#A7C957`. New: burnt orange `--action` `#EA580C` + fire gradient. Visible effects on `privacy.html` / `terms.html` / `support.html`:
   - `<a>` links shift from indigo to burnt orange (`--action`)
   - The `.brand-mark` shifts from indigo→lime gradient to the real app icon
   - The `.callout` left-border shifts from lime to magenta `--ai`
   - The CTA pill (if any future page adds one) shifts from indigo to burnt orange
2. **`--max` widens from 720px to 880px.** Affects all four pages — the legal pages will use the extra width too, which doesn't harm readability for short documents.
3. **New utility classes** (`.ai-gradient-bg`, `.ai-gradient-text`, `.cards`, `.callout`, `.cta`) gain new variants but the legal pages don't reference them.

**No breaking changes to legal-page markup** — they continue to render correctly with the new palette. Verify by visual diff after implementation.

---

## 7. Accessibility

- All text-on-color combinations must clear WCAG AA contrast (4.5:1 for body text, 3:1 for large text):
  - White on `--action` burnt orange (`#EA580C` ≈ 4.4 contrast): borderline AA. Use **bold weight** on white-on-orange CTAs (large-text exception 3:1 applies to 18pt+ or 14pt+ bold).
  - White on `--bg-dark` (`#0A0A18`): pure black, 19+ contrast, easy AA.
  - `--text` `#1C1C1E` on `--bg` `#FBFBFC`: 16+ contrast, easy AA.
  - `--text-soft` `#5a5a63` on `--bg` `#FBFBFC`: 6.8 contrast, passes AA.
  - Magenta `--ai` `#F0506E` on `--bg-dark` `#0A0A18`: 5.4 contrast, passes AA.
- Fire-gradient text: the four stops average around 4–5 contrast on white. Use **weight 800** on all gradient-text headings to land in large-text territory (3:1 exception).
- All semantic landmarks (`header`, `nav`, `main`, `section`, `footer`).
- Skip-to-main-content link at the very top of `<body>`: `<a class="skip-link" href="#main">Skip to content</a>` — visually hidden until focused.
- All `<img>` elements have meaningful `alt` text. The header logo's alt is `"CleanCut"`. The phone-frame screenshot (if/when added) gets a descriptive alt.
- `<details>` / `<summary>` FAQ is keyboard-accessible by default.
- Prefers-color-scheme: out of scope for v1. Light-only.

---

## 8. Performance budget

- Page weight target: **under 100 KB total** (HTML + CSS + logo image, excluding browser-internal fonts).
  - HTML: ~12 KB (the full landing page is verbose but compresses well)
  - CSS: ~6 KB (pure CSS, no framework)
  - Logo PNG: ~15 KB (256×256 PNG of the 1024 source, downsampled via `sips -Z 256`)
  - Total: ~33 KB pre-gzip, ~12 KB gzipped — well within budget.
- No JavaScript. FAQ uses `<details>`. No analytics, no fonts, no third-party scripts.
- No web fonts — use the system-font stack already in `style.css`.
- Lighthouse target: **100/100/100/100** at v1.

---

## 9. SEO + social

- `<title>`: `CleanCut — Cut, clean, and merge audio on your iPhone` (61 chars)
- `<meta name="description">`: `CleanCut is an on-device audio editor for iPhone. Trim filler words, denoise background noise, and merge takes — your audio never leaves the phone.` (152 chars)
- Open Graph tags:
  - `og:title` matches `<title>`
  - `og:description` matches `meta description`
  - `og:image` references `cleancut-logo.png` (1024×1024 — the OG-image min is 1200×630 but Apple-style square icons work as fallback)
  - `og:url` `https://datnntqn.github.io/clearcut-legal/`
- Twitter Card:
  - `twitter:card` `summary` (uses the square og:image)
  - `twitter:title`, `twitter:description` mirror og
- No schema.org / JSON-LD at v1 (Apple App Store metadata handles app schema upstream).

---

## 10. Implementation hand-off — what the plan must address

The implementation plan (next step, via `superpowers:writing-plans`) needs to define:

1. **Logo asset prep:** `cp` the source 1024 PNG, optionally `sips -Z 256` for a smaller artifact, copy into `cleancut-legal/`.
2. **style.css full rewrite:** the new palette + new section classes. Replace the file entirely rather than diff-editing (cleaner; the new file is similar in length).
3. **index.html full rewrite:** new 8-section structure as outlined above.
4. **Legal-page minimal edits** (3 files, 2 changes each): favicon link + brand-mark img swap.
5. **Visual verification:** open each of the 4 pages in a browser after edits, confirm:
   - Logo loads at the header
   - Favicon shows in tab
   - Colors look right (no leftover indigo/lime)
   - FAQ `<details>` opens/closes correctly
   - Phone-frame renders correctly at 260px and at the mobile 220px
   - Hero stacks vertically below 720px
6. **Commit + push to GitHub Pages:** the cleancut-legal repo is a separate Git working tree from the main app repo. Commit messages should describe the homepage rewrite + the legal-page cascade.

---

## 11. Open questions

None blocking. Two minor items to surface to the plan author:

- **OQ-1: Mobile breakpoint exact value.** Spec says 720px (the current `style.css` breakpoint). The hero column-stack behavior should be retested at 720px on a real device to confirm the phone-frame mockup doesn't crowd the column. If it does, raise breakpoint to 760px.
- **OQ-2: "MOST POPULAR" ribbon vs. "BEST VALUE" copy.** Spec uses "MOST POPULAR" on the Yearly pricing card. Pre-launch, "most popular" is technically inaccurate (no purchases yet). Implementation plan can choose "BEST VALUE" instead — same UI slot, different copy. Recommend "BEST VALUE" for the pre-launch period; switch to "MOST POPULAR" 30 days post-launch once the data backs it.

---

## 12. Source pointers

- Marketing copy (anchor for body text): `docs/marketing/cleancut-v1-marketing-copy.md`
- Brand color tokens (source of truth): `SonicMerge/DesignSystem/SonicMergeTheme.swift` + `SonicMergeTheme+Appearance.swift`
- App icon source: `SonicMerge/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- Legal site repo: `~/Desktop/DatNNT/App/cleancut-legal/` (remote: `github.com:datnntqn/clearcut-legal.git`)
- App Store listing spec (sibling content): `docs/superpowers/specs/2026-05-09-app-store-listing-design.md`
- Brainstorm mockups (visual companion preview, gitignored): `.superpowers/brainstorm/8973-1778513837/`
