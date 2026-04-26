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
