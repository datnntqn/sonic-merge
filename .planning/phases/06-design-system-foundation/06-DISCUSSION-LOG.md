# Phase 6: Design System Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-11
**Phase:** 06-design-system-foundation
**Areas discussed:** Color token migration strategy

---

## Color Token Migration Strategy

### Token Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Expand SonicMergeSemantic (Recommended) | Add new slots (accentAI, accentGlow, surfaceCard) to existing struct. Keeps one resolved palette, existing views migrate incrementally. | ✓ |
| Replace with new token system | Create fresh DesignTokens struct with v1.1 naming from scratch. Cleaner naming but requires updating all existing view references at once. | |
| Layer: keep old + add new | Keep SonicMergeSemantic as-is, add V1_1Tokens struct alongside. Two systems coexist until Phase 9 cleanup. | |

**User's choice:** Expand SonicMergeSemantic (Recommended)
**Notes:** None

### Dark Palette Transition

| Option | Description | Selected |
|--------|-------------|----------|
| Hard swap (Recommended) | Replace charcoal+mint values in darkConveyor() with pure black + Deep Indigo + Lime Green. v1.0 dark palette is gone. | ✓ |
| Keep both as selectable themes | Add v1.1 dark palette alongside existing one. User can choose 'Classic Dark' vs 'Spatial Dark'. | |

**User's choice:** Hard swap (Recommended)
**Notes:** None

### Light Mode Accent Color

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, Deep Indigo only (Recommended) | Replace #007AFF with #5856D6 as primary accent in light mode. Unified brand color across both modes. | ✓ |
| Keep blue for interactive, Indigo for brand | Use #007AFF for tappable buttons/links, #5856D6 for brand elements. Two accent tiers. | |

**User's choice:** Yes, Deep Indigo only (Recommended)
**Notes:** None

### Lime Green AI Accent Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Both modes (Recommended) | Lime Green marks AI features in both light and dark mode. Consistent AI visual identity. | ✓ |
| Dark mode only | Lime Green only in dark mode. Light mode AI features use Deep Indigo. Matches spec literally. | |
| You decide | Claude picks the approach that best fits the design system architecture. | |

**User's choice:** Both modes (Recommended)
**Notes:** None

---

## Claude's Discretion

- SquircleCard glass material behavior (blur intensity, transparency, content interaction)
- PillButton inner glow style, haptic intensity, disabled state
- Glassmorphism header design (blur depth, glow placement, scroll behavior)

## Deferred Ideas

None — discussion stayed within phase scope
