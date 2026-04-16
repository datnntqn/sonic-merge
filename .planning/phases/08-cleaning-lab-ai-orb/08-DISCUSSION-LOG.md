# Phase 8: Cleaning Lab + AI Orb - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-16
**Phase:** 08-cleaning-lab-ai-orb
**Areas discussed:** AI Orb rendering approach, LimeGreenSlider gesture tuning

---

## AI Orb Rendering Approach

### Blob Parameter Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Static struct array | Define a [BlobConfig] array with baseRadius, phaseOffset, frequency, gradient stops, blendMode. Canvas iterates the array. Easy to tune, clear separation of data vs rendering. | ✓ |
| Inline constants | Hardcode each blob's parameters directly in the Canvas closure. Simpler code but harder to tune individual blobs. | |
| You decide | Claude picks the cleanest approach for the 4-blob composition. | |

**User's choice:** Static struct array (Recommended)
**Notes:** None — user accepted recommended approach.

### Outer Bloom Implementation

| Option | Description | Selected |
|--------|-------------|----------|
| Separate View layer | A ZStack sibling with .blur(radius: 24) applied. UI-SPEC recommends this ('outside Canvas — cheaper this way'). Keeps Canvas draw calls minimal. | ✓ |
| Inside Canvas | Draw the bloom directly in the Canvas context with a gradient. Fewer view layers but the blur must be applied to the entire Canvas. | |
| You decide | Claude picks based on GPU budget (max 2 blur layers). | |

**User's choice:** Separate View layer (Recommended)
**Notes:** None — aligns with UI-SPEC recommendation.

### Idle State Visual

| Option | Description | Selected |
|--------|-------------|----------|
| Same static composition | Idle and reduceMotion both show the t=0 nebula. Label switches to 'Ready to denoise' in muted textSecondary. Consistent visual, less code. | ✓ |
| Dimmed/desaturated orb for idle | Apply .opacity(0.6) or .saturation(0.7) when idle to signal 'not active'. Label still reads 'Ready to denoise'. | |
| You decide | Claude picks what looks best while staying within the spec's constraints. | |

**User's choice:** Same static composition (Recommended)
**Notes:** None — user preferred consistency and simplicity.

### Progress Ring Animation

| Option | Description | Selected |
|--------|-------------|----------|
| Smooth easeOut animation | Each progress update animates with .easeOut(duration: 0.25) per the UI-SPEC. Ring sweeps smoothly between discrete progress values. | ✓ |
| Instant steps | Ring jumps to each new value immediately. More accurate to actual progress but looks choppy. | |
| You decide | Claude picks the animation approach. | |

**User's choice:** Smooth easeOut animation (Recommended)
**Notes:** None — matches UI-SPEC specification.

---

## LimeGreenSlider Gesture Tuning

### Touch Target Implementation

| Option | Description | Selected |
|--------|-------------|----------|
| .contentShape expansion | Use .contentShape(Rectangle().size(width: 44, height: 44)) centered on the thumb circle. Matches UI-SPEC exactly. Standard HIG approach. | ✓ |
| Invisible overlay circle | Layer a 44pt transparent Circle over the 28pt visible thumb. Same hit area, different implementation. | |
| You decide | Claude picks the cleanest approach. | |

**User's choice:** .contentShape expansion (Recommended)
**Notes:** None — standard HIG pattern.

### Track Tappability

| Option | Description | Selected |
|--------|-------------|----------|
| Track tappable | Tapping anywhere on the track jumps the value to that position. Matches iOS system Slider behavior. DragGesture(minimumDistance: 0) on the full track frame achieves this. | ✓ |
| Thumb drag only | Only dragging from the thumb moves the value. More precise but less discoverable. Requires hit-testing against thumb position. | |
| You decide | Claude picks based on iOS conventions. | |

**User's choice:** Track tappable (Recommended)
**Notes:** None — matches iOS system Slider convention.

### reduceTransparency Fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, check reduceTransparency | Read @Environment(\.accessibilityReduceTransparency) and adjust shadow params accordingly. Matches the spec and Phase 6/7 accessibility patterns. | ✓ |
| Skip for now | Implement the standard glow first. The reduceTransparency fallback can be addressed in Phase 9 (Polish). | |
| You decide | Claude picks based on Phase 8 scope. | |

**User's choice:** Yes, check reduceTransparency (Recommended)
**Notes:** None — consistent with Phase 6/7 accessibility patterns, within Phase 8 scope.

---

## Claude's Discretion

- Layout migration sequencing (order of restyle operations)
- PillButtonStyle Tint enum implementation details
- Export sheet preservation approach
- Stale banner SquircleCard internal spacing and transition
- Accessibility VoiceOver phrasing beyond UI-SPEC
- WaveformCanvasView scrub line color migration

## Deferred Ideas

None — discussion stayed within phase scope.
