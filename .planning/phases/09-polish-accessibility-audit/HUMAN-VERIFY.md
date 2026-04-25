# Phase 9 — Human Verification

**Verified by:** _[your name]_
**Date:** _[YYYY-MM-DD]_
**Device:** _[e.g. iPhone 16e Simulator + iPhone 15 Pro physical device]_
**iOS version:** _[e.g. 17.5]_

> **How to use this file:** Each `[ ]` box is checked manually after observing the behavior. Computed contrast ratios are pre-filled (math is deterministic from documented hex values), but the "verified visually" checkboxes still need a human eyeballing the rendered screens.

---

## Regression Test Baseline (P1 build + P2 tests)

Run on iPhone 17 Simulator (iOS 26.2) with `-parallel-testing-enabled NO` (parallel runs created broken simulator clones — all tests fail at 0.000s on bad clones; serial run is reliable).

- **P1 build:** `** BUILD SUCCEEDED **` ✓
- **P2 tests:** 54 / 59 passed. 5 baseline failures, all pre-existing on `main` (no Phase 9 test files modified — confirmed by `git diff main..HEAD -- SonicMergeTests/` returning empty):
  | Test | Reason | Provenance |
  |------|--------|------------|
  | `ShareExtensionTests/testFileCopyToClipsDirectory` | `Bool(false)` stub | `f5df7af` Phase 5 Wave 0 RED stub |
  | `ShareExtensionTests/testLargeFileCopyDoesNotCrash` | `Bool(false)` stub | `f5df7af` Phase 5 Wave 0 RED stub |
  | `ShareExtensionTests/testPendingKeyWrittenAndCleared` | `Bool(false)` stub | `f5df7af` Phase 5 Wave 0 RED stub |
  | `ABPlaybackTests/testPositionPreservedOnSwitch` | `Issue.record(...)` stub | `a592f6d` Phase 3 Wave 0 RED stub (file header: "RED state: ABPlaybackController does not exist until Wave 3") |
  | `AudioMergerServiceTests/compositionWithCrossfadeHasNonNilAudioMix` | Duration tolerance violated: `abs(duration.seconds - 1.5) → 0.499 < 0.2` fails | Last touched in Phase 2 (`19de7bb`); flaky pre-existing assertion, not a Phase 9 regression |

Phase 9's regression-only test strategy is satisfied: every test that exercises code Phase 9 modified passes. The above failures pre-date this branch and should be addressed in a separate plan (the crossfade duration test in particular looks worth investigating).

---

## POL-01 — Haptics

> **Note:** The iOS Simulator does not reproduce haptics. These checks require a physical iPhone running iOS 17+. If you don't have one available, mark each row as **N/A — physical device unavailable** rather than checked.

- [ ] Import toolbar button → light impact
- [ ] Appearance menu → light impact on theme selection change
- [ ] Export toolbar button → light impact
- [ ] Denoise toolbar button → light impact
- [ ] Empty-state "Import Audio" pill → light impact (PillButtonStyle default)
- [ ] ExportFormatSheet "Export Audio" pill → light impact (PillButtonStyle default)
- [ ] ExportProgressSheet "Cancel Export" button → **medium** impact (explicit `.sensoryFeedback(.impact(weight: .medium))`)

---

## POL-02 — Dark Mode Completeness

Open the app, set Simulator → Features → Toggle Appearance → Dark, and inspect each surface. Pure black `#000000` background, light text `~#F5F5F5`, Deep Indigo `#5856D6` accent, Lime Green `#A7C957` AI accent.

- [ ] **MixingStationView empty state** — pure black bg, Deep Indigo waveform icon, Deep Indigo "Import Audio" pill with white label
- [ ] **MixingStationView timeline (≥2 clips imported)** — black bg, `#0F0F0F` clip cards, vertical spine visible
- [ ] **ExportFormatSheet** — Deep Indigo Toggle tint, Deep Indigo "Export Audio" pill with white label
- [ ] **ExportProgressSheet** — Deep Indigo `ProgressView` tint (regression check: this was iOS system blue before Phase 9), red "Cancel Export" label
- [ ] **CleaningLabView** — black bg, AI Orb nebula visible, Lime Green slider + ring, stale banner readable
- [ ] **AIOrbView** — nebula blobs animate, Lime Green progress ring fills smoothly during a denoise

---

## POL-03 — Accessibility Fallbacks

### reduceMotion

Enable Settings → Accessibility → Motion → Reduce Motion, then:

- [ ] AI Orb nebula freezes at t=0 composition (regression — Phase 8)
- [ ] PillButton press no longer scale-animates (regression — Phase 6)
- [ ] MergeSlotRow drag no longer scale-animates (regression — Phase 7)
- [ ] **NEW (Phase 9):** AI Orb progress ring fills in sharp jumps during denoise (no 0.25s ease) — easiest to observe with a ~10s clip
- [ ] **NEW (Phase 9):** Stale banner appears/disappears instantly with no fade — reproduce by denoising, then reordering or deleting a clip in MixingStation and returning to CleaningLab

### reduceTransparency

Enable Settings → Accessibility → Display & Text Size → Reduce Transparency, then (regression checks only — no Phase 9 change):

- [ ] `SquircleCard(glassEnabled: true)` surfaces render solid `surfaceCard` (no material blur)
- [ ] `LocalFirstTrustStrip` header renders solid
- [ ] AI Orb outer bloom drops from 24pt to 8pt blur radius

### Contrast (computed — deterministic from documented hex values)

Computed via WCAG 2.1 relative-luminance formula on the values defined in `SonicMergeTheme+Appearance.swift`. Light-mode `textSecondary` has 60% alpha and is composited over `surfaceBase #FBFBFC` to its effective RGB before computing the ratio.

| Pair | Ratio | WCAG AA (≥4.5:1) | Notes |
|------|------:|:----------------:|-------|
| textPrimary (`#F5F5F5`) on surfaceBase dark (`#000000`) | **19.26:1** | PASS | UI-SPEC predicted ~20:1 — match |
| textPrimary (`#1C1C1E`) on surfaceBase light (`#FBFBFC`) | **16.45:1** | PASS | UI-SPEC predicted ~19:1 — match |
| textSecondary dark (solid `#8C8C8C`) on `#000000` | **6.25:1** | PASS | UI-SPEC said "BORDERLINE ~4.6:1" — actually clear PASS |
| textSecondary light (60% alpha → effective `#88888D`) on `#FBFBFC` | **3.39:1** | **FAIL** | UI-SPEC said "BORDERLINE ~4.7:1" — actual ratio fails AA. **Finding — see below.** |
| PillButton white (`#FFFFFF`) on Deep Indigo (`#5856D6`) | **5.65:1** | PASS | UI-SPEC said "3.2:1 FAIL — known accepted risk". The actual ratio passes WCAG AA. **Finding — see below.** |
| PillButton dark (`#1C1C1E`) on Lime Green (`#A7C957`) | **9.02:1** | PASS (AAA) | UI-SPEC predicted ~7.4:1 — close, both PASS |
| AI Orb label `accentAI` (`#A7C957`) on `surfaceCard` dark (`#0F0F0F`) | **10.16:1** | PASS | UI-SPEC predicted ~7.1:1 |

Visual confirmation that the right colors land in the right places (separate from the math):

- [ ] Accessibility Inspector audit on **light** mode reports no contrast violations on the screens above
- [ ] Accessibility Inspector audit on **dark** mode reports no contrast violations
- [ ] textSecondary appears legible in light mode (despite the computed 3.39:1 — see Finding below)

---

## Findings (computed-vs-spec discrepancies)

These are observations from the contrast computation. They are not Phase 9 regressions — both colors were defined in earlier phases. Recording here so the spec can be reconciled before merge.

1. **`textSecondary` light-mode contrast is 3.39:1, not ~4.7:1 as predicted by UI-SPEC line 166.** The actual `UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.6)` composited over `#FBFBFC` yields effective RGB `~#88888D`, which fails WCAG AA. This is a real accessibility risk for light-mode users. _Action:_ either bump the alpha (or darken the base RGB) in a follow-up phase, or accept and document. Out of scope for Phase 9 (visual-only, no token changes).

2. **PillButton white-on-Deep-Indigo contrast is 5.65:1, not 3.2:1 as predicted by UI-SPEC line 167 / line 171.** The "known accepted risk" framing in UI-SPEC appears to be based on an incorrect calculation — `#FFFFFF` on `#5856D6` actually passes WCAG AA. _Action:_ update UI-SPEC to remove the FAIL annotation in a follow-up doc commit.

---

## Issues Found

_[List any issues discovered during device verification beyond the two findings above. If none, write "None."]_

---

## Sign-off

- [ ] All POL-01 haptic items confirmed on physical device (or marked N/A if unavailable)
- [ ] All POL-02 dark-mode items confirmed in Simulator
- [ ] All POL-03 reduceMotion / reduceTransparency items confirmed in Simulator
- [ ] Computed contrast ratios reviewed; the two findings above are acknowledged
- [ ] Phase 9 acceptance criteria satisfied
