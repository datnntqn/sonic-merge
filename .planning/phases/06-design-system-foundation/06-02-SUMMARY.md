---
phase: 06-design-system-foundation
plan: "02"
subsystem: design-system
tags: [design-system, components, swiftui, glassmorphism, accessibility, squircle, pill-button]
dependency_graph:
  requires: [06-01-color-tokens, DS-01-semantic-slots]
  provides: [DS-02-squircle-card, DS-03-pill-button, DS-04-glassmorphism-header]
  affects: [phase-07-mixing-station-ui, phase-08-cleaning-lab-ui, phase-09-polish]
tech_stack:
  added: []
  patterns: [SquircleCard-generic-view, ButtonStyle-custom, glassmorphism-ultraThinMaterial, reduceTransparency-fallback, reduceMotion-fallback]
key_files:
  created:
    - SonicMerge/DesignSystem/SquircleCard.swift
    - SonicMerge/DesignSystem/PillButtonStyle.swift
  modified:
    - SonicMerge/DesignSystem/TrustSignalViews.swift
decisions:
  - "[06-02]: SquircleCard uses RoundedRectangle(cornerRadius: SonicMergeTheme.Radius.card, style: .continuous) — 24pt squircle matches DS-02 contract"
  - "[06-02]: PillButtonStyle.sensoryFeedback uses .impact(weight: .light) label form — iOS 26.2 Xcode requires weight: label, not positional .impact(.light)"
  - "[06-02]: PillButtonStyle uses .font(.subheadline) + .fontWeight(.semibold) split — chained .font(.subheadline.weight(.semibold)) fails to compile on ButtonStyleConfiguration.Label in Xcode 26.2"
  - "[06-02]: LocalFirstTrustStrip radius changed from SonicMergeTheme.Radius.card (24pt) to 16pt — DS-04 spec explicitly requires 16pt for the trust strip, distinct from card radius"
metrics:
  duration: 15min
  completed: "2026-04-11"
  tasks_completed: 2
  files_modified: 3
---

# Phase 06 Plan 02: Design System Components Summary

**One-liner:** Implemented SquircleCard (24pt squircle, glass/glow variants), PillButtonStyle (Deep Indigo capsule, inner white glow, haptic, scale animation), and restyled LocalFirstTrustStrip with ultraThinMaterial glassmorphism and Deep Indigo glow ring — all with reduceTransparency and reduceMotion accessibility fallbacks.

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create SquircleCard component | ba9c481 | SonicMerge/DesignSystem/SquircleCard.swift |
| 2 | Create PillButtonStyle and restyle glassmorphism header | 6743be8 | SonicMerge/DesignSystem/PillButtonStyle.swift, SonicMerge/DesignSystem/TrustSignalViews.swift |

---

## Checkpoint: Awaiting Human Verification

Task 3 is a `checkpoint:human-verify` gate. Execution paused pending visual verification of all three design system components in Xcode Simulator (light mode, dark mode, Xcode Previews, and accessibility settings).

---

## Verification Results

- `xcodebuild build -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16e'`: BUILD SUCCEEDED (zero errors)
- `SquircleCard.swift` exists and contains `struct SquircleCard<Content: View>: View`, `glassEnabled`, `glowEnabled`, `accessibilityReduceTransparency`, `ultraThinMaterial`, `semantic.surfaceCard`, `semantic.accentGlow`, `SonicMergeTheme.Radius.card, style: .continuous`, `padding(SonicMergeTheme.Spacing.md)`
- `PillButtonStyle.swift` exists and contains `struct PillButtonStyle: ButtonStyle`, `sensoryFeedback`, `scaleEffect`, `Capsule()`, `Color.white.opacity(0.25)`, `opacity(isEnabled ? 1.0 : 0.35)`, `frame(minHeight: 44)`, `accessibilityReduceMotion`
- `TrustSignalViews.swift` contains `.ultraThinMaterial`, `semantic.accentGlow`, `accessibilityReduceTransparency`, `cornerRadius: 16, style: .continuous`, `opacity(0.08)`, `opacity(0.30)`, `semantic.surfaceCard`

---

## Changes Made

### SquircleCard.swift (created)

- Generic `SquircleCard<Content: View>` view with `glassEnabled: Bool = false` and `glowEnabled: Bool = false`
- 24pt continuous corner radius (`SonicMergeTheme.Radius.card`, `.continuous` style)
- Glass mode: `ZStack { Color(surfaceGlass) + Rectangle().fill(.ultraThinMaterial) }`
- `reduceTransparency` fallback: solid `surfaceCard` replaces material
- Border: 1pt `accentGlow` at 0.18 opacity when glass enabled
- Glow shadow: `accentGlow` at 0.25 opacity, radius 24, y:10
- Default shadow: black at 0.10 opacity, radius 16, y:6
- 16pt internal padding (`SonicMergeTheme.Spacing.md`)
- Xcode Preview with default/glass/glow card variants

### PillButtonStyle.swift (created)

- `ButtonStyle` implementation with `Capsule()` shape
- Deep Indigo fill from `semantic.accentAction`
- Inner white shimmer glow overlay: `LinearGradient` white 0.25 → 0.0 top to 60% height
- Disabled state: 0.35 opacity, inner glow hidden via `if isEnabled` guard
- Haptic: `.sensoryFeedback(.impact(weight: .light), trigger: isPressed)` on press
- Scale animation: `scaleEffect(0.96)` with `.spring(response: 0.25, dampingFraction: 0.6)`
- `reduceMotion` fallback: returns scale 1.0, nil animation
- Minimum touch target: `.frame(minHeight: 44)`
- Xcode Preview with enabled and disabled states

### TrustSignalViews.swift (restyled)

| Property | Before (v1.0) | After (v1.1) |
|----------|---------------|--------------|
| Icon color | `semantic.trustIcon` | `semantic.accentGlow` (Deep Indigo) |
| Background | solid `surfaceElevated` | `ultraThinMaterial` + `accentGlow` at 0.08 opacity |
| Corner radius | `SonicMergeTheme.Radius.card` (24pt) | 16pt (per DS-04 spec) |
| Border | `trustIcon` at 0.25 opacity | `accentGlow` at 0.30 opacity |
| Shadow | black 0.08, radius 10, y:4 | `accentGlow` 0.20, radius 12, y:0 (ambient ring) |
| `reduceTransparency` | none | falls back to solid `surfaceCard` |

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `.sensoryFeedback(.impact(.light))` failed to compile**
- **Found during:** Task 2 build verification
- **Issue:** `SensoryFeedback.impact` requires `weight:` label in iOS 26.2 / Xcode 26.2 — positional `.impact(.light)` causes `missing argument label 'weight:'` error
- **Fix:** Changed to `.sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)`
- **Files modified:** SonicMerge/DesignSystem/PillButtonStyle.swift
- **Commit:** 6743be8

**2. [Rule 1 - Bug] `.font(.subheadline.weight(.semibold))` failed on ButtonStyleConfiguration.Label**
- **Found during:** Task 2 build verification
- **Issue:** Chained `.weight()` modifier on `Font` does not compile when applied to `ButtonStyleConfiguration.Label` in Xcode 26.2
- **Fix:** Split into `.font(.subheadline)` + `.fontWeight(.semibold)` separate modifiers
- **Files modified:** SonicMerge/DesignSystem/PillButtonStyle.swift
- **Commit:** 6743be8

---

## Known Stubs

None. All three components use semantic color tokens from Plan 01. No hardcoded colors, no placeholder values.

---

## Self-Check: PASSED

- [x] `SonicMerge/DesignSystem/SquircleCard.swift` — FOUND (created)
- [x] `SonicMerge/DesignSystem/PillButtonStyle.swift` — FOUND (created)
- [x] `SonicMerge/DesignSystem/TrustSignalViews.swift` — FOUND (modified)
- [x] Commit `ba9c481` — Task 1 SquircleCard
- [x] Commit `6743be8` — Task 2 PillButtonStyle + TrustSignalViews
- [x] BUILD SUCCEEDED with zero errors
