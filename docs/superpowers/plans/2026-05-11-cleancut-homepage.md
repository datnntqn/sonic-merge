# CleanCut Homepage Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `cleancut-legal/index.html` with a full product landing page, update `style.css` to the v1.1 fire palette, ship the real app icon, and cascade the palette to the three legal pages — without touching the legal-page body copy.

**Architecture:** Pure static HTML + CSS. No framework, no JavaScript, no build pipeline. Single `style.css` shared across all four pages. Hero phone-frame mockup is pure CSS + inline SVG (no PNG asset). The implementation lives in a **separate Git repository** from the main app: `~/Desktop/DatNNT/App/cleancut-legal/` (remote: `git@github.com:datnntqn/clearcut-legal.git` — see Spec §11 OQ-1 about the repo-name typo).

**Tech Stack:** HTML5, CSS3, inline SVG. macOS `sips` for image resizing. Git. GitHub Pages for hosting.

**Spec:** `docs/superpowers/specs/2026-05-11-cleancut-homepage-design.md`
**Canonical mockup:** `.superpowers/brainstorm/8973-1778513837/hero-with-logo.html` — the implementation should match this pixel-for-pixel for the hero block.
**Marketing copy source:** `docs/marketing/cleancut-v1-marketing-copy.md` — body text for sections 3, 4, 5, 6, 7 lifts from this doc.

**Repo-path note for agentic workers:** All file edits in this plan happen in `~/Desktop/DatNNT/App/cleancut-legal/`, NOT the main SonicMerge app repo. Each step lists absolute paths to avoid confusion. Verification commands include `cd /Users/datnnt/Desktop/DatNNT/App/cleancut-legal` where relevant. Git commits go to the cleancut-legal remote, not main app remote.

**Verification approach:** Static-site work doesn't have a unit-test layer. "Verification" in this plan means:
- Visual inspection by opening the file in a browser (`open /Users/datnnt/Desktop/DatNNT/App/cleancut-legal/index.html`)
- Lighthouse score in Chrome DevTools (target: 100/100/100/100)
- WCAG AA contrast spot-checks with https://webaim.org/resources/contrastchecker/
- Grep-level checks to confirm the right strings are present / old strings are gone

---

## Chunk 1: Asset prep + style.css palette migration

**Why this chunk:** The new homepage depends on the real app icon being present at `cleancut-logo.png` and on `style.css` carrying the new fire palette tokens. Doing this first means subsequent chunks can reference the new tokens without forward-declaring them. After this chunk, the three legal pages still render correctly (palette cascades), and `index.html` still works (it'll look a bit broken because the abstract gradient mark is gone, but no crashes).

**At end of chunk:**
- `cleancut-legal/cleancut-logo.png` exists (a 256×256 copy of the app icon).
- `cleancut-legal/style.css` has been rewritten with the v1.1 fire palette + new utility classes for the landing page.
- The three legal pages (`privacy.html` / `terms.html` / `support.html`) still render correctly with the new colors (link colors shift from indigo to burnt orange; the abstract gradient `.brand-mark` is now an orange square because `.brand-mark` was changed to expect an `<img>` — this is cosmetic; Chunk 2 fixes the legal pages).
- Lighthouse Performance score on `index.html` is still 100 (we haven't touched it yet; the page just loses one tiny gradient effect on the brand mark).

### Task 1.1: Copy the app icon into cleancut-legal

**Files:**
- Create: `/Users/datnnt/Desktop/DatNNT/App/cleancut-legal/cleancut-logo.png`
- Source: `/Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMerge/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`

- [ ] **Step 1.1.1: Resize the 1024 PNG to 256×256 using sips and copy to cleancut-legal**

```bash
sips -Z 256 \
  /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMerge/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png \
  --out /Users/datnnt/Desktop/DatNNT/App/cleancut-legal/cleancut-logo.png 2>&1 | tail -2
```

Expected output: paths printed by `sips`. No errors.

- [ ] **Step 1.1.2: Verify the file exists and is under 20 KB**

```bash
ls -la /Users/datnnt/Desktop/DatNNT/App/cleancut-legal/cleancut-logo.png
```

Expected: file exists, size between 10 KB and 20 KB. (The source 1024 PNG is 200 KB; 256×256 is roughly 14 KB.)

- [ ] **Step 1.1.3: Open the file to spot-check it visually**

```bash
open /Users/datnnt/Desktop/DatNNT/App/cleancut-legal/cleancut-logo.png
```

Expected: macOS Preview opens. You see deep-navy canvas with symmetric fire-gradient waveform bars and a central white diagonal "cut" mark. If you see indigo/lime or a corrupt image, the wrong source got copied — restart from Step 1.1.1.

- [ ] **Step 1.1.4: Stage the new asset**

```bash
cd /Users/datnnt/Desktop/DatNNT/App/cleancut-legal && git add cleancut-logo.png && git status
```

Expected: `new file: cleancut-logo.png` listed under "Changes to be committed".

> **Do not commit yet.** Commit happens after the `style.css` rewrite (Task 1.2) so both changes ship as one atomic palette migration.

### Task 1.2: Rewrite style.css with the v1.1 fire palette

**Files:**
- Modify (full rewrite): `/Users/datnnt/Desktop/DatNNT/App/cleancut-legal/style.css`

The file is small (196 lines today) and the structural changes are spread across most rules. Per the spec §10 step 2, a full rewrite is cleaner than diff-edits. The new file is ~280 lines.

- [ ] **Step 1.2.1: Replace `style.css` with the new palette and utility classes**

Open `/Users/datnnt/Desktop/DatNNT/App/cleancut-legal/style.css` and replace its entire contents with the block below. (Use your editor's "Save As" / overwrite; do not leave any of the old content.)

```css
:root {
  /* Brand — v1.1 fire palette */
  --action: #EA580C;           /* Burnt orange — chrome, nav, primary CTAs */
  --action-hover: #c2470a;     /* Burnt orange, darker, for hover */
  --ai: #F0506E;               /* Magenta — AI moments, flat single color */
  --ai-grad-1: #FF4E50;        /* Ember red */
  --ai-grad-2: #F9A66C;        /* Ember orange */
  --ai-grad-3: #F0506E;        /* Magenta */
  --ai-grad-4: #6F2DBD;        /* Deep violet */

  /* Surfaces */
  --bg: #FBFBFC;
  --bg-soft: #ffffff;
  --bg-dark: #0A0A18;
  --bg-dark-card: #15172B;

  /* Text */
  --text: #1C1C1E;
  --text-soft: #5a5a63;
  --text-dim: #9a9aa3;

  --border: #e5e5ea;

  /* Layout */
  --max: 880px;
}

* { box-sizing: border-box; }

html, body {
  margin: 0;
  padding: 0;
  background: var(--bg);
  color: var(--text);
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  font-size: 17px;
  line-height: 1.55;
  -webkit-font-smoothing: antialiased;
}

a { color: var(--action); text-decoration: none; }
a:hover { text-decoration: underline; }

/* Skip-to-content link, visually hidden until focused */
.skip-link {
  position: absolute;
  left: -9999px;
  top: 0;
  padding: 8px 12px;
  background: var(--text);
  color: #fff;
  z-index: 100;
}
.skip-link:focus { left: 8px; top: 8px; }

/* Header / nav */
header.site {
  border-bottom: 1px solid var(--border);
  background: rgba(255, 255, 255, 0.92);
  backdrop-filter: blur(6px);
  -webkit-backdrop-filter: blur(6px);
  position: sticky;
  top: 0;
  z-index: 10;
}

header.site .inner {
  max-width: var(--max);
  margin: 0 auto;
  padding: 14px 20px;
  display: flex;
  align-items: center;
  gap: 18px;
  flex-wrap: wrap;
}

.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  font-weight: 700;
  font-size: 18px;
  color: var(--text);
}

/* Brand mark is now an <img>, not a span with gradient background */
.brand-mark {
  width: 28px;
  height: 28px;
  border-radius: 7px;
  display: inline-block;
  object-fit: cover;
}

nav.site {
  display: flex;
  gap: 18px;
  margin-left: auto;
  font-size: 15px;
}

nav.site a {
  color: var(--text-soft);
  font-weight: 500;
}

nav.site a.active,
nav.site a:hover {
  color: var(--action);
  text-decoration: none;
}

/* Main content */
main {
  max-width: var(--max);
  margin: 0 auto;
  padding: 40px 20px 80px;
}

main h1 {
  font-size: 34px;
  line-height: 1.15;
  margin: 0 0 8px;
  letter-spacing: -0.5px;
}

main h2 {
  font-size: 22px;
  line-height: 1.25;
  margin: 36px 0 8px;
  letter-spacing: -0.3px;
}

main h3 { font-size: 18px; margin: 24px 0 4px; }
main p { margin: 0 0 14px; }
main ul { padding-left: 22px; margin: 0 0 14px; }
main li { margin-bottom: 6px; }
main strong { font-weight: 700; }

.lede {
  color: var(--text-soft);
  font-size: 19px;
  margin-bottom: 28px;
}

.meta {
  color: var(--text-soft);
  font-size: 14px;
  margin-bottom: 36px;
}

/* Feature card grid — used by index.html only */
.cards {
  display: grid;
  gap: 16px;
  grid-template-columns: 1fr;
  margin: 28px 0 36px;
}

@media (min-width: 720px) {
  .cards { grid-template-columns: 1fr 1fr 1fr; }
}

.card {
  background: var(--bg-soft);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 18px;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.04);
  position: relative;
  overflow: hidden;
}

.card::before {
  content: "";
  position: absolute;
  top: 0; left: 0; right: 0;
  height: 4px;
  background: linear-gradient(90deg, var(--ai-grad-1) 0%, var(--ai-grad-2) 30%, var(--ai-grad-3) 60%, var(--ai-grad-4) 100%);
}

.card h3 {
  margin: 6px 0 6px;
  font-size: 13px;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  color: var(--text);
  font-weight: 700;
}

.card p {
  margin: 0 0 8px;
  font-size: 15px;
  color: var(--text);
  line-height: 1.5;
}

.card p:last-child { margin-bottom: 0; }

/* Callout (used by legal pages and pricing footnotes) */
.callout {
  border-left: 3px solid var(--ai);
  background: var(--bg-soft);
  padding: 14px 18px;
  border-radius: 0 8px 8px 0;
  margin: 24px 0;
  font-size: 15px;
}

/* CTAs */
.cta {
  display: inline-block;
  background: var(--action);
  color: #fff;
  padding: 12px 24px;
  border-radius: 999px;
  font-weight: 600;
  margin-top: 16px;
  box-shadow: 0 8px 22px rgba(234, 88, 12, 0.28);
}

.cta:hover { text-decoration: none; background: var(--action-hover); }

.cta-ghost {
  display: inline-block;
  background: transparent;
  color: var(--text);
  border: 1.5px solid var(--border);
  padding: 10px 22px;
  border-radius: 999px;
  font-weight: 600;
  margin-top: 16px;
}

.cta-ghost:hover { text-decoration: none; border-color: var(--action); color: var(--action); }

.cta-disclaimer {
  font-size: 12px;
  color: var(--text-dim);
  margin-top: 8px;
}

/* Fire-gradient utilities — used by hero text accent + phone-frame */
.ai-gradient-text {
  background: linear-gradient(90deg, var(--ai-grad-1) 0%, var(--ai-grad-2) 30%, var(--ai-grad-3) 60%, var(--ai-grad-4) 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.ai-gradient-bg {
  background: linear-gradient(90deg, var(--ai-grad-1) 0%, var(--ai-grad-2) 30%, var(--ai-grad-3) 60%, var(--ai-grad-4) 100%);
}

/* Footer */
footer.site {
  border-top: 1px solid var(--border);
  padding: 28px 20px 40px;
  text-align: center;
  color: var(--text-soft);
  font-size: 13px;
}

footer.site a { color: var(--text-soft); }
footer.site a:hover { color: var(--action); }

/* ====================================================================
   index.html-only styles — hero, privacy-moat, pricing, FAQ, founder
   ==================================================================== */

/* Hero */
.hero {
  padding: 48px 20px;
  background: radial-gradient(ellipse at top left,
    rgba(255, 78, 80, 0.07) 0%,
    rgba(240, 80, 110, 0.05) 35%,
    rgba(111, 45, 189, 0.04) 70%,
    rgba(255, 255, 255, 0) 100%);
  margin: -40px -20px 36px;
  display: grid;
  grid-template-columns: 1fr;
  gap: 32px;
  align-items: center;
}

@media (min-width: 720px) {
  .hero { grid-template-columns: 1.05fr 0.95fr; padding: 64px 32px; }
}

.hero-eyebrow {
  font-size: 11px;
  color: var(--action);
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 1.4px;
  margin-bottom: 10px;
}

.hero-headline {
  font-size: 34px;
  line-height: 1.05;
  letter-spacing: -1px;
  margin: 0 0 14px;
  color: var(--text);
  font-weight: 800;
}

.hero-lede {
  font-size: 15px;
  color: var(--text-soft);
  margin: 0 0 20px;
  line-height: 1.55;
  max-width: 380px;
}

.hero-phone-wrap {
  display: flex;
  justify-content: center;
}

/* Phone frame */
.phone-frame {
  width: 220px;
  height: 450px;
  background: var(--bg-dark);
  border-radius: 38px;
  padding: 10px;
  box-shadow:
    0 0 0 1.5px #1a1a24,
    0 30px 60px -20px rgba(111, 45, 189, 0.35),
    0 18px 40px -10px rgba(255, 78, 80, 0.18);
  position: relative;
}

@media (min-width: 720px) {
  .phone-frame { width: 260px; height: 530px; }
}

.phone-notch {
  position: absolute;
  top: 14px; left: 50%; transform: translateX(-50%);
  width: 90px; height: 24px;
  background: var(--bg-dark);
  border-radius: 999px;
  z-index: 2;
}

.phone-screen {
  width: 100%; height: 100%;
  background: var(--bg);
  border-radius: 30px;
  overflow: hidden;
  position: relative;
  display: flex;
  flex-direction: column;
}

.phone-status {
  padding: 14px 22px 6px;
  display: flex;
  justify-content: space-between;
  font-size: 10px;
  font-weight: 600;
  color: var(--text);
}

.phone-nav {
  padding: 16px 16px 6px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.phone-nav .back, .phone-nav .edit { font-size: 10px; color: var(--action); }
.phone-nav .title { font-size: 12px; font-weight: 700; color: var(--text); }

.phone-card {
  margin: 6px 14px;
  padding: 10px 12px;
  background: var(--bg-soft);
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.06);
}

.phone-card.summary { padding: 12px; }
.phone-card.summary .row { display: flex; justify-content: space-between; align-items: baseline; }
.phone-card.summary .row .label { font-size: 9px; color: var(--text-soft); text-transform: uppercase; letter-spacing: 0.6px; font-weight: 600; }
.phone-card.summary .row .meta { font-size: 9px; color: var(--text-soft); }
.phone-card.summary .big-num { font-size: 28px; font-weight: 800; color: var(--text); line-height: 1; margin-top: 4px; letter-spacing: -0.6px; }

.phone-chips { display: flex; gap: 6px; margin-top: 8px; }
.chip { font-size: 9px; padding: 3px 7px; border-radius: 999px; font-weight: 600; }
.chip-ai { background: rgba(240, 80, 110, 0.1); color: var(--ai); }
.chip-action { background: rgba(234, 88, 12, 0.1); color: var(--action); }

.phone-card .card-label { font-size: 9px; color: var(--text-soft); margin-bottom: 6px; font-weight: 600; }

.phone-card.category {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.phone-card.category .cat-title { font-size: 11px; font-weight: 700; color: var(--text); }
.phone-card.category .cat-sub { font-size: 9px; color: var(--text-soft); margin-top: 2px; }

.toggle { width: 32px; height: 18px; background: var(--action); border-radius: 999px; position: relative; }
.toggle::after { content: ""; position: absolute; right: 2px; top: 2px; width: 14px; height: 14px; background: #fff; border-radius: 50%; }

.phone-cta {
  margin: auto 14px 18px;
  padding: 11px;
  border-radius: 999px;
  text-align: center;
  box-shadow: 0 8px 20px -4px rgba(240, 80, 110, 0.4);
  font-size: 12px;
  color: #fff;
  font-weight: 700;
  letter-spacing: 0.2px;
}

/* Privacy-moat dark strip */
.moat {
  background: linear-gradient(135deg, var(--bg-dark) 0%, var(--bg-dark-card) 100%);
  color: rgba(255, 255, 255, 0.92);
  padding: 56px 20px;
  margin: 48px -20px;
  border-radius: 16px;
}

.moat-eyebrow {
  font-size: 11px;
  color: var(--ai);
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 1.4px;
  margin-bottom: 10px;
}

.moat h2 {
  color: #fff;
  font-size: 26px;
  margin: 0 0 16px;
  letter-spacing: -0.4px;
}

.moat p { color: rgba(255, 255, 255, 0.86); margin: 0 0 14px; line-height: 1.6; }
.moat p:last-child { margin-bottom: 0; }
.moat em { font-style: normal; color: #fff; font-weight: 600; }

/* Pricing grid */
.pricing {
  display: grid;
  gap: 14px;
  grid-template-columns: 1fr;
  margin: 28px 0 36px;
}

@media (min-width: 540px) { .pricing { grid-template-columns: 1fr 1fr; } }
@media (min-width: 880px) { .pricing { grid-template-columns: repeat(4, 1fr); } }

.tier-card {
  background: var(--bg-soft);
  border: 1px solid var(--border);
  border-radius: 14px;
  padding: 18px;
  display: flex;
  flex-direction: column;
  position: relative;
}

.tier-card.highlighted {
  border: 2px solid var(--action);
  padding: 17px; /* compensate for 2px border */
}

.tier-card .ribbon {
  position: absolute;
  top: -10px; right: 14px;
  background: var(--action);
  color: #fff;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.6px;
  padding: 4px 8px;
  border-radius: 999px;
  text-transform: uppercase;
}

.tier-label { font-size: 11px; color: var(--text-soft); text-transform: uppercase; letter-spacing: 0.6px; font-weight: 700; margin-bottom: 6px; }
.tier-price { font-size: 28px; font-weight: 800; color: var(--text); letter-spacing: -0.5px; line-height: 1; }
.tier-period { font-size: 13px; color: var(--text-soft); margin: 6px 0 14px; }
.tier-card ul { padding-left: 18px; margin: 0 0 14px; font-size: 13px; color: var(--text); }
.tier-card li { margin-bottom: 4px; }
.tier-card .cta, .tier-card .cta-ghost { margin-top: auto; text-align: center; padding: 10px 0; font-size: 13px; box-shadow: none; }
.tier-card .cta { box-shadow: 0 6px 14px rgba(234, 88, 12, 0.22); }

/* FAQ */
.faq { margin: 32px 0; }

.faq details {
  border-bottom: 1px solid var(--border);
}

.faq summary {
  cursor: pointer;
  font-weight: 600;
  color: var(--text);
  padding: 16px 0;
  font-size: 16px;
  list-style: none;
  position: relative;
  padding-right: 32px;
}

.faq summary::-webkit-details-marker { display: none; }

.faq summary::after {
  content: "+";
  position: absolute;
  right: 0;
  top: 14px;
  font-size: 22px;
  font-weight: 400;
  color: var(--text-soft);
  transition: transform 0.2s;
}

.faq details[open] summary::after {
  content: "×";
  font-size: 26px;
  top: 11px;
}

.faq details p {
  padding: 0 16px 16px 0;
  color: var(--text-soft);
  margin: 0;
}

/* Founder note */
.founder {
  background: var(--bg-soft);
  border: 1px solid var(--border);
  border-radius: 14px;
  padding: 24px;
  margin: 36px 0;
}

.founder p { margin: 0 0 12px; font-size: 15px; color: var(--text); line-height: 1.6; }
.founder p:last-child { margin-bottom: 0; }
```

- [ ] **Step 1.2.2: Verify the file syntactically parses**

```bash
# A working file shouldn't crash any tool. Quick sanity check by counting expected rules.
grep -c "^[.#a-z]" /Users/datnnt/Desktop/DatNNT/App/cleancut-legal/style.css
```

Expected: a number around 100 (each CSS rule's selector starts at column 0). If you see 0 or a single-digit number, the file save didn't land.

- [ ] **Step 1.2.3: Open the existing legal pages in a browser to confirm they don't crash visually**

```bash
open /Users/datnnt/Desktop/DatNNT/App/cleancut-legal/privacy.html
open /Users/datnnt/Desktop/DatNNT/App/cleancut-legal/terms.html
open /Users/datnnt/Desktop/DatNNT/App/cleancut-legal/support.html
```

Expected for all three:
- Header still renders. Brand mark `<span class="brand-mark">` is now an **orange square** (because `.brand-mark` was changed from gradient-background to `object-fit: cover` expecting an `<img>`, and the existing `<span>` has no inner image yet — it gets the default text color background). This is **expected**; Chunk 2 fixes it.
- Link colors are burnt orange (`#EA580C`), not the old indigo.
- Body type / layout otherwise unchanged.

If any page is broken in a way that looks worse than "orange square where the brand mark used to be," diagnose before proceeding.

### Task 1.3: Commit the asset + style.css together

**Files:** none beyond what's already staged.

- [ ] **Step 1.3.1: Stage style.css and commit**

```bash
cd /Users/datnnt/Desktop/DatNNT/App/cleancut-legal && \
  git add style.css cleancut-logo.png && \
  git status
```

Expected: both files listed under "Changes to be committed".

- [ ] **Step 1.3.2: Commit**

```bash
cd /Users/datnnt/Desktop/DatNNT/App/cleancut-legal && git commit -m "$(cat <<'EOF'
feat: v1.1 fire palette + real app icon

Replaces the indigo+lime brand colors with the v1.1 fire palette to match
the iPhone app's current identity:
- Burnt orange #EA580C for chrome and primary CTAs
- Magenta #F0506E for AI moments needing a single flat color
- Four-stop fire gradient (red → orange → magenta → violet) for AI moments
  hosting a gradient
- Deep navy #0A0A18 for dark sections

style.css fully rewritten with the new palette + utility classes for the
upcoming landing-page sections (hero, phone-frame, moat, pricing, FAQ,
founder). Legal pages cascade automatically — their colors update but
structure is unchanged.

cleancut-logo.png is a 256×256 downsample of the iPhone app icon
(deep-navy canvas + fire-gradient waveform + central white cut mark).
EOF
)" && git log --oneline -1
```

Expected: commit succeeds, `git log --oneline -1` shows the new commit. Do **not** push yet — Chunk 5 pushes everything at the end after the new `index.html` lands.

---

## Chunk 2: Legal-page minimal edits

**Why this chunk:** With the palette migrated, the three legal pages still have two cosmetic issues: (1) their headers show no logo (just an orange `<span>` placeholder), (2) they have no favicon. Both fixes are mechanical and identical across the three files: add a `<link rel="icon">` line in `<head>`, and swap `<span class="brand-mark"></span>` for `<img src="cleancut-logo.png" alt="CleanCut" class="brand-mark">`. After this chunk, all three legal pages render correctly with the real logo in the header and tab favicon.

**At end of chunk:**
- `privacy.html`, `terms.html`, `support.html` each have a favicon link in `<head>`.
- Each replaces the `<span class="brand-mark">` with an `<img>` referencing `cleancut-logo.png`.
- Visual inspection of the three pages shows: tab favicon = app icon, header brand mark = app icon.

### Task 2.1: Edit privacy.html, terms.html, support.html — favicon + logo img

**Files (3 files, 2 edits each):**
- Modify: `/Users/datnnt/Desktop/DatNNT/App/cleancut-legal/privacy.html`
- Modify: `/Users/datnnt/Desktop/DatNNT/App/cleancut-legal/terms.html`
- Modify: `/Users/datnnt/Desktop/DatNNT/App/cleancut-legal/support.html`

Each file gets two identical edits. The line numbers below reference the current state of the files as committed at the start of the plan (privacy.html has the favicon-target line at line 8, the brand-mark line at line 15).

- [ ] **Step 2.1.1: Add favicon `<link>` to privacy.html, after the existing stylesheet link**

In `/Users/datnnt/Desktop/DatNNT/App/cleancut-legal/privacy.html`, find this line (around line 8):

```html
<link rel="stylesheet" href="style.css">
```

Insert a new line **after** it:

```html
<link rel="icon" type="image/png" href="cleancut-logo.png">
```

Result: the `<head>` block now contains both `<link>` elements back-to-back.

- [ ] **Step 2.1.2: Replace the `<span class="brand-mark">` in privacy.html**

In the same file, find the line (around line 15):

```html
      <span class="brand-mark"></span>
```

Replace with:

```html
      <img src="cleancut-logo.png" alt="CleanCut" class="brand-mark">
```

- [ ] **Step 2.1.3: Repeat 2.1.1 + 2.1.2 for terms.html**

In `/Users/datnnt/Desktop/DatNNT/App/cleancut-legal/terms.html`:
1. Add `<link rel="icon" type="image/png" href="cleancut-logo.png">` after the stylesheet link
2. Replace `<span class="brand-mark"></span>` with `<img src="cleancut-logo.png" alt="CleanCut" class="brand-mark">`

- [ ] **Step 2.1.4: Repeat 2.1.1 + 2.1.2 for support.html**

In `/Users/datnnt/Desktop/DatNNT/App/cleancut-legal/support.html`:
1. Add `<link rel="icon" type="image/png" href="cleancut-logo.png">` after the stylesheet link
2. Replace `<span class="brand-mark"></span>` with `<img src="cleancut-logo.png" alt="CleanCut" class="brand-mark">`

- [ ] **Step 2.1.5: Verify the three files using grep**

```bash
cd /Users/datnnt/Desktop/DatNNT/App/cleancut-legal
echo "--- favicon links (expect 3):" && grep -c 'rel="icon"' privacy.html terms.html support.html
echo "--- old span brand-marks (expect 0):" && grep -c 'class="brand-mark"></span>' privacy.html terms.html support.html
echo "--- new img brand-marks (expect 3):" && grep -c 'img src="cleancut-logo.png" alt="CleanCut" class="brand-mark"' privacy.html terms.html support.html
```

Expected:
- 3 `rel="icon"` matches (1 per page)
- 0 old `<span>` brand marks
- 3 new `<img>` brand marks (1 per page)

If any counts are off, the edit didn't land in one of the files — re-check that file.

- [ ] **Step 2.1.6: Visual spot-check in a browser**

```bash
open /Users/datnnt/Desktop/DatNNT/App/cleancut-legal/privacy.html
open /Users/datnnt/Desktop/DatNNT/App/cleancut-legal/terms.html
open /Users/datnnt/Desktop/DatNNT/App/cleancut-legal/support.html
```

Expected for each:
- Browser tab shows the CleanCut app icon as favicon
- Header shows the real app icon (deep navy + fire-gradient waveform) at 28×28, not an orange square
- Nav links are burnt orange on hover
- Page body still reads correctly

### Task 2.2: Commit the legal-page edits

- [ ] **Step 2.2.1: Stage and commit**

```bash
cd /Users/datnnt/Desktop/DatNNT/App/cleancut-legal && \
  git add privacy.html terms.html support.html && \
  git commit -m "$(cat <<'EOF'
feat: add favicon + real logo image to privacy/terms/support pages

Each legal page gets two minimal edits:
- New <link rel="icon"> in <head> so browser tabs show the app icon
- <span class="brand-mark"> → <img src="cleancut-logo.png">

No body-copy changes. The palette cascade from style.css already
restyled link colors; this completes the visual update for legal pages.
EOF
)" && git log --oneline -2
```

Expected: 2 commits visible (the palette one from Chunk 1 + this one).

---

## Chunk 3: index.html — header, hero, feature cards

**Why this chunk:** This is the meatiest chunk — it produces the first three sections of the new landing page (header, hero with phone-frame mockup, three feature cards). At end of chunk, the page is visibly a "real landing page" even though the bottom half (moat / pricing / FAQ / founder / footer) is still missing.

**At end of chunk:**
- `index.html` has been replaced from the top through the third feature card.
- Header, hero (with phone-frame), feature cards render correctly.
- The page below the third feature card is just the existing footer (carried forward from old index.html temporarily; Chunk 4 will move it to the bottom of the new sections).

### Task 3.1: Replace index.html with scaffold (top half)

**Files:**
- Modify (full rewrite, top half): `/Users/datnnt/Desktop/DatNNT/App/cleancut-legal/index.html`

This single step replaces the whole file but only fills in the top half — the bottom half is a TEMP placeholder that Chunk 4 replaces with the moat/pricing/FAQ/founder. This is intentional: each chunk should produce a working page (just incomplete).

- [ ] **Step 3.1.1: Replace index.html entirely with the markup below**

Overwrite `/Users/datnnt/Desktop/DatNNT/App/cleancut-legal/index.html` with this content. The phone-frame SVG markup is **lifted verbatim from `.superpowers/brainstorm/8973-1778513837/hero-with-logo.html`** (per spec §10 step 7) — if you find yourself rewriting any of the SVG bars, stop and copy from that file instead.

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>CleanCut — Cut, clean, and merge audio on your iPhone</title>
<meta name="description" content="CleanCut is an on-device audio editor for iPhone. Trim filler words, denoise background noise, and merge takes — your audio never leaves the phone.">
<link rel="stylesheet" href="style.css">
<link rel="icon" type="image/png" href="cleancut-logo.png">

<!-- Open Graph / Twitter Card meta added in Chunk 5 -->
</head>
<body>

<a class="skip-link" href="#main">Skip to content</a>

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

<main id="main">

  <!-- ======================================================== -->
  <!-- Section 2: Hero with phone-frame                          -->
  <!-- ======================================================== -->
  <section class="hero">
    <div class="hero-text">
      <div class="hero-eyebrow">A 30-min recording → 22-min edit</div>
      <h1 class="hero-headline">
        Cut filler words.<br>
        Clean noise. Merge takes.<br>
        <span class="ai-gradient-text">All on your iPhone.</span>
      </h1>
      <p class="hero-lede">An on-device audio editor for podcasters. Your audio never leaves your phone.</p>
      <a class="cta" href="#">Get on App Store →</a>
      <p class="cta-disclaimer">7-day free trial · $19.99/yr or $39.99 lifetime · App Store link goes live at launch.</p>
    </div>

    <div class="hero-phone-wrap">
      <div class="phone-frame">
        <div class="phone-notch"></div>
        <div class="phone-screen">
          <div class="phone-status">
            <span>9:41</span>
            <span>▮▮▮▯ 98%</span>
          </div>
          <div class="phone-nav">
            <span class="back">‹ Sessions</span>
            <span class="title">Smart Cut</span>
            <span class="edit">Edit</span>
          </div>

          <div class="phone-card summary">
            <div class="row">
              <span class="label">Saved</span>
              <span class="meta">in 90s</span>
            </div>
            <div class="big-num"><span class="ai-gradient-text">7:32</span></div>
            <div class="phone-chips">
              <span class="chip chip-ai">124 fillers</span>
              <span class="chip chip-action">8 pauses</span>
            </div>
          </div>

          <div class="phone-card">
            <div class="card-label">Waveform</div>
            <svg viewBox="0 0 220 50" style="width:100%;height:50px;display:block;">
              <g fill="#1C1C1E" opacity="0.85">
                <rect x="2" y="20" width="2" height="10" rx="1"/><rect x="6" y="15" width="2" height="20" rx="1"/><rect x="10" y="18" width="2" height="14" rx="1"/><rect x="14" y="10" width="2" height="30" rx="1"/><rect x="18" y="13" width="2" height="24" rx="1"/><rect x="22" y="8" width="2" height="34" rx="1"/><rect x="26" y="16" width="2" height="18" rx="1"/><rect x="30" y="22" width="2" height="6" rx="1"/><rect x="34" y="20" width="2" height="10" rx="1"/><rect x="38" y="12" width="2" height="26" rx="1"/><rect x="42" y="9" width="2" height="32" rx="1"/><rect x="46" y="15" width="2" height="20" rx="1"/><rect x="50" y="18" width="2" height="14" rx="1"/><rect x="54" y="22" width="2" height="6" rx="1"/><rect x="58" y="20" width="2" height="10" rx="1"/><rect x="62" y="14" width="2" height="22" rx="1"/><rect x="66" y="11" width="2" height="28" rx="1"/><rect x="70" y="8" width="2" height="34" rx="1"/><rect x="74" y="13" width="2" height="24" rx="1"/><rect x="78" y="16" width="2" height="18" rx="1"/><rect x="82" y="20" width="2" height="10" rx="1"/><rect x="86" y="22" width="2" height="6" rx="1"/><rect x="90" y="17" width="2" height="16" rx="1"/><rect x="94" y="12" width="2" height="26" rx="1"/><rect x="98" y="9" width="2" height="32" rx="1"/><rect x="102" y="14" width="2" height="22" rx="1"/><rect x="106" y="18" width="2" height="14" rx="1"/><rect x="110" y="21" width="2" height="8" rx="1"/><rect x="114" y="19" width="2" height="12" rx="1"/><rect x="118" y="13" width="2" height="24" rx="1"/><rect x="122" y="10" width="2" height="30" rx="1"/><rect x="126" y="15" width="2" height="20" rx="1"/><rect x="130" y="18" width="2" height="14" rx="1"/><rect x="134" y="22" width="2" height="6" rx="1"/><rect x="138" y="20" width="2" height="10" rx="1"/><rect x="142" y="12" width="2" height="26" rx="1"/><rect x="146" y="9" width="2" height="32" rx="1"/><rect x="150" y="15" width="2" height="20" rx="1"/><rect x="154" y="18" width="2" height="14" rx="1"/><rect x="158" y="22" width="2" height="6" rx="1"/><rect x="162" y="20" width="2" height="10" rx="1"/><rect x="166" y="14" width="2" height="22" rx="1"/><rect x="170" y="11" width="2" height="28" rx="1"/><rect x="174" y="8" width="2" height="34" rx="1"/><rect x="178" y="13" width="2" height="24" rx="1"/><rect x="182" y="16" width="2" height="18" rx="1"/><rect x="186" y="20" width="2" height="10" rx="1"/><rect x="190" y="22" width="2" height="6" rx="1"/><rect x="194" y="17" width="2" height="16" rx="1"/><rect x="198" y="12" width="2" height="26" rx="1"/><rect x="202" y="9" width="2" height="32" rx="1"/><rect x="206" y="14" width="2" height="22" rx="1"/><rect x="210" y="18" width="2" height="14" rx="1"/><rect x="214" y="21" width="2" height="8" rx="1"/>
              </g>
              <rect x="26" y="22" width="14" height="6" fill="#F0506E" opacity="0.85" rx="1"/>
              <rect x="78" y="22" width="16" height="6" fill="#F0506E" opacity="0.85" rx="1"/>
              <rect x="130" y="22" width="12" height="6" fill="#F0506E" opacity="0.85" rx="1"/>
              <rect x="178" y="22" width="16" height="6" fill="#F0506E" opacity="0.85" rx="1"/>
              <rect x="55" y="20" width="10" height="10" fill="#EA580C" opacity="0.25" rx="1"/>
              <rect x="160" y="20" width="10" height="10" fill="#EA580C" opacity="0.25" rx="1"/>
            </svg>
          </div>

          <div class="phone-card category">
            <div>
              <div class="cat-title">Hesitations</div>
              <div class="cat-sub">um, uh, ah · 47 found</div>
            </div>
            <div class="toggle"></div>
          </div>

          <div class="phone-cta ai-gradient-bg">Apply Cuts</div>
        </div>
      </div>
    </div>
  </section>

  <!-- ======================================================== -->
  <!-- Section 3: Three feature cards                            -->
  <!-- ======================================================== -->
  <h2>Three tools, one phone.</h2>
  <div class="cards">
    <div class="card">
      <h3>Smart Cut</h3>
      <p>Auto-detect filler words ("um," "uh," "like"), long silences, and dead air. Every cut shows on a waveform timeline before export — nothing is removed without your review.</p>
      <p>Auto-transcript export to .txt, .srt, or .vtt. Per-session language picker. iOS 26: long-form streaming via Apple's SpeechAnalyzer with a live transcript pane during analysis.</p>
    </div>
    <div class="card">
      <h3>Denoise</h3>
      <p>DeepFilterNet3 on iPhone — a neural network built for speech. Intensity slider to taste the result, A/B toggle to hear exactly what changed. Works on subway commutes, busy cafés, humming offices.</p>
    </div>
    <div class="card">
      <h3>Merge</h3>
      <p>Drag clips onto a timeline, set crossfades, export as M4A or WAV. Loudness auto-normalized to broadcast standard (BS.1770 LUFS) — volume jumps between clips disappear.</p>
    </div>
  </div>

  <!-- ======================================================== -->
  <!-- TEMP PLACEHOLDER — Chunk 4 replaces this with             -->
  <!-- moat / pricing / FAQ / founder sections                   -->
  <!-- ======================================================== -->
  <p style="color:#9a9aa3; text-align:center; padding:40px 0;"><em>(More sections coming in Chunk 4.)</em></p>

</main>

<footer class="site">
  <p>&copy; 2026 CleanCut · <a href="privacy.html">Privacy</a> · <a href="terms.html">Terms</a> · <a href="support.html">Support</a></p>
</footer>

</body>
</html>
```

- [ ] **Step 3.1.2: Visual check**

```bash
open /Users/datnnt/Desktop/DatNNT/App/cleancut-legal/index.html
```

Verify (top to bottom):
1. **Browser tab** — favicon shows the CleanCut app icon
2. **Header** — real logo (28×28, deep-navy + fire-gradient waveform), "CleanCut" wordmark, nav links right-aligned
3. **Hero text (left column on desktop)**:
   - Eyebrow "A 30-MIN RECORDING → 22-MIN EDIT" in burnt orange uppercase, letter-spaced
   - Three-line headline; "All on your iPhone." has a fire-gradient text accent
   - Lede paragraph in soft gray
   - Burnt-orange pill CTA "Get on App Store →" with a drop shadow
   - Sub-CTA line in dim gray
4. **Phone-frame (right column on desktop)**:
   - Deep-navy frame with rounded corners
   - Notch at top center
   - Status bar "9:41 · ▮▮▮▯ 98%"
   - "Smart Cut" nav title with burnt-orange "‹ Sessions" and "Edit"
   - Summary card with "Saved · in 90s" eyebrow + big fire-gradient "7:32" + two chips
   - Waveform card with vertical bars + magenta strikethrough overlays + orange pause regions
   - Hesitations category row with active toggle
   - Fire-gradient "Apply Cuts" pill at the bottom
5. **Feature cards** — three cards in a row (desktop), each with a fire-gradient top stripe and the right body copy
6. **Placeholder** — gray italic line "(More sections coming in Chunk 4.)"
7. **Footer** — copyright + 3 legal links

On mobile (resize browser narrower than 720px), the hero stacks vertical (text on top, phone below), feature cards stack to single column. Verify both.

- [ ] **Step 3.1.3: Sanity-check that the file isn't corrupt**

```bash
wc -l /Users/datnnt/Desktop/DatNNT/App/cleancut-legal/index.html
```

Expected: ~130 lines.

### Task 3.2: Commit Chunk 3

- [ ] **Step 3.2.1: Stage and commit**

```bash
cd /Users/datnnt/Desktop/DatNNT/App/cleancut-legal && \
  git add index.html && \
  git commit -m "$(cat <<'EOF'
feat: new index.html — header, hero with phone-frame, feature cards

Replaces the minimal "About" index.html with the first half of the new
landing page. Sections added:

- Sticky header with the real app icon and skip-to-content link
- Hero (two-column on desktop, stacked on mobile):
  - "A 30-min recording → 22-min edit" eyebrow
  - Three-line headline with fire-gradient "All on your iPhone." accent
  - Burnt-orange App Store CTA + 7-day-trial disclaimer
  - Right column: pure CSS/SVG phone-frame mockup of the Smart Cut
    results state (waveform with magenta filler strikethroughs + orange
    pause regions, summary card, Apply Cuts CTA)
- Three feature cards (Smart Cut, Denoise, Merge) with fire-gradient
  top stripes

Bottom-half sections (moat, pricing, FAQ, founder) shipped in the next
commit. Page renders correctly end-to-end; only the bottom half is a
temporary placeholder.
EOF
)" && git log --oneline -3
```

Expected: 3 commits visible (palette + logo + this).

---

## Chunk 4: index.html — privacy moat, pricing, FAQ, founder note

**Why this chunk:** Replaces the temporary placeholder from Chunk 3 with the four bottom-half sections. At end of chunk, the page is structurally complete.

**At end of chunk:**
- Privacy-moat dark-strip section with the "no comparable tool" paragraph.
- 4-card pricing grid (Free / Monthly / Yearly highlighted with BEST VALUE / Lifetime).
- FAQ with 6 `<details>` items.
- Founder note section with mailto link.
- The page renders end-to-end, no placeholders.

### Task 4.1: Replace the placeholder with the four new sections

**Files:**
- Modify: `/Users/datnnt/Desktop/DatNNT/App/cleancut-legal/index.html` — replace the placeholder paragraph from Chunk 3.

- [ ] **Step 4.1.1: Replace the placeholder paragraph**

In `/Users/datnnt/Desktop/DatNNT/App/cleancut-legal/index.html`, find this block (added in Chunk 3):

```html
  <!-- ======================================================== -->
  <!-- TEMP PLACEHOLDER — Chunk 4 replaces this with             -->
  <!-- moat / pricing / FAQ / founder sections                   -->
  <!-- ======================================================== -->
  <p style="color:#9a9aa3; text-align:center; padding:40px 0;"><em>(More sections coming in Chunk 4.)</em></p>
```

Replace the entire block (all 5 lines, the four `<!-- -->` lines plus the `<p>`) with the markup below:

```html
  <!-- ======================================================== -->
  <!-- Section 4: Privacy moat (dark strip)                      -->
  <!-- ======================================================== -->
  <section class="moat">
    <div class="moat-eyebrow">On-device. Always.</div>
    <h2>Your voice. Your iPhone. No cloud.</h2>
    <p><em>Every comparable tool uploads your audio to a server.</em> Descript, Riverside, Cleanvoice, Adobe Podcast — all of them ship your voice to a data center, run AI on it, and ship the result back. That's how it's been because the models were too big to run on a phone.</p>
    <p>CleanCut runs entirely on your iPhone. The transcription model is Apple's on-device SpeechAnalyzer (or SFSpeechRecognizer on iOS 17–25). The denoise model is DeepFilterNet3, a small neural network built for embedded inference. The merge timeline is AVFoundation. No analytics SDK, no third-party tracker, no account. Turn on airplane mode — CleanCut still works.</p>
    <p>That's not a marketing claim we can hide behind. It's a structural property: <em>there's no server to send it to.</em></p>
  </section>

  <!-- ======================================================== -->
  <!-- Section 5: Pricing (4-card grid)                          -->
  <!-- ======================================================== -->
  <h2>Pricing</h2>
  <div class="pricing">

    <div class="tier-card">
      <div class="tier-label">Free</div>
      <div class="tier-price">$0</div>
      <div class="tier-period">free forever</div>
      <ul>
        <li>3 Smart Cut sessions / day</li>
        <li>3 Denoise sessions / day</li>
        <li>Files ≤ 5 min (Smart Cut) or 3 min (Denoise)</li>
        <li>Unlimited Merge, up to 3 clips</li>
        <li>WAV export</li>
      </ul>
      <a class="cta-ghost" href="#">Download →</a>
    </div>

    <div class="tier-card">
      <div class="tier-label">Pro Monthly</div>
      <div class="tier-price">$3.99</div>
      <div class="tier-period">per month · 7-day free trial</div>
      <ul>
        <li>Everything in Free, unlimited</li>
        <li>Export to M4A, MP3, WAV</li>
        <li>No watermark</li>
        <li>Custom filler libraries</li>
        <li>Background processing</li>
      </ul>
      <a class="cta" href="#">Start trial</a>
    </div>

    <div class="tier-card highlighted">
      <div class="ribbon">Best Value</div>
      <div class="tier-label">Pro Yearly</div>
      <div class="tier-price">$19.99</div>
      <div class="tier-period">per year · save 58% · 7-day free trial</div>
      <ul>
        <li>Everything in Free, unlimited</li>
        <li>Export to M4A, MP3, WAV</li>
        <li>No watermark</li>
        <li>Custom filler libraries</li>
        <li>Background processing</li>
      </ul>
      <a class="cta" href="#">Start trial</a>
    </div>

    <div class="tier-card">
      <div class="tier-label">Lifetime</div>
      <div class="tier-price">$39.99</div>
      <div class="tier-period">once · no subscription</div>
      <ul>
        <li>Everything in Pro, forever</li>
        <li>One-time purchase</li>
        <li>Never billed again</li>
        <li>Same features as Pro Yearly</li>
      </ul>
      <a class="cta" href="#">Buy Lifetime</a>
    </div>

  </div>
  <p class="cta-disclaimer" style="text-align:center; margin-top:8px;">App Store links go live at launch. Restore Purchases lives in Settings → Subscription. Cancel anytime.</p>

  <!-- ======================================================== -->
  <!-- Section 6: FAQ                                            -->
  <!-- ======================================================== -->
  <h2>FAQ</h2>
  <div class="faq">
    <details>
      <summary>Does Smart Cut work without internet?</summary>
      <p>Yes. Both Smart Cut (transcription) and Denoise run on-device. You can put your phone in airplane mode and CleanCut works.</p>
    </details>
    <details>
      <summary>Which languages does Smart Cut support?</summary>
      <p>Whatever your iPhone's Speech framework supports — typically English, Spanish, Portuguese, French, German, Italian, Japanese, Korean, Chinese, and ~20 more. You pick a language per session. No bilingual auto-detect at launch (single language per recording).</p>
    </details>
    <details>
      <summary>How does the iOS 26 version differ from iOS 17?</summary>
      <p>iOS 26 uses Apple's new SpeechAnalyzer for long-form streaming with a live transcript pane that updates as the analysis runs. iOS 17–25 uses SFSpeechRecognizer in 30-second chunks — same accuracy, just shown as a progress bar instead of streaming text.</p>
    </details>
    <details>
      <summary>How long does a recording take to process?</summary>
      <p>Roughly 2.5× faster than real time on iPhone 15 Pro and newer. A 30-minute recording takes ~12 minutes of foreground processing, or you can hit "Run in BG" and lock your phone.</p>
    </details>
    <details>
      <summary>Why is the free tier limited?</summary>
      <p>The free tier covers a daily voice memo (3 Smart Cut + 3 Denoise sessions a day, ≤5 min each). Beyond that, the on-device models use real CPU/battery, so the economics need to net out. Pro is the unlock for unlimited processing.</p>
    </details>
    <details>
      <summary>Is there a Mac version?</summary>
      <p>Not at launch. The on-device models are tuned for iPhone first. macOS Catalyst is on the roadmap but not v1.x.</p>
    </details>
  </div>

  <!-- ======================================================== -->
  <!-- Section 7: Founder note                                   -->
  <!-- ======================================================== -->
  <div class="founder">
    <p>Hi, I'm Đạt. I built CleanCut because I record voice notes constantly — drafts, demos, talking-to-myself thinking sessions — and I wanted to clean them up without uploading them anywhere.</p>
    <p>Every audio tool I tried sent my audio to a server. Some had decent privacy policies. None of them were as good as "the audio just never leaves your phone." So I built that.</p>
    <p>Smart Cut runs on Apple's SpeechAnalyzer (iOS 26) and SFSpeechRecognizer (iOS 17–25). Denoise uses DeepFilterNet3, a 1.7M-parameter neural network compiled to Core ML. Merge is straight AVFoundation. No backend. No analytics. Three tools, on the phone.</p>
    <p>Free tier is generous (3 sessions a day forever — enough for a daily voice memo). Pro is $3.99/mo or $19.99/yr if you want it unlimited; one-time $39.99 if you hate subscriptions (I do too).</p>
    <p>Feedback welcome — <a href="mailto:support@cleancut.app">support@cleancut.app</a>.</p>
  </div>
```

- [ ] **Step 4.1.2: Verify the placeholder is gone**

```bash
grep -c "More sections coming in Chunk 4" /Users/datnnt/Desktop/DatNNT/App/cleancut-legal/index.html
```

Expected: `0`. If `1`, the replace didn't land.

- [ ] **Step 4.1.3: Verify the new sections are present**

```bash
cd /Users/datnnt/Desktop/DatNNT/App/cleancut-legal
grep -c "On-device. Always." index.html       # moat eyebrow
grep -c "Best Value" index.html                # ribbon
grep -c "Does Smart Cut work without internet" index.html  # first FAQ
grep -c "I'm Đạt" index.html                  # founder note
```

Expected: each command outputs `1`.

- [ ] **Step 4.1.4: Visual check**

```bash
open /Users/datnnt/Desktop/DatNNT/App/cleancut-legal/index.html
```

Verify the four new sections:
1. **Privacy moat**: dark navy gradient strip, magenta "ON-DEVICE. ALWAYS." eyebrow, white H2 "Your voice. Your iPhone. No cloud.", three paragraphs of body copy with white-at-86%-opacity color
2. **Pricing**: four cards in a row on wide screens (wraps to 2 columns at 540px, 1 column below). The Yearly card has a 2px burnt-orange border and a "BEST VALUE" ribbon at top-right. Each card has price, period, bullets, CTA at the bottom.
3. **FAQ**: 6 collapsible items. Click each `<summary>` to confirm the `+` rotates to `×` and the answer paragraph appears.
4. **Founder note**: white card with 1px border, 5 short paragraphs, mailto link at the end.
5. **Footer**: unchanged from Chunk 3.

### Task 4.2: Commit Chunk 4

- [ ] **Step 4.2.1: Stage and commit**

```bash
cd /Users/datnnt/Desktop/DatNNT/App/cleancut-legal && \
  git add index.html && \
  git commit -m "$(cat <<'EOF'
feat: index.html bottom half — moat, pricing, FAQ, founder note

Replaces the Chunk-3 placeholder with the four bottom-half sections:

- Privacy moat (dark navy gradient strip): the "every comparable tool
  uploads your audio" paragraph that journalists / Product-Hunt voters
  can lift verbatim
- Pricing: 4-card grid (Free / Pro Monthly / Pro Yearly highlighted
  with BEST VALUE ribbon / Lifetime) with $3.99 / $19.99 / $39.99
- FAQ: 6 collapsible <details> items (no JavaScript)
- Founder note: 5 short paragraphs + mailto:support@cleancut.app

Page now reads end-to-end. Chunk 5 adds the OG/Twitter meta + final
Lighthouse pass and pushes to GitHub Pages.
EOF
)" && git log --oneline -4
```

Expected: 4 commits visible.

---

## Chunk 5: OG/Twitter meta + Lighthouse pass + push

**Why this chunk:** The page works; this chunk adds social-preview metadata for shares (Twitter / LinkedIn / Slack / WhatsApp / etc.), runs a Lighthouse audit to confirm the 100/100/100/100 target, fixes anything Lighthouse flags, and pushes the four commits to GitHub Pages.

**At end of chunk:**
- `<head>` has Open Graph + Twitter Card meta tags pointing at the logo.
- Lighthouse score is 100/100/100/100 on `index.html`.
- All four commits are pushed to `origin/main` on the `clearcut-legal` GitHub repo.
- The live URL (`https://datnntqn.github.io/clearcut-legal/`) reflects the changes within ~2 minutes (GitHub Pages publish lag).

### Task 5.1: Add Open Graph + Twitter Card meta tags

**Files:**
- Modify: `/Users/datnnt/Desktop/DatNNT/App/cleancut-legal/index.html` — add meta tags in `<head>`.

- [ ] **Step 5.1.1: Add OG + Twitter meta tags**

In `/Users/datnnt/Desktop/DatNNT/App/cleancut-legal/index.html`, find this line in `<head>`:

```html
<!-- Open Graph / Twitter Card meta added in Chunk 5 -->
```

Replace that single comment line with:

```html
<!-- Open Graph -->
<meta property="og:type" content="website">
<meta property="og:title" content="CleanCut — Cut, clean, and merge audio on your iPhone">
<meta property="og:description" content="CleanCut is an on-device audio editor for iPhone. Trim filler words, denoise background noise, and merge takes — your audio never leaves the phone.">
<meta property="og:image" content="https://datnntqn.github.io/clearcut-legal/cleancut-logo.png">
<meta property="og:url" content="https://datnntqn.github.io/clearcut-legal/">

<!-- Twitter Card -->
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="CleanCut — Cut, clean, and merge audio on your iPhone">
<meta name="twitter:description" content="CleanCut is an on-device audio editor for iPhone. Trim filler words, denoise background noise, and merge takes — your audio never leaves the phone.">
<meta name="twitter:image" content="https://datnntqn.github.io/clearcut-legal/cleancut-logo.png">
```

> **OQ-1 reminder (Spec §11):** the URL above uses `clearcut-legal` (the actual GitHub repo name with the typo). If you decide to rename the repo to `cleancut-legal` before launch (recommended per the spec), update these two `og:image` / `og:url` / `twitter:image` URLs accordingly. The rename happens in GitHub's repo settings; the URLs propagate immediately to GitHub Pages.

- [ ] **Step 5.1.2: Verify**

```bash
grep -c "og:title\|twitter:card" /Users/datnnt/Desktop/DatNNT/App/cleancut-legal/index.html
```

Expected: `2` (one og:title, one twitter:card).

### Task 5.2: Run Lighthouse and fix any sub-100 metrics

**Files:** depends on what Lighthouse flags.

- [ ] **Step 5.2.1: Run Lighthouse against the local file**

Open Chrome (or any Chromium-based browser, including Edge / Brave) and load `file:///Users/datnnt/Desktop/DatNNT/App/cleancut-legal/index.html`. Then:

1. Right-click → Inspect → Lighthouse tab
2. Categories: check all four (Performance / Accessibility / Best Practices / SEO)
3. Mode: **Navigation (Default)**
4. Device: **Desktop**
5. Click "Analyze page load"

Wait ~30 seconds for the audit.

Expected: 100 / 100 / 100 / 100. If any score is below 100, Lighthouse explains why. Common issues to anticipate + fix:

- **Accessibility < 100 — "Background and foreground colors do not have a sufficient contrast ratio"**: re-check white-on-burnt-orange CTAs. Bold weight on the CTA text is already in the spec. If still flagged, increase font weight from 600 to 700.
- **Best Practices < 100 — "Image elements do not have explicit width and height"**: add `width="28" height="28"` to the four `<img class="brand-mark">` tags across `index.html` + the three legal pages.
- **SEO < 100 — "Links do not have descriptive text"**: the `href="#"` CTAs may be flagged. This is acceptable pre-launch (we have the disclaimer); if Lighthouse insists, switch the CTA text from "Get on App Store →" to "Get CleanCut on the App Store →" (more descriptive).
- **Performance < 100**: extremely unlikely on a static HTML file with one 14 KB image. If flagged, check the Network tab for any large transfers — there shouldn't be any.

- [ ] **Step 5.2.2: If any score < 100, fix in place and re-run Lighthouse**

Repeat 5.2.1 until 100/100/100/100. If a metric won't budge despite reasonable fixes, document the trade-off in the commit message and accept it (with explicit reason).

- [ ] **Step 5.2.3: Run a quick mobile Lighthouse pass too**

Same as 5.2.1 but Device = **Mobile**. Expected: 100/100/100/100 (mobile is the dominant audience).

### Task 5.3: Final cross-page contrast spot-check

**Files:** none — verification only.

- [ ] **Step 5.3.1: Manual contrast check on the burnt-orange CTA**

Open https://webaim.org/resources/contrastchecker/ in a browser.

- Foreground: `#FFFFFF`
- Background: `#EA580C`

Expected:
- **Normal text**: Ratio ~4.4 — **AA Large only** (passes for 18pt+ or 14pt+ bold)
- **Large text**: Pass

Since the CTA uses `font-weight: 600` and 14px text, it qualifies as "large text" by WCAG's large-text definition (14pt+ bold = 18.66px+ bold). Confirmed PASS.

If you upgraded font-weight to 700 in Step 5.2.2, this is even safer.

### Task 5.4: Push to GitHub Pages

**Files:** none — git operation only.

- [ ] **Step 5.4.1: Commit any Lighthouse-driven fixes**

If you made fixes in 5.2.2, stage and commit them:

```bash
cd /Users/datnnt/Desktop/DatNNT/App/cleancut-legal && \
  git status
```

If `git status` shows changes, commit them with a descriptive message. Use an explicit file list (no `git add .` — only the four HTML files + `style.css` could possibly have changed):

```bash
cd /Users/datnnt/Desktop/DatNNT/App/cleancut-legal && \
  git add index.html privacy.html terms.html support.html style.css && \
  git commit -m "fix: lighthouse-driven accessibility / SEO tweaks for 100 score"
```

Otherwise (Lighthouse passed cleanly), skip this step.

- [ ] **Step 5.4.2: Stage the OG/Twitter meta commit**

```bash
cd /Users/datnnt/Desktop/DatNNT/App/cleancut-legal && \
  git add index.html && \
  git diff --cached --stat
```

Expected: `index.html | 12 ++++++++++++` (or similar — about 12 added lines).

- [ ] **Step 5.4.3: Commit the OG/Twitter meta**

```bash
cd /Users/datnnt/Desktop/DatNNT/App/cleancut-legal && git commit -m "$(cat <<'EOF'
feat: Open Graph + Twitter Card meta for social previews

When the URL is shared on Twitter / LinkedIn / Slack / WhatsApp etc., the
preview now shows the CleanCut app icon, title, and description instead of
a bare URL. Square (summary) Twitter card is intentional — we ship the
square app icon, not a 1200×630 marketing banner. Pre-launch trade-off
acceptable; replace with a proper og:image banner post-launch.
EOF
)" && git log --oneline -6
```

Expected: 5+ commits visible (palette + legal-pages + index-top + index-bottom + meta + optional Lighthouse-fix).

- [ ] **Step 5.4.4: Push to GitHub Pages**

```bash
cd /Users/datnnt/Desktop/DatNNT/App/cleancut-legal && \
  git push origin main 2>&1 | tail -5
```

Expected: `main -> main` line near the bottom, no errors.

- [ ] **Step 5.4.5: Wait 2 minutes, then verify the live site**

```bash
# Quick verification that the site is reachable
curl -sI https://datnntqn.github.io/clearcut-legal/ | head -3
```

Expected: `HTTP/2 200` (or HTTP/1.1 200). If you get 404, GitHub Pages is still publishing — wait another minute and retry.

```bash
# Open the live site in a browser to confirm
open https://datnntqn.github.io/clearcut-legal/
```

Expected: the full new landing page renders identically to the local version.

### Task 5.5: Verify the legal pages are also live

**Files:** none — verification only.

- [ ] **Step 5.5.1: Open each legal page on the live site**

```bash
open https://datnntqn.github.io/clearcut-legal/privacy.html
open https://datnntqn.github.io/clearcut-legal/terms.html
open https://datnntqn.github.io/clearcut-legal/support.html
```

Each should: (a) show the app icon as favicon, (b) show the real logo in the header, (c) have burnt-orange link colors. If any page shows the old indigo or a broken header, the push failed for that file — check `git log` and re-push.

- [ ] **Step 5.5.2: Implementation complete**

If the live URL renders correctly, the four commits have pushed, and Lighthouse passed 100/100/100/100, the implementation is complete.

**Post-implementation reminders** (not part of the plan, for the human reviewer):

1. **OQ-1**: GitHub repo is still named `clearcut-legal`. Rename to `cleancut-legal` in GitHub settings before locking the App Store Connect Privacy Policy URL. Update the four OG/Twitter URLs accordingly.
2. **OQ-2**: Re-test the 720px mobile breakpoint on a real device. If the phone-frame crowds the text column at exactly 720px, bump the breakpoint to 760px in `style.css` (the `.hero { grid-template-columns: ... }` rule and the `.cards { grid-template-columns: ... }` rule both have a `@media (min-width: 720px)` line).
3. **Future enhancement**: when a real Smart Cut screenshot exists, swap the `<svg>` + `<div>` phone-screen contents in `index.html` for `<img src="hero-screenshot.png" alt="Smart Cut results...">` at 720×1530 px (3× retina for the 240×510 inner screen).
4. **Post-launch OG image**: ship a 1200×630 marketing banner as a separate `og-banner.png` and update the OG/Twitter `image` URLs. Square app icon will continue to be the favicon.