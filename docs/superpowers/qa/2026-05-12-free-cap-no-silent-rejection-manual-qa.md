# Free-cap "no silent rejection" — manual QA checklist

**Spec:** `docs/superpowers/specs/2026-05-12-free-cap-no-silent-rejection-design.md`
**Date:** 2026-05-12

Unit tests cover the pure logic (`PresentDecision` routing, caption strings, App Group mirror writes). This checklist covers the UI integration and the Share Extension cross-process path.

## Pre-conditions

- Build & install the app on iPhone 17 Simulator (or a device).
- Start on a Free account. Settings → Subscription should show "Free" status.
- Reset paywall dismiss counters from a previous QA run if needed:
  ```bash
  # In the simulator's UserDefaults, the keys are:
  # PaywallTriggerCoordinator.dismissCount.hitLengthCap
  # PaywallTriggerCoordinator.dismissCount.hitDailyCap
  ```

## Smart Cut — in-app

- [ ] **A1.** Empty Smart Cut tab shows `FreeCapCaption` below the hero import button: `Free: up to 5 min · 0 of 3 today`.
- [ ] **A2.** Import a 2-minute clip → session created. Caption updates to `Free: up to 5 min · 1 of 3 today`.
- [ ] **A3.** Import a 7-minute clip → paywall sheet appears with the `.hitLengthCap` headline "This clip is longer than free supports. Pro = any length."
- [ ] **A4.** Dismiss the paywall. Try a *second* 7-minute import in the same session → top-anchored toast slides in: "This 7:XX clip exceeds the Free 5-min cap." with an "Upgrade →" button. Auto-dismisses after 5s.
- [ ] **A5.** Tap "Upgrade →" on the toast → paywall opens (this is the `.settingsUpgrade` bypass path).
- [ ] **A6.** Tap the caption itself → paywall opens (also `.settingsUpgrade`).
- [ ] **A7.** Hit the 3-session daily cap by importing 3 ≤ 5-min clips. The 4th attempt at any duration triggers the daily-cap paywall first time, toast "You've used today's 3 free sessions." on subsequent attempts.

## Denoise — in-app

- [ ] **B1.** Empty Denoise tab shows `Free: up to 3 min · 0 of 3 today` caption.
- [ ] **B2.** 4-minute clip → paywall sheet (first time), toast (subsequent throttled attempts) with "exceeds the Free 3-min cap."

## Merge — in-app

- [ ] **C1.** Empty Merge tab shows `Free: up to 3 clips` caption.
- [ ] **C2.** Add 3 clips → all admitted, caption visible throughout.
- [ ] **C3.** Add a 4th clip → paywall first time, toast "Free is limited to 3 clips." on subsequent throttled attempts. The 4th clip should NOT appear in the timeline.
- [ ] **C4.** Drag-drop a 4th clip — same gate as C3.

## Share Extension

- [ ] **D1.** Free + over-cap: open Files.app, share a 7-min audio file → CleanCut Share Extension. Extension HUD shows "Free limit reached" / "This 7:XX clip exceeds the Free 5-min cap. Open CleanCut to upgrade." Done button dismisses; CleanCut not opened.
- [ ] **D2.** Verify nothing was imported: open CleanCut, no new session appears in Smart Cut Recents.
- [ ] **D3.** Free + under-cap: share a 2-min clip → HUD shows "Adding to CleanCut…" → "Added!" → auto-dismisses. Open CleanCut → new session appears.
- [ ] **D4.** Pro + over-cap: upgrade to Pro in app, then share a 7-min clip → admitted. (Run after E1 below.)

## Pro upgrade & downgrade

- [ ] **E1.** Upgrade to Pro via paywall. After purchase, all `FreeCapCaption` instances disappear from home screens. No length gating fires on any subsequent in-app import.
- [ ] **E2.** Subscription expiry (StoreKit configuration "expire now" if testing locally): Pro flag flips back to Free, caption reappears on next view appearance.
- [ ] **E3.** With Pro active, share an 8-min file via Share Extension → admitted (App Group mirror reflects Pro).

## Accessibility

- [ ] **F1.** With VoiceOver on, when the toast appears, the announcement "This 7:XX clip exceeds the Free 5-min cap." is read.
- [ ] **F2.** `FreeCapCaption` is announced as a button and reads the caption text.
- [ ] **F3.** Toast can be activated via the rotor and the Upgrade button is reachable.

## Theme

- [ ] **G1.** Toast renders correctly in both light and dark mode (regular material background; readable text; indigo accent color).
- [ ] **G2.** Share Extension HUD's `.freeLimitReached` state uses the indigo accent (matches main app chrome).
- [ ] **G3.** Caption uses `.secondary` foreground; legible in both themes.

## Regression spot-checks

- [ ] **H1.** Settings → "Upgrade to Pro" still opens the paywall (bypass path unchanged).
- [ ] **H2.** "Custom filler library" gate in `EditFillerListStudioSheet` still opens the paywall (settings reason, no cap-hit, no toast).
- [ ] **H3.** Export-format paywall (WAV → AAC) for Free unchanged.
- [ ] **H4.** ReviewPromptCoordinator still suppresses review prompts when a paywall has been shown this session.
