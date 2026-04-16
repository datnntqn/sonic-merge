# Phase 8: Cleaning Lab + AI Orb - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Restyle the Cleaning Lab screen with the v1.1 "Modern Spatial Utility" design system AND introduce the AI Orb — a pulsating nebula sphere visualizer rendered via TimelineView + Canvas during denoising. All controls migrate to SquircleCard wrappers and PillButtonStyle. All hardcoded colors are replaced with semantic tokens. Full dark mode support. Pure view-layer phase — zero ViewModel or service changes.

</domain>

<decisions>
## Implementation Decisions

### AI Orb Rendering Approach
- **D-01:** Blob parameters (baseRadius, phaseOffset, frequency, gradient stops, blendMode) are structured as a static `[BlobConfig]` array. The Canvas iterates the array to draw each blob. This separates data from rendering and makes individual blobs easy to tune.
- **D-02:** The outer bloom (Lime Green glow extending beyond the 240pt orb) is rendered as a separate SwiftUI View layer in a ZStack — NOT inside the Canvas. `.blur(radius: 24)` is applied to this separate layer. This keeps Canvas draw calls minimal and follows the UI-SPEC recommendation ("outside Canvas — cheaper this way").
- **D-03:** The idle state (no denoising, no result) reuses the same static t=0 nebula composition as the reduceMotion fallback. Label switches to "Ready to denoise" in muted `textSecondary`. No dimming or desaturation — the orb looks identical whether idle or reduceMotion, just without animation.
- **D-04:** The progress ring animates smoothly with `.easeOut(duration: 0.25)` per each discrete progress callback from the ViewModel. Ring sweeps smoothly between values rather than jumping.

### LimeGreenSlider Gesture Tuning
- **D-05:** The 44pt touch target around the 28pt visible thumb uses `.contentShape(Rectangle().size(width: 44, height: 44))` centered on the thumb circle. Standard HIG approach matching the UI-SPEC.
- **D-06:** The slider track is tappable (jump-to-position). Tapping anywhere on the track jumps the value to that position, matching iOS system Slider behavior. `DragGesture(minimumDistance: 0)` on the full track frame achieves this.
- **D-07:** The `reduceTransparency` environment value IS checked in Phase 8. When active, thumb glow parameters change from radius 12/opacity 0.35 to radius 6/opacity 0.50. Consistent with Phase 6/7 accessibility patterns.

### Claude's Discretion
- Layout migration sequencing — order of restyle operations (staleBanner, slider, buttons, then new components, or vice versa)
- PillButtonStyle `.Tint` enum implementation details — struct placement, label color branching logic
- Export sheet preservation — how to cleanly separate the denoising progress sheet removal from the export sheet chain
- Stale banner SquircleCard internal spacing and transition animation
- Accessibility VoiceOver announcement phrasing beyond what the UI-SPEC specifies
- WaveformCanvasView scrub line color migration (`textPrimary@0.3` per UI-SPEC)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### UI Design Contract (primary)
- `.planning/phases/08-cleaning-lab-ai-orb/08-UI-SPEC.md` — Complete visual and interaction contract for Phase 8. Defines AI Orb spec, LimeGreenSlider spec, color story, layout contract, component contracts, accessibility rules, dark mode migration table, implementation constraints. THIS IS THE SOURCE OF TRUTH for all visual decisions.

### Design System (existing code)
- `SonicMerge/DesignSystem/SonicMergeTheme.swift` — Color palette tokens, radius tokens, spacing scale
- `SonicMerge/DesignSystem/SonicMergeTheme+Appearance.swift` — SonicMergeSemantic resolved palette, ThemePreference, EnvironmentKey
- `SonicMerge/DesignSystem/PillButtonStyle.swift` — Current PillButtonStyle (Variant + Size enums, to be extended with Tint)
- `SonicMerge/DesignSystem/SquircleCard.swift` — SquircleCard component (glassEnabled, glowEnabled parameters)

### Cleaning Lab (existing code to restyle)
- `SonicMerge/Features/Denoising/CleaningLabView.swift` — Current view with 6 hardcoded colors, manual RoundedRectangle wrappers, system Slider, denoising progress sheet to remove
- `SonicMerge/Features/Denoising/CleaningLabViewModel.swift` — FROZEN contract (isProcessing, progress, intensity, hasDenoisedResult, isHoldingOriginal, waveformPeaks, etc.) — read to understand available properties, never modify

### Upstream UI Specs
- `.planning/phases/06-design-system-foundation/06-UI-SPEC.md` — Token definitions, SquircleCard + PillButtonStyle + GlassmorphismHeader specs
- `.planning/phases/07-mixing-station-restyle/07-UI-SPEC.md` — PillButtonStyle Variant/Size matrix, spine-threading patterns, drag-animation conventions

### Requirements
- `.planning/REQUIREMENTS.md` §v1.1 Requirements / Cleaning Lab — CL-01, CL-02, CL-03 acceptance criteria

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SquircleCard`: Ready to consume — replaces all manual `RoundedRectangle + .fill + .shadow` wrappers in CleaningLabView
- `PillButtonStyle`: Variant (.filled, .outline) + Size (.regular, .compact, .icon) — Phase 8 extends with Tint (.accent, .ai)
- `SonicMergeSemantic.accentAI` (#A7C957 Lime Green): Token already exists from Phase 6, Phase 8 is its first consumer
- `SonicMergeSemantic.accentGradientEnd` (#AF52DE System Purple): Added in Phase 7, reused for AI Orb mid-band
- `@Environment(\.sonicMergeSemantic)`: Already wired in CleaningLabView — palette changes propagate automatically
- `TrustSignalCopy.aiDenoiseTitle/Subtitle`: Existing string constants for the trust strip

### Established Patterns
- UIColor stored in semantic struct, wrapped with `Color(uiColor:)` at SwiftUI call sites
- `SonicMergeTheme.Radius.card` = 24pt (updated in Phase 6)
- `SonicMergeTheme.Spacing.*` 7-tier scale (xs=4 through xxxl=64)
- `.sensoryFeedback(.impact(weight: .light), trigger:)` — iOS 26.2 requires `weight:` label
- `.font(.subheadline).fontWeight(.semibold)` split form (Phase 06-02 pattern)

### Integration Points
- CleaningLabView.body ScrollView: restyle content order, remove `.sheet(isPresented: .constant(viewModel.isProcessing))` for denoising progress
- Export plumbing (showExportSheet, showExportProgressSheet, showShareSheet): MUST remain untouched
- Navigation: CleaningLabView pushed from MixingStationView via NavigationLink — no changes needed

</code_context>

<specifics>
## Specific Ideas

No specific requirements beyond the UI-SPEC — user focused discussion on rendering architecture (BlobConfig array, separate bloom layer) and slider gesture behavior (track-tappable, contentShape expansion). All other visual details are locked in the UI-SPEC.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 08-cleaning-lab-ai-orb*
*Context gathered: 2026-04-16*
