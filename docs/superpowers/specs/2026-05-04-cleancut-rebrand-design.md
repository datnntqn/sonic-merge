# CleanCut Rebrand — Fire Gradient + Custom Smart Cut Mark

**Date:** 2026-05-04
**Status:** Spec
**Author:** Claude (autonomous mode, user-approved direction "A")

## Summary

A whole-app visual rebrand inspired by the AHS Audio reference: deep-navy base with a four-stop fire gradient (red → orange → magenta → violet) replacing the indigo+lime two-color system. A custom **Cut Waveform** glyph replaces the generic `sparkles` SF Symbol everywhere Smart Cut is represented (8 callsites + onboarding) **and** becomes the iOS app icon for both light and dark appearance variants. Light mode keeps a near-white surface; dark mode becomes the headline aesthetic.

## Goals

1. **Single visual identity** — palette feels coherent across all three tabs, all five onboarding screens, and the app icon.
2. **Personalized Smart Cut mark** — replace the off-the-shelf SF Symbol that the user described as "like AI, I don't like it" with a custom glyph that reads as "audio cut" at every size from a 24pt toolbar item up to a 1024pt app icon.
3. **Preserve the two-color discipline** — same rule as today (brand chrome vs. AI moments), just with a different color story. Indigo → violet for navigation; lime → fire gradient for AI moments.
4. **Zero behavior change** — only colors, icons, and gradient stops change. No new features, no token-key renames that would force callsites to be re-typed beyond what the rebrand itself touches.

## Non-Goals

- Renaming bundle ID, scheme, module, App Group ID, type names, `@AppStorage` keys (deliberate per CLAUDE.md §Project).
- Touching `MeshGradient` math in `PremiumBackground.swift` beyond the input colors it consumes.
- Touching tab-bar layout, navigation hierarchy, copy, or feature behavior.
- Changing the binary `ThemePreference` (still `.light` / `.dark`).
- Generating an entire icon family (notification icon, Spotlight, Settings, etc. — Xcode's "Single Size" 1024×1024 entry handles those automatically on iOS 14+).

## Design Decisions

### D-01 — Direction A: gradient as `accentAI`

User picked Option A from the visual companion: the fire gradient *is* the AI accent (not a single flat magenta). Implementation needs a way to expose a gradient through the existing `SonicMergeSemantic` struct, which currently stores only `UIColor` values.

**Resolution:** Add one new slot to `SonicMergeSemantic`:

```swift
/// Fire-gradient stops for AI-moment surfaces — red → orange → magenta → violet.
/// Use as `LinearGradient(colors: semantic.accentAIGradientStops.map(Color.init), …)`.
/// Callsites that need a flat single color still read `accentAI` (the magenta stop).
var accentAIGradientStops: [UIColor]
```

Callsites that already render a flat fill (e.g., `PillButtonStyle.ai`) keep using `accentAI` and get the magenta `#F0506E`. Callsites that want the gradient (the floating "Apply Cuts" CTA, the AI Orb, the Smart Cut mark itself) read `accentAIGradientStops`. This preserves the two-color discipline at a semantic level: there's still ONE "AI moment" token; it just exposes both a flat and a gradient face.

### D-02 — `accentAction` becomes Deep Violet `#6F2DBD`

Indigo `#5856D6` → Violet `#6F2DBD`. Violet is the last stop of the fire gradient, so brand chrome (tab-bar selection, primary CTAs, back-chevrons) reads as a continuation of the gradient at rest.

### D-03 — Dark default for the icon, but theme toggle stays neutral

App icon is a single dark-navy canvas; the mark uses the fire gradient on it. The in-app theme toggle stays neutral — dark and light both read well. Light mode uses the same fire gradient on a near-white base.

The home screen / app-icon dark+light+tinted variants in `AppIcon.appiconset` all use the **same dark-navy canvas + fire-gradient glyph**. Reasons:
- The user described the AHS reference as "the colors I want." That reference IS dark.
- iOS dark/light icon variants are about subtle tonal shift, not full re-skinning. A different light-canvas icon would make the brand feel inconsistent in the home-screen grid.
- The tinted variant uses iOS 18+'s automatic monochromatic processing on the same source.

### D-04 — `surfaceBase` dark gets a hint of navy

`#000000` → `#0A0A18`. Pure black wasn't on the reference; the reference is a deep navy that reads almost-black but lifts the violet accents away from the background. `#0A0A18` is the inkjet-print-equivalent of pure black for the eye but pairs better with the gradient.

`surfaceCard` dark: `#0F0F0F` → `#15172B`. Same rationale — slightly cool card surface so violet/magenta accents on cards don't fight the surface.

Light mode surfaces unchanged.

### D-05 — Smart Cut mark structure: bars + diagonal

The Cut Waveform glyph is **8 vertical waveform bars** (4 on each side, ascending then descending heights) **bisected by a single white diagonal line at ~26°**. Reads as "audio cut" at 24pt and at 1024pt without external annotation.

- Bars use `LinearGradient` with the fire-gradient stops, horizontal direction.
- Diagonal is solid white (`#FFFFFF`) at 3pt stroke (proportional to icon size).
- Bars to the LEFT of the diagonal use 35% / 55% / 80% / 100% gradient opacity (creates a "fade in" feel — the unprocessed audio).
- Bars to the RIGHT of the diagonal mirror the heights in reverse and re-use 100% / 80% / 55% / 35% (the "cleaned" audio fading out).
- 1024×1024 app-icon canvas is `#0A0A18` deep navy, full-bleed, no rounding (iOS applies the squircle mask).

### D-06 — One `SmartCutMark` SwiftUI view, three size presets

The 8 in-app callsites currently use `Image(systemName: "sparkles")` at varying sizes. Rather than reproduce the SVG at each callsite, define one parametric SwiftUI view:

```swift
struct SmartCutMark: View {
    enum Size { case toolbar, hero, splash }
    let size: Size
    /// When true, gradient bars become a flat `tint` color.
    /// Used for monochrome contexts (e.g. tab bar where iOS forces single-color rendering).
    var monochromeTint: Color? = nil
    var body: some View { … }
}
```

`Size.toolbar` → 22×22 logical points (tab bar, toolbar buttons).
`Size.hero` → 56×56 (onboarding feature pill, AI Orb idle state).
`Size.splash` → 96×96 (onboarding hero step 1, Smart Cut empty-state).

**Tab bar caveat:** UIKit's `UITabBarItem` does NOT render gradient images in its native rendering. Two options:
- **Option α (preferred):** Pre-render the mark to a 1× / 2× / 3× PNG asset set in `Assets.xcassets/SmartCutTabIcon.imageset/`, with `Render As: Default`, and supply both filled and outline variants (selected vs. unselected).
- **Option β (rejected):** Use `Label("Smart Cut", systemImage: "...")` and have iOS auto-tint a flat shape — loses the gradient identity.

We pick Option α — the asset set means the gradient survives in the tab bar, which is the most-visible single placement of the mark in the app.

### D-07 — Onboarding: hero badge keeps the gradient frame, swaps the glyph

Current onboarding hero (`OnboardingFlow.swift:159`) is a 80×80 rounded rectangle with a 20%-alpha gradient fill and a `sparkles` symbol on top. We replace just the symbol — `SmartCutMark(size: .hero)` — and update the gradient stops to the fire gradient. The feature pill at line 193 (`FeaturePill(icon: "sparkles", …)`) gets a new variant that takes a `View` instead of a `String` symbol name, so it can host the mark.

### D-08 — `accentGlow` becomes magenta `#F0506E`

Glow shadows on AI-moment elements (currently indigo) become magenta — warmer halo that reads from the gradient. Trust-signal icons (`TrustSignalViews.swift`) inherit the same warm glow.

## Token Map (Old → New)

| Token | Old | New |
|---|---|---|
| `surfaceBase` (dark) | `#000000` | `#0A0A18` |
| `surfaceCard` (dark) | `#0F0F0F` | `#15172B` |
| `surfaceSlot` (dark) | `#0F0F0F` | `#15172B` |
| `surfaceElevated` (dark) | `#0F0F0F` | `#15172B` |
| `surfaceBase` (light) | `#FBFBFC` | `#FBFBFC` *(unchanged)* |
| `surfaceCard` (light) | `#FFFFFF` | `#FFFFFF` *(unchanged)* |
| `accentAction` | `#5856D6` indigo | `#6F2DBD` violet |
| `accentWaveform` | `#5856D6` | `#6F2DBD` |
| `accentAI` (flat) | `#A7C957` lime | `#F0506E` magenta |
| `accentAIGradientStops` (NEW) | — | `[#FF4E50, #F9A66C, #F0506E, #6F2DBD]` |
| `accentGlow` | `#5856D6` | `#F0506E` magenta |
| `trustIcon` | `#5856D6` | `#6F2DBD` violet |
| `accentGradientEnd` | `#AF52DE` | `#6F2DBD` *(aligns mesh-gradient end with new violet)* |
| `textPrimary`, `textSecondary` | unchanged | unchanged |
| `surfaceGlass` | unchanged | unchanged |

## File Inventory

### New files

```
SonicMerge/DesignSystem/SmartCutMark.swift          NEW — SwiftUI view, 3 size presets, gradient + monochrome modes
SonicMerge/Assets.xcassets/SmartCutTabIcon.imageset/  NEW — pre-rendered 1×/2×/3× PNGs for the tab bar
  Contents.json
  SmartCutTabIcon.png       (66×66 — 1× would be 22pt × 1×, but iOS renders @2x/@3x; ship 22, 44, 66)
  SmartCutTabIcon@2x.png
  SmartCutTabIcon@3x.png
SonicMerge/Assets.xcassets/AppIcon.appiconset/      MODIFIED
  AppIcon-1024.png          NEW (light/any appearance)
  AppIcon-1024-Dark.png     NEW (dark appearance)
  AppIcon-1024-Tinted.png   NEW (tinted appearance — grayscale source for iOS to tint)
```

### Modified files

```
SonicMerge/DesignSystem/SonicMergeTheme.swift                       — palette primitives
SonicMerge/DesignSystem/SonicMergeTheme+Appearance.swift            — semantic resolver, NEW slot accentAIGradientStops
SonicMerge/App/RootTabView.swift:55                                 — Label(systemImage:) → Image asset
SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift:67   — sparkles → SmartCutMark(size: .splash)
SonicMerge/Features/SmartCut/Views/Home/SmartCutSessionView.swift:136 — sparkles → SmartCutMark(size: .toolbar)
SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift:182, 243 — sparkles → SmartCutMark(.toolbar / .hero)
SonicMerge/Features/Onboarding/OnboardingFlow.swift:159, 169, 193, 412 — sparkles → SmartCutMark + FeaturePill variant
SonicMerge/DesignSystem/PremiumBackground.swift                     — corner gradient inputs (token-driven; no math change)
SonicMerge/DesignSystem/PillButtonStyle.swift                       — comments only (lime → magenta refs)
SonicMerge/Assets.xcassets/AppIcon.appiconset/Contents.json         — wire up the 3 1024×1024 PNGs
```

### Asset generation strategy

We will NOT hand-design the icon PNGs in a vector editor. Instead, we ship a **headless SwiftUI render** invoked by a one-shot `xcrun swift run` script (`Scripts/RenderSmartCutAppIcon.swift`) that:
1. Uses `ImageRenderer` (SwiftUI iOS 16+ / macOS 13+) on the same `SmartCutMark` SwiftUI view.
2. Renders at 1024×1024 with `#0A0A18` background, full-bleed.
3. Saves to `SonicMerge/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`.
4. Re-runs with monochrome variants for `-Dark` (white-on-dark stays the same) and `-Tinted` (full grayscale gradient).

Single source of truth — the same view drives both in-app rendering and the app icon. If we tweak the glyph later, one change updates everything. The script is committed to git but only re-run when the mark itself changes; the resulting PNGs are also committed.

## Architecture / Data Flow

The rebrand is a leaf change — no data flow changes, no new SwiftData models, no service touchpoints. The only structural change is the introduction of `accentAIGradientStops` on `SonicMergeSemantic`, which is read via `@Environment(\.sonicMergeSemantic)` exactly like every other token today.

```
SonicMergeApp
└─ RootTabView (resolves SonicMergeSemantic from ThemePreference)
   └─ Environment(\.sonicMergeSemantic, …) injected once
      └─ All views read tokens including new accentAIGradientStops
         └─ SmartCutMark (new) — used at 8 callsites + onboarding
```

## Testing

This change is visual; the existing test suite covers behavior, not pixel output. Test additions:

1. **`SmartCutMarkTests`** (Swift Testing, new file) — assert the view renders without crashing at each `Size`, both with and without `monochromeTint`. One snapshot test using `ImageRenderer` capturing a 96pt render to verify gradient stops appear in the rendered output (assert non-trivial pixel diversity in the bar regions).

2. **`SonicMergeSemanticTests`** (existing pattern, extend) — assert that `resolved(colorScheme: .dark, preference: .dark).accentAIGradientStops.count == 4` and that the first/last stops match `#FF4E50` and `#6F2DBD`.

3. **`ThemeMigrationTests`** — re-run; existing `migrateLegacyTheme` logic is unchanged but verify nothing about the migration depends on specific color values.

4. **Manual QA checklist** at `docs/superpowers/qa/2026-05-04-cleancut-rebrand-manual-qa.md` covering:
   - Tab bar renders the new mark at correct size in both selected/unselected states
   - Onboarding step 1 hero shows the new mark + new gradient
   - Smart Cut "Apply Cuts" CTA renders gradient correctly
   - AI Orb idle state shows the new mark
   - App icon shows on Home screen at all sizes after fresh install

5. **Baseline:** `FAIL=5` expected on `main` per CLAUDE.md. The rebrand must not exceed this. Watch for `testThemeRoundTrip*` regressions.

## Rollout / Risk

- **Risk: tab-bar gradient rendering.** UIKit may flatten the asset to a tint color. Mitigation: ship the asset set with `Render As: Original Image` so the gradient survives.
- **Risk: low-contrast violet on dark navy.** `#6F2DBD` on `#0A0A18` clears WCAG AA for large text (>4.5:1) but is borderline for body text. We're using violet for chrome (selection, CTAs) where it sits on lighter surfaces — never as body text. Verify with the `Color Contrast` Xcode preview check.
- **Risk: app-icon caching.** iOS caches app icons aggressively. After replacing the PNGs, a fresh install on the simulator is needed to verify; the QA checklist calls this out.
- **No backwards-compatibility shims needed.** The `accentAI` semantic role is unchanged (still "AI moments"); only the color it returns flips. Lime-green specific test assertions (none in the current test suite, verified by grep) would be the one place requiring updates.

## Open Questions

None — auto-mode direction A is unambiguous on color and icon. Light-mode app-icon variant uses the same dark canvas (D-03), which I've made an explicit decision rather than asking; if the user wants a light-canvas variant we can revisit in a follow-up.
