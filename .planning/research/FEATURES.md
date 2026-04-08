# Feature Research

**Domain:** Modern Spatial Utility UI Restyle — iOS audio app (SwiftUI, iOS 17+)
**Researched:** 2026-04-08
**Confidence:** HIGH (SwiftUI APIs verified against Apple developer docs, WWDC sessions, and current community sources)

---

## Scope Note

This file covers **visual restyle features only** (milestone v1.1). Functional features (import, mixing, denoising, export) were researched in the prior milestone and remain unchanged in scope. The project constraint is explicit: no ViewModel or service changes — restyle only.

---

## Feature Landscape

### Table Stakes (Users Expect These)

These are non-negotiable for the restyle to feel complete. Missing any one of them makes "Modern Spatial Utility" feel inconsistent or half-assembled. A partial restyle is worse than no restyle — uncovered views reveal the seam.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Design system token layer (Color + Spacing + Radius + Shadow) | Every polished 2025 iOS app uses semantic tokens. Raw hex values in views signal unfinished work and make future theme changes require a grep-and-replace across every file. | LOW | Single `DesignSystem` enum with nested `Color`, `Spacing`, `Radius`, `Shadow` namespaces. Colors stored in `Assets.xcassets` as color sets with Any Appearance and Dark Appearance slots — SwiftUI auto-resolves at runtime. **Must ship first. All other features reference these tokens.** |
| Full light/dark mode adaptive colors | iOS has system-enforced dark mode since iOS 13. Users switch system appearance and expect zero broken or unreadable colors. | LOW | Every token resolves through `Assets.xcassets` color sets. No hardcoded hex in views. Verify in both appearances before shipping any single screen. |
| Squircle card shape with continuous corner radius | iOS system UI uses `style: .continuous` (superellipse) corner rounding everywhere from app icons to alerts. Non-continuous rounded corners look visually "off" to trained iOS eyes — it is immediately detectable. | LOW | `RoundedRectangle(cornerRadius: 24, style: .continuous)` — built-in SwiftUI primitive, no custom `Shape` implementation needed. Zero performance overhead vs standard rounded rectangle. Consistent 24pt radius across all audio cards. |
| Shadow elevation system (resting + lifted states) | Cards and interactive elements need coherent depth layering. Ad-hoc `shadow(radius:)` values produce visual noise and make the UI look unintentional. | LOW | Two named shadow tokens: `cardResting` (radius 8, y-offset 2, opacity 0.12) and `cardLifted` (radius 20, y-offset 8, opacity 0.22). Applied via a `.shadowElevation(_ token:)` ViewModifier so every card uses the same shadow language. |
| Dark mode: pure black background | Premium iOS apps (Halide, Apollo, Ivory) use `#000000` on OLED screens. Users on OLED iPhones expect true black pixels for battery savings and visual premium feel. Mid-grey dark backgrounds signal a hasty implementation. | LOW | `Color(.systemBackground)` resolves to a near-black in dark mode, not `#000000`. Must use an explicit token: `backgroundPrimary` = `#000000` (dark) / `#FBFBFC` (light). |
| Haptic feedback on all primary button taps | iOS 17 introduced `.sensoryFeedback` as a one-line SwiftUI modifier. In 2025, apps without haptics feel unresponsive. The bar is set by every first-party Apple app. | LOW | `.sensoryFeedback(.impact, trigger: isPressed)` on export, add clip, toggle denoise, and any destructive action. No UIKit bridge needed on iOS 17+. |
| Consistent type hierarchy using SF Pro system font | Design restyls that swap in a third-party font introduce Dynamic Type breakage, accessibility failures, and App Store review friction. The "spatial utility" look is achieved with color, shape, and depth — not typography replacement. | LOW | Use `SF Pro Rounded` (`Font.system(.body, design: .rounded)`) for display headings only. All body, metadata, and UI label text stays at `.system` default. |

---

### Differentiators (Competitive Advantage)

These features make SonicMerge v1.1 visually distinct from generic iOS utility apps. Each adds meaningful depth without adding architectural complexity. They are what transforms "restyled" into "premium."

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Glassmorphism header with Deep Indigo glow | Creates visual "float" — the header appears to hover above scrolling content. Signals spatial depth and premium build quality. Apple's Liquid Glass design language (introduced WWDC 2025) validates this direction as the forward-looking iOS aesthetic. | MEDIUM | `ZStack`: (1) `.background(.ultraThinMaterial)` for the blur layer, (2) `Color(hex: "#5856D6").opacity(0.12)` as a glow wash, (3) bottom-edge `Divider` colored `Color.white.opacity(0.08)`. Do NOT use `UIBlurEffect` directly — `.ultraThinMaterial` is the correct SwiftUI primitive and auto-adapts to light/dark. Applies to sticky navigation header in both Mixing Station and Cleaning Lab. |
| Vertical Timeline Hybrid layout with connecting line | Audio editors (GarageBand, Ferrite) use vertical timeline metaphors. A central connecting line communicates sequence and ordering in a way a plain `List` cannot. Makes the Mixing Station feel like a purpose-built audio tool, not a to-do list. | MEDIUM | `ZStack` with a 2pt wide `Rectangle` connecting line running vertically through card connection points inside a `VStack`. Line color: `accentIndigo.opacity(0.4)`. Filled 6pt circle node at each card's midpoint connection. Complexity is in precise vertical alignment math to match circle nodes with card centers — not in API difficulty. The underlying `List` with `.onMove` drag-reorder remains unchanged. |
| Mesh gradient waveform on audio cards | Static linear gradient waveforms exist in every competitor. A `MeshGradient`-backed waveform fill (Deep Indigo → Purple → transparent) makes each card feel unique and visually rich. | HIGH | `MeshGradient` requires **iOS 18** minimum (confirmed: Apple Developer Documentation, WWDC24). Project minimum is iOS 17.0. **Mandatory `#available(iOS 18, *)` gate** with `LinearGradient(colors: [Color("accentIndigo").opacity(0.6), Color("purple").opacity(0.3), .clear])` fallback for iOS 17. Waveform bar shapes drawn with `Path` or `HStack` of `Rectangle`, gradient applied as `.fill`. Do not use this as a full-screen background — performance cost is acceptable only at card scale. |
| Pill buttons with inner glow | Adds physical depth to flat capsule shapes. The glow communicates "pressable surface" without requiring a border or drop shadow. Feels more tactile than a flat fill. Industry pattern in premium iOS apps (Darkroom, Bear, Notion). | LOW | Two-layer button overlay: (1) base `Capsule` fill at `accentIndigo`, (2) inner glow `Capsule` stroke `Color.white.opacity(0.25)` at 1pt width inset 1pt from edge, (3) outer ambient shadow `accentIndigo.opacity(0.35)` radius 12. On press: `scaleEffect(0.96)` + `.sensoryFeedback(.impact)`. Implemented as a single `ButtonStyle` struct — applied once, used everywhere. |
| AI Orb visualizer (pulsating nebula sphere) | Signals "AI is actively working" with a distinctive, iconic visual. Transforms a progress state into a branded moment. Differentiates noise reduction from a plain progress spinner or percentage label. Sets the emotional context: sophisticated on-device intelligence. | HIGH | **Tier 1 (this milestone):** Three concentric `Circle` views, each animated with `withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true))` at staggered delays. Outer circle: `scale(1.0→1.12)` + `opacity(0.3→0.0)`. Middle circle: `scale(1.0→1.06)` + `opacity(0.6→0.3)`. Core circle: static, radial gradient fill `accentIndigo` → `purple`. No Metal dependency. Animate **only while denoise is actively processing** — stop animation when idle to avoid unnecessary GPU work during audio export. **Tier 2 (future):** Metal `layerEffect` shader using MSL for organic noise/turbulence distortion. Defer until Tier 1 is stable. |
| Elevated drag shadow on card reorder | When a user lifts a card, shadow depth increases and card scales up slightly. On release, spring animation snaps it back. Micro-interaction that signals "this card is in my hand." Distinguishes premium list implementations from standard `List` drag behavior. | LOW | `DragGesture.onChanged`: `withAnimation(.easeOut(duration: 0.15)) { shadowToken = .cardLifted; scale = 1.03 }`. `DragGesture.onEnded`: `withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { shadowToken = .cardResting; scale = 1.0 }`. Note: iOS 17 `DragGesture.Value` does not expose gesture velocity (this was added in iOS 26 / Xcode 26). Use fixed spring parameters — do not attempt velocity-based spring damping on iOS 17. |

---

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Full-screen animated mesh gradient background | Looks impressive in mockups. Makes the entire screen feel "alive." | `MeshGradient` animation is GPU-intensive per frame. On A15 and older devices, full-screen mesh animation at 60fps causes thermal throttling — directly degrading AVAudioEngine's audio processing performance. Also requires iOS 18, excluding iOS 17 users entirely. | Use mesh gradient as a static fill scoped to individual audio card backgrounds only, gated with `#available(iOS 18, *)`. Full-screen background stays pure `#000000` (dark) / `#FBFBFC` (light). Zero GPU cost. |
| Always-on AI Orb animation | A constantly pulsating orb looks premium in screenshots and demo videos. | An always-running `repeatForever` animation that fires concurrent GPU tasks alongside AVAudioEngine processing has been shown to cause audio buffer dropouts on constrained devices. The animation has no semantic meaning when not processing. | Animate the orb only while `isDenoising == true`. Show a static, non-animated orb or the "Hold to Listen Original" button in idle state. Animation carries more impact when reserved for active states. |
| AI Orb Tier 2 Metal shader (this milestone) | Metal shaders produce genuinely organic, non-repeating visual noise — more premium than CSS-style concentric circle animations. | Metal shader + AVAudioEngine simultaneously can cause resource contention on A-series devices with shared GPU/CPU/Neural Engine budgets. Shipping Metal effects before validating Tier 1 stability creates two unknowns at once. Metal MSL also adds build complexity and a new test surface. | Ship Tier 1 (SwiftUI concentric circles) for v1.1. Upgrade to Metal shader in a focused v1.2 pass after stability is confirmed. |
| Custom third-party display font | Creates typographic personality and brand differentiation. | SF Pro is Apple's system font, tuned for all weights, optical sizes, Dynamic Type, and accessibility across every device. Custom fonts introduce: font loading overhead at launch, potential Dynamic Type size breakage, VoiceOver label mismatches, and App Store review friction if the font license is not correctly embedded. The "spatial utility" aesthetic is expressed through color, depth, and shape — not typography. | Use `Font.system(.largeTitle, design: .rounded)` for display headings (SF Pro Rounded is free, built-in, passes all accessibility checks). All other text stays at `.system` default. |
| Per-clip unique color coding | Makes the timeline feel dynamic and personalized. Users can identify clips at a glance without reading filenames. | Requires persistent color state keyed to clip identity, color clash detection, and the visual problem of what happens when clips are reordered (do colors follow the clip or stay positional?). This is a ViewModel concern — and the restyle explicitly prohibits ViewModel changes. | All cards use the same gradient fill (mesh or linear fallback). Visual variation comes from waveform shape (driven by actual audio data) and clip duration, not arbitrary color assignment. |
| Particle system / star field background | Creates "space" aesthetic. Seen in some visionOS concept demos. Popular on Dribbble. | Requires SpriteKit or `CAEmitterLayer` UIKit bridge. Adds a non-native framework dependency. Has no semantic relationship to audio work. CPU load is non-trivial. Competes with actual audio visualization for GPU budget. | Deep Indigo accent + pure black background achieves spatial aesthetic at zero performance cost. Particle effects belong in visionOS, not on a utilitarian iPhone audio tool. |
| Blurred translucent cards (glass cards, not just glass header) | Extends the glassmorphism language from header to every card. Looks cohesive in design tools. | Glass cards require live-blur compositing behind every card in the scroll view. This is significantly more expensive than a header blur (which is static). On a long Mixing Station list, N cards blurring simultaneously causes visible jank on older devices. Apple's own HIG warns against overusing materials. | Reserve `.ultraThinMaterial` for the sticky header only. Audio cards use semi-opaque solid fills with the mesh gradient / linear gradient waveform. The contrast between solid cards and the glass header reinforces the depth hierarchy. |

---

## Feature Dependencies

```
[Design System Tokens]  ← must ship first
    └──required-by──> [Light/Dark Mode Colors]
    └──required-by──> [Squircle Cards (24pt continuous radius)]
    └──required-by──> [Shadow Elevation System]
    └──required-by──> [Pill Buttons with Inner Glow]
    └──required-by──> [Glassmorphism Header]
    └──required-by──> [Vertical Timeline Layout]
    └──required-by──> [Mesh Gradient Waveforms]
    └──required-by──> [AI Orb Visualizer]

[Squircle Cards]
    └──required-by──> [Mesh Gradient Waveforms]   (gradient fills the card background layer)
    └──required-by──> [Elevated Drag Shadow]      (shadow applied to the card container view)

[Shadow Elevation System]
    └──required-by──> [Elevated Drag Shadow]      (animation swaps between named shadow tokens)

[Haptic Feedback (.sensoryFeedback)]
    └──enhances──> [Pill Buttons with Inner Glow] (visual scale + haptic must be implemented together)
    └──enhances──> [Elevated Drag Shadow]          (drag-start triggers haptic alongside shadow change)

[Mesh Gradient Waveforms]
    └──conflicts-with──> [iOS 17 deployment target]
        └──resolution──> [#available(iOS 18, *) guard + LinearGradient fallback]

[AI Orb Tier 2 Metal Shader]
    └──requires──> [AI Orb Tier 1 stability confirmed]
    └──deferred-to──> [v1.2 or later]

[Vertical Timeline Connecting Line]
    └──enhances──> [Squircle Cards]  (line connects card midpoints; cards must exist first)

[Glassmorphism Header]
    └──independent-of──> [Card-level features]  (header is a separate view layer)
```

### Dependency Notes

- **Design system tokens must ship first.** Every other visual feature references color, radius, and shadow tokens. Without this foundation, components use ad-hoc values that require a second cleanup pass. This is the mandatory Phase 1 of the restyle.
- **Squircle cards before mesh gradients.** The mesh gradient (or linear fallback) is applied as a background layer inside the card shape clip. The card shape definition must exist before styling its fill.
- **Shadow elevation tokens before elevated drag.** The drag interaction animates between two named shadow tokens (`cardResting` / `cardLifted`). The token struct must exist before the animation references it.
- **Mesh gradient requires `#available(iOS 18, *)` guard — this is non-negotiable.** `MeshGradient` is iOS 18+ only per Apple Developer Documentation. Shipping without the guard causes a runtime crash on iOS 17 devices. The fallback `LinearGradient` must be visually acceptable — design for the fallback first, treat mesh as progressive enhancement.
- **Haptic + visual press state must be implemented together.** Splitting the `scaleEffect(0.96)` press animation from `.sensoryFeedback` into separate code paths creates perceptible desynchronization. Both live in the same `ButtonStyle` `body(configuration:)` closure.
- **AI Orb animation must stop when idle.** A `repeatForever` SwiftUI animation that is never stopped keeps GPU work alive indefinitely. Gate the animation with an `isDenoising` state flag. When `false`, show a static orb state.

---

## MVP Definition

This is a visual restyle milestone. "MVP" means the minimum set of visual changes that achieves a coherent "Modern Spatial Utility" look across all existing screens without leaving any view in the old style.

### Launch With (v1.1 restyle complete)

- [ ] Design system tokens (Color + Radius + Spacing + Shadow) — foundation, everything else references this
- [ ] Light/dark mode color pairs for all tokens — no appearance-switching breaks
- [ ] Squircle cards with `style: .continuous`, 24pt radius — visual identity anchor
- [ ] Shadow elevation system (resting + lifted tokens) — coherent depth language
- [ ] Pill buttons with inner glow + `.sensoryFeedback` haptics — primary actions feel premium
- [ ] Glassmorphism header (`.ultraThinMaterial` + Deep Indigo glow wash) — spatial depth on entry
- [ ] Vertical Timeline layout with connecting line — Mixing Station signature layout
- [ ] Elevated drag shadow + spring animation on card reorder — micro-interaction completeness
- [ ] AI Orb visualizer, Tier 1 SwiftUI concentric circles — Cleaning Lab hero element (animated during processing only)
- [ ] Mesh gradient waveforms with `#available(iOS 18, *)` guard + `LinearGradient` fallback — visual richness where supported, no crash on iOS 17

### Add After Validation (v1.x)

- [ ] AI Orb Tier 2 Metal shader — only after Tier 1 ships stable with no audio processing regressions. Separate focused phase.
- [ ] Per-card animated mesh gradient (subtle idle loop) — only if iOS 18 adoption metrics show the iOS 17 fallback path is rarely hit and GPU budget is confirmed safe.

### Future Consideration (v2+)

- [ ] SF Pro Rounded body text — only if a full brand refresh justifies touching typography system-wide
- [ ] visionOS adaptation — real depth via RealityKit, Liquid Glass materials natively supported; different platform, different phase

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Design system tokens | HIGH | LOW | P1 |
| Light/dark mode colors | HIGH | LOW | P1 |
| Squircle cards | HIGH | LOW | P1 |
| Shadow elevation system | MEDIUM | LOW | P1 |
| Pill buttons + inner glow + haptics | HIGH | LOW | P1 |
| Glassmorphism header | HIGH | MEDIUM | P1 |
| Vertical Timeline layout + connecting line | HIGH | MEDIUM | P1 |
| Elevated drag shadow + spring animation | MEDIUM | LOW | P1 |
| AI Orb Tier 1 (SwiftUI concentric circles) | HIGH | MEDIUM | P1 |
| Mesh gradient waveforms + iOS 17 fallback | MEDIUM | MEDIUM | P1 |
| AI Orb Tier 2 (Metal shader) | LOW | HIGH | P3 |
| Animated mesh gradient background | LOW | HIGH | P3 |
| Custom font system | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Must have for restyle launch — omitting creates an incomplete or inconsistent aesthetic
- P2: Should have, add when possible
- P3: Nice to have, future consideration

---

## Competitor Feature Analysis

Visual pattern survey of premium iOS utility and audio apps.

| Visual Pattern | Halide (camera) | Darkroom (photo) | Ferrite Recording Studio | Our Approach |
|---------------|-----------------|-----------------|--------------------------|--------------|
| Dark mode background | True `#000000` OLED | Near-black, not pure | Dark grey (#1C1C1E) | Pure `#000000` token in dark mode |
| Card shape | Continuous corner, ~12pt | Continuous corner, ~16pt | Standard rounded rect | Continuous corner, 24pt (more spacious for audio metadata) |
| Header treatment | Blurred sticky header, tinted | Blurred, minimal | Plain navigation bar | `.ultraThinMaterial` + Deep Indigo glow; sticky |
| Primary button | Capsule, vibrant fill | Capsule, muted | Rounded rectangle | Capsule with inner glow + `.sensoryFeedback` |
| AI / processing indicator | N/A | Radial progress ring | Progress bar | Pulsating nebula orb (Tier 1 SwiftUI) |
| Color palette | Amber accent on black | Muted neutrals + orange | Teal/green | Deep Indigo #5856D6 + Lime Green #A7C957 (AI accent) |
| Timeline / list layout | N/A | Grid | Linear scrolling list | Vertical timeline with connecting line |
| Waveform fill | N/A | Linear gradient | Blue linear gradient | Mesh gradient (iOS 18+) / Linear gradient fallback (iOS 17) |
| Haptics | Every interaction | Primary interactions | Minimal | All primary actions + drag lift/drop |

---

## Sources

- Apple Developer Documentation — MeshGradient availability (iOS 18+): https://developer.apple.com/documentation/swiftui/meshgradient
- Apple WWDC24 — Create custom visual effects with SwiftUI (Metal shaders / layerEffect): https://developer.apple.com/videos/play/wwdc2024/10151/
- Donny Wals — Mesh Gradients in SwiftUI (iOS 18 availability confirmed): https://www.donnywals.com/getting-started-with-mesh-gradients-on-ios-18/
- NilCoalescing — Mesh Gradients in SwiftUI (grid definition, iOS 18 only): https://nilcoalescing.com/blog/MeshGradientsInSwiftUI/
- Hacking with Swift — Inferno Metal shader library (orb/glass effects): https://github.com/twostraws/Inferno
- Hacking with Swift — Metal shaders as SwiftUI layer effects (iOS 17 API): https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-metal-shaders-to-swiftui-views-using-layer-effects
- Design+Code — SwiftUI Material background blur (.ultraThinMaterial): https://designcode.io/swiftui-handbook-background-blur/
- Design+Code — Clip Shape and Smooth Corners (continuous corner radius): https://designcode.io/swiftui-handbook-clip-shape-and-smooth-corners/
- DEV Community — Micro-Interactions in SwiftUI (elevated card shadow, spring animation): https://dev.to/sebastienlato/micro-interactions-in-swiftui-subtle-animations-that-make-apps-feel-premium-2ldn
- DEV Community — SwiftUI Design Tokens & Theming System: https://dev.to/sebastienlato/swiftui-design-tokens-theming-system-production-scale-b16
- Hacking with Swift — .sensoryFeedback haptic modifier (iOS 17): https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-haptic-effects-using-sensory-feedback
- Medium — Dark Glassmorphism as dominant iOS aesthetic 2026: https://medium.com/@developer_89726/dark-glassmorphism-the-aesthetic-that-will-define-ui-in-2026-93aa4153088f
- EveryDayUX — Apple Liquid Glass design language (WWDC 2025): https://www.everydayux.net/glassmorphism-apple-liquid-glass-interface-design/

---

*Feature research for: SonicMerge v1.1 Modern Spatial Utility UI Restyle*
*Researched: 2026-04-08*
