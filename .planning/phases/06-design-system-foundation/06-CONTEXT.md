# Phase 6: Design System Foundation - Context

**Gathered:** 2026-04-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver centralized color tokens (light/dark), reusable SquircleCard and PillButton components, and a glassmorphism header — the visual primitives that Phases 7–9 consume. No screen-level restyling (that's Phase 7+). No functional changes to ViewModels or services.

</domain>

<decisions>
## Implementation Decisions

### Color Token Migration
- **D-01:** Expand existing `SonicMergeSemantic` struct with new slots (accentAI for Lime Green, accentGlow for Deep Indigo glow, surfaceCard for squircle cards) rather than replacing or creating a parallel system. Existing views migrate incrementally.
- **D-02:** Hard swap dark palette — replace charcoal (#121315) + neon-mint (#2EEB9E) with pure black #000000 + Deep Indigo #5856D6 + Lime Green #A7C957. The v1.0 dark palette is gone.
- **D-03:** Deep Indigo #5856D6 becomes the sole accent color in light mode, replacing #007AFF. Unified brand color across both modes.
- **D-04:** Lime Green #A7C957 AI accent appears in both light and dark modes for AI features (denoise progress, slider, AI orb, action indicators). Consistent AI visual identity regardless of mode.
- **D-05:** Light mode background changes from #F8F9FA to #FBFBFC per v1.1 spec.

### Claude's Discretion
- SquircleCard component API design (glass material intensity, transparency level, glow shadow parameters) — build what fits the 24pt continuous corner radius spec
- PillButton inner glow style (subtle shimmer vs bright edge), haptic intensity (light vs medium), disabled state visual treatment
- Glassmorphism header implementation (blur depth, Indigo glow placement, scroll behavior) — restyle existing `LocalFirstTrustStrip` with ultraThinMaterial
- Whether to use `Color` (SwiftUI) vs `UIColor` for new token slots — follow existing `SonicMergeSemantic` pattern (UIColor stored, Color(uiColor:) at call site)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design System (existing code)
- `SonicMerge/DesignSystem/SonicMergeTheme.swift` — v1.0 color palette (ColorPalette enum) and radius tokens
- `SonicMerge/DesignSystem/SonicMergeTheme+Appearance.swift` — SonicMergeSemantic resolved palette, ThemePreference enum, SwiftUI EnvironmentKey
- `SonicMerge/DesignSystem/TrustSignalViews.swift` — LocalFirstTrustStrip (current "Private by Design" card, needs glassmorphism restyle)

### Requirements
- `.planning/REQUIREMENTS.md` §v1.1 Requirements / Design System — DS-01 through DS-04 acceptance criteria

### Tests
- `SonicMergeTests/SonicMergeThemeTests.swift` — existing theme tests to extend

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SonicMergeSemantic` struct: 8 color slots with light/dark resolution via `resolved(colorScheme:preference:)` — expand with new slots
- `ThemePreference` enum: system/light/dark with `@AppStorage` persistence — no changes needed
- `SonicMergeSemanticKey` EnvironmentKey: injects resolved palette into SwiftUI environment — pattern to follow for any new environment values
- `LocalFirstTrustStrip`: existing "Private by Design" view — restyle to glassmorphism rather than rebuild

### Established Patterns
- UIColor stored in semantic struct, wrapped with `Color(uiColor:)` at SwiftUI call sites
- `SonicMergeTheme.Radius` enum for radius constants (currently 12pt card, 8pt chip)
- Continuous corner radius via `RoundedRectangle(cornerRadius:style:.continuous)` already used in TrustSignalViews
- No ButtonStyle implementations exist — PillButton will be the first custom ButtonStyle

### Integration Points
- All existing views read `@Environment(\.sonicMergeSemantic)` — palette swap propagates automatically
- `SonicMergeTheme.Radius.card` used in TrustSignalViews — update to 24pt affects existing components
- `SonicMergeTheme.ColorPalette` static values referenced directly in SonicMergeSemantic resolution — update these hex values

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches for SquircleCard, PillButton, and glassmorphism header. User focused discussion on color token strategy; component design left to Claude's discretion.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-design-system-foundation*
*Context gathered: 2026-04-11*
