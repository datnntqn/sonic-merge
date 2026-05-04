# CleanCut Rebrand — Manual QA Checklist

**Build:** local debug, iPhone 17 simulator (iOS 17 floor; verify on iOS 18 sim too if convenient).
**Reset before testing:** delete the app from the simulator Home screen so iOS clears its app-icon cache.

## App icon
- [ ] After fresh install, Home screen shows the new icon: deep navy canvas with 8 fire-gradient bars + diagonal white slash. Not the generic `sparkles` placeholder.
- [ ] Toggle simulator appearance light → dark. Icon variant changes per Contents.json (currently same canvas in both, per spec D-03).
- [ ] iOS 18+ tinted variant: long-press a Home empty area → Edit Home Screen → tinted appearance. Icon should auto-tint to a single-color version of the glyph.

## Tab bar
- [ ] Smart Cut tab (leftmost): shows the fire-gradient glyph, NOT a flat-tinted symbol.
- [ ] Selected vs. unselected state: the glyph stays full-color in both (intentional — see spec D-06 visual asymmetry note).
- [ ] Denoise + Merge tabs: their SF Symbols template-tint with the new violet `accentAction` color when selected, gray when unselected.

## Smart Cut tab
- [ ] Empty state: hero badge shows fire-tinted squircle with the gradient glyph.
- [ ] Import a clip → idle state shows orb with the gradient glyph + gentle scale-pulse.
- [ ] Tap Analyze → analyzing state still shows the orb pulsing.
- [ ] Results state → "Apply Cuts" floating CTA: gradient glyph + label, fire-gradient capsule background.
- [ ] Studio's idle Analyze button: gradient glyph + "Analyze ~N min" label, flat magenta capsule.

## Denoise + Merge tabs
- [ ] Visual unchanged except for color swap: surfaces/cards/text follow the new dark-navy in dark mode and unchanged light mode.
- [ ] Theme toggle in toolbar still works in both directions, both tabs.

## Onboarding (re-trigger by deleting app and reinstalling, or by setting hasOnboarded=false in defaults)
- [ ] Step 1 BrandOpener: hero badge shows fire-tinted squircle + gradient glyph + scale-bounce on appear.
- [ ] Step 1 feature pills: Smart Cut pill has white-glyph-on-magenta; Denoise pill has white SF Symbol on magenta; Merge pill has white SF Symbol on violet.
- [ ] "Smart Cut This Sample" CTA in onboarding step 4 (or wherever the sample lives): full fire-gradient capsule fill + white glyph + label.
- [ ] Onboarding ProgressView tints (Analyzing… / Applying cuts…) read as flat magenta — no gradient (`.tint()` cannot take a gradient — confirm visual is acceptable).
- [ ] Sample-podcast result-summary chip background: flat magenta.

## Theme toggle
- [ ] Light → dark transition: surfaces fade from #FBFBFC to #0A0A18; violet `accentAction` (selected tab indicator, primary CTAs) reads well on both surfaces; magenta `accentAI` reads well on both surfaces.
- [ ] No two-source-of-truth bug: tab bar appearance flips alongside chrome (per RootTabView's environment+preferredColorScheme injection).

## Regression spot-checks
- [ ] Full test suite still reports `FAIL=5` baseline (the same names listed in CLAUDE.md). No new failures.
- [ ] Smart Cut analyze pipeline still works end-to-end on a real audio sample.
- [ ] Denoise tab still produces a clean output on a noisy sample.
- [ ] Merge tab still combines two clips.

## Known intentional visual changes (NOT bugs)
- App icon is the same dark canvas in light/dark/tinted appearance (spec D-03).
- Smart Cut tab icon doesn't dim when unselected (spec D-06).
- Waveform mesh-gradient end-stop changed from system purple to violet (spec non-goal §2 phrasing).
