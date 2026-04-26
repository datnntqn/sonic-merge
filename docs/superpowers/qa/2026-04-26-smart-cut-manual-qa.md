# Smart Cut — Manual QA Protocol

**Run before merging Smart Cut to main.**

## Sample episodes (5)

1. **Interview** — two speakers, 30+ minutes
2. **Monologue** — single speaker, 20+ minutes, frequent fillers
3. **Casual chat** — 2-3 speakers, lots of overlap, frequent "like"
4. **Music-heavy** — episode with intro/outro music + spoken content
5. **Multi-speaker debate** — 3+ speakers, fast pace

## For each sample, verify:

### Analyze
- [ ] Card transitions Idle → Analyzing → Results
- [ ] Progress reaches 100%
- [ ] If backgrounded, resumes on foreground (no lost progress)
- [ ] If "Run in BG" tapped, notification fires when complete (may take iOS-discretion time)

### Curation
- [ ] Default-on categories (`um`, `uh`, `ah`, `er`) are checked
- [ ] Default-off categories (`like`, `you know`, etc.) are unchecked
- [ ] Toggling a category flips all children
- [ ] Toggling individual rows leaves others unchanged
- [ ] Pause row shows count + savings
- [ ] Threshold stepper updates pause count

### Per-occurrence preview
- [ ] Tapping `▶` plays a 4s window centered on the cut
- [ ] Audio is original (not cut) — confirms preview source

### Apply
- [ ] Apply completes in a reasonable time (no perf budget set in v1; flag if it takes longer than the original analyze)
- [ ] State transitions to Applied
- [ ] A/B pill toggles between input and output
- [ ] No clicks or pops at 3 randomly sampled cut seams
- [ ] No unintended word truncation observed in a 30s end-to-end listen
- [ ] After toggling additional rows post-Apply, the "Re-apply" button appears (spec §6.4)

### Pass criterion
- No audible click/pop on >80% of seams sampled across the 5 episodes
- No unintended word truncation observed
- Pause cuts feel natural (not abruptly compressed)

### Edge cases to verify
- [ ] Speech permission denied → inline alert with Settings link
- [ ] Notification permission denied → "Tip" appears, BG task still scheduled
- [ ] Audio < 30s → low-confidence warning shown but Analyze proceeds
- [ ] Empty result (silent file) → "Found 0 fillers" + Apply disabled
- [ ] Re-merging in Mixing Station after Smart Cut → State 5 (Stale) banner
- [ ] Disk full at Apply → toast error, EditList preserved

### Sign-off
- [ ] All 5 episodes meet pass criteria
- [ ] Edge cases verified
- [ ] PR description updated with QA results


---

## Cleaning Lab Tabs (clt-t1..t5)

Run after the Cleaning Lab tabs refactor lands.

### Default + state preservation
- [ ] First entry to Cleaning Lab lands on the **AI Denoise** tab.
- [ ] Tapping the **Smart Cut** pill smoothly switches the visible card.
- [ ] Tapping back to **AI Denoise** restores the orb in whatever state it was last in (denoised state preserved).
- [ ] After Apply Cuts in Smart Cut, switching to Denoise tab → changing intensity → re-denoising → switching back to Smart Cut transitions the card to the Stale state on next visit.

### Floating action bar
- [ ] Bar visible on AI Denoise tab whenever a merged file is loaded; label is "Denoise Audio" before first denoise, "Re-denoise" after.
- [ ] Bar disabled (visible-but-greyed) on Denoise tab when `mergedFileURL` is nil.
- [ ] Bar visible on Smart Cut tab in **Results** state with "Apply Cuts" label.
- [ ] Bar visible on Smart Cut tab in **Applied** state ONLY when `hasDirtyEditsSinceApply` is true ("Re-apply" label).
- [ ] Bar collapses (no chassis visible) on Smart Cut tab in idle / analyzing / stale / error states.
- [ ] Bar reads cleanly over scrolled list content (glassmorphic blur, not opaque).
- [ ] Bar respects safe-area on devices with home indicator (no clipping).

### Smart Cut visual polish
- [ ] "saves ~Xs" badge has visible lime glow when savings > 0.
- [ ] Badge dims to grey when all rows are toggled off (savings == 0); does NOT disappear (layout stays stable).
- [ ] Disabled per-occurrence filler rows visually muted to ~40% opacity but still tappable to re-enable.
- [ ] Each category-block (header + expanded children) sits on its own rounded surface background.
- [ ] Pause row also sits on a rounded surface background.

### No regressions
- [ ] The toolbar share icon remains tappable from either tab.
- [ ] Export from either tab uses `smartCutOutputURL ?? denoisedTempURL ?? mergedFileURL` (the most-processed audio).
- [ ] Light haptic still fires on individual filler toggle.
- [ ] Medium haptic still fires on category toggle.
- [ ] Heavy haptic still fires on Apply Cuts.
- [ ] EditFillerListSheet opens and dismisses cleanly; floating bar does NOT visually overlap the sheet.
- [ ] **Sheet-during-tab-switch**: open EditFillerListSheet → swipe to Denoise tab → sheet dismisses cleanly without console warning; returning to Smart Cut leaves the card in its previous state.

### Smaller-device check
- [ ] On iPhone SE (smallest supported): SegmentedPill + scroll content + floating bar all fit without clipping.
