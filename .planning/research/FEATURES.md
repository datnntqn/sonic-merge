# Feature Research — v1.1 Modern Spatial Utility Restyle

**Domain:** iOS audio utility app — visual identity restyle (no functional changes to ViewModels or services)
**Researched:** 2026-04-11
**Confidence:** MEDIUM-HIGH — design patterns verified via competitor app inspection, SwiftUI API docs, and codebase review; complexity estimates grounded in actual source files

---

## Scope

Visual restyle features only (milestone v1.1). Functional features (import, mixing, denoising, export, MVVM) are already built and must not change. The project constraint is explicit: no ViewModel or service changes — restyle only.

Reference apps studied: Ferrite Recording Studio (v3, 2024–2025), Dark Noise (OLED dark mode benchmark), Capo (chord detection, dark mode follow-through), Logic Remote (professional audio dark interface), Apple Music, Halide, Darkroom.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist in a polished 2025 iOS app. Missing or broken means the product feels incomplete regardless of any new feature — a partial restyle with broken dark mode or inconsistent corners is worse than no restyle.

| Feature | Why Expected | Complexity | Existing Code Touch Points |
|---------|--------------|------------|---------------------------|
| **Design system token layer** | Every polished 2025 iOS app (Ferrite, Dark Noise, Halide) uses semantic tokens. Raw hex values in views force grep-and-replace for every future theme change. Inconsistent tokens make a restyle look like a patchwork job. | LOW | `SonicMergeTheme.swift` + `SonicMergeTheme+Appearance.swift` — `SonicMergeSemantic` struct already exists and is injected via environment. Restyle extends the existing token set: add `accentAI`, `glassOverlay`, `timelineLine` tokens. Do not rewrite the architecture — extend it. |
| **Full light/dark mode correctness across all screens** | iOS has enforced dark mode since iOS 13. Users switch appearances and expect zero broken colors. An uncovered view (e.g., a hardcoded white background in `CleaningLabView.staleBanner`) destroys credibility. | LOW | `SonicMergeSemantic` resolves via `ColorScheme` environment. `staleBanner` in `CleaningLabView.swift` currently hardcodes `Color(red: 1.0, green: 0.88, blue: 0.6)` — this breaks in dark mode. Every hardcoded color must be tokenized. |
| **Consistent squircle corner radius (24pt continuous)** | iOS system UI uses `style: .continuous` (superellipse) everywhere from app icons to sheets. Non-continuous corners are detectable to trained iOS eyes. Dark Noise sound tiles and Ferrite v3 clip cards both use large-radius continuous corners. | LOW | `SonicMergeTheme.Radius.card = 12` (current). Change to `24`. Single constant — propagates to `ClipCardView`, `MergeTimelineView.mergeOutputCard`, `CleaningLabView` waveform section, `GapRowView`, `TrustSignalViews.LocalFirstTrustStrip`, `ExportProgressSheet`. |
| **Shadow elevation system (resting + lifted)** | Ad-hoc `shadow(radius:)` values create visual noise. Every view currently uses different shadow parameters: `ClipCardView` uses `radius: 8, y: 3`; `onDeviceAIHero` uses `radius: 6, y: 2`; `LocalFirstTrustStrip` uses `radius: 10, y: 4`. Coherent depth requires two named tokens. | LOW | Create `SonicMergeTheme.Shadow.cardResting` and `.cardLifted` in `SonicMergeTheme.swift`. Add a `.shadowElevation(_ token:)` `ViewModifier` so all cards reference the same tokens. All five card-like components need updating. |
| **Dark mode: pure black #000000 background** | Premium OLED apps (Halide, Capo, Apollo before shutdown, Ivory) use true `#000000` dark backgrounds. Current `darkConveyor()` uses charcoal `#11141A`. The target spec is `#000000`. Per-pixel OLED savings are a real user benefit on iPhone X and later. | LOW | `SonicMergeTheme+Appearance.swift` `darkConveyor()` — change `surfaceBase` from charcoal to `UIColor.black`. Ripples to all views via `semantic.surfaceBase` — no individual view changes needed. |
| **Haptic feedback on all primary buttons** | iOS 17 `.sensoryFeedback` is a one-line SwiftUI modifier. Apps without haptics on CTAs feel unresponsive in 2025. Logic Remote, Ferrite, and Capo all use haptics on transport controls and mode changes. | LOW | `CleaningLabViewModel` already fires haptics on A/B toggle. Remaining surfaces without haptics: Export button in `MixingStationView`, Import button, denoiseActionButton in `CleaningLabView`, drag-lift in `MergeSlotRow`. Add `.sensoryFeedback(.impact, trigger: ...)` at each call site. |
| **Reduced Motion compliance** | App Store accessibility review has flagged continuous animations that ignore `accessibilityReduceMotion` since 2023. The AI Orb is the highest-risk element. This is non-negotiable for review. | LOW | Add `@Environment(\.accessibilityReduceMotion) private var reduceMotion` to any view with `withAnimation(.repeatForever(...))`. Guard the AI Orb pulse, drag shadow spring, and any future `TimelineView`-driven animation behind `if !reduceMotion`. No existing code to modify — must be built into new animated components from day one. |
| **Typography: no third-party fonts** | SF Pro is tuned for Dynamic Type, VoiceOver, and all accessibility sizes. Third-party fonts introduce App Store review friction, font loading overhead, and license compliance risk. The aesthetic is achieved through color, depth, and shape — not font replacement. | LOW | Use `Font.system(.body, design: .rounded)` for display labels and section headers only (already in use in `MergeTimelineView` and `MixingStationView` empty state). All body, metadata text stays at `.system` default. Zero new font assets. |

---

### Differentiators (Competitive Advantage)

Features that make SonicMerge v1.1 visually distinct from generic audio utility apps. Each adds meaningful depth without touching the audio pipeline or ViewModels. Ranked by user impact / implementation complexity ratio.

| Feature | Value Proposition | Complexity | Existing Code Touch Points |
|---------|-------------------|------------|---------------------------|
| **Deep Indigo + Lime Green color palette (dark mode)** | No competitor in the iOS audio utility space (Ferrite, Voice Record Pro, TapeRecorder) uses Deep Indigo as primary accent. Combined with Lime Green for AI-specific elements, this creates a unique, immediately recognizable brand color. Dark Noise uses custom colors as brand identity — this follows the same playbook. | LOW | `darkConveyor()` in `SonicMergeTheme+Appearance.swift`. Change `accentAction` from neon-mint `#2FEBA0` to Deep Indigo `#5856D6`. Add new `accentAI: UIColor` token set to Lime Green `#A7C957` for AI Orb, Cleaning Lab intensity slider thumb, and denoise progress. `accentWaveform` in dark mode should be set to `#5856D6` (indigo) to match the mesh gradient direction. |
| **Glassmorphism trust strip + navigation header** | Apple's Liquid Glass material (WWDC 2025) validates frosted-glass as the forward-looking iOS design vocabulary. The `LocalFirstTrustStrip` ("Private by Design" banner) is the first content element users see in the Mixing Station — making it a glass card with an indigo glow reinforces the privacy brand at first glance. Logic Remote uses blurred header bars; this extends the pattern to content cards. | MEDIUM | `TrustSignalViews.LocalFirstTrustStrip` — replace `.background(Color(uiColor: semantic.surfaceElevated))` with `.background(.ultraThinMaterial)` + `Color(uiColor: semantic.accentAction).opacity(0.08)` color wash overlay. Add `shadow(color: Color(uiColor: semantic.accentAction).opacity(0.3), radius: 12)` indigo ambient glow. Navigation bar glassmorphism is free via `.toolbarBackground(.ultraThinMaterial, for: .navigationBar)` in `MixingStationView` and `CleaningLabView`. |
| **Pill buttons with inner glow** | Apple Intelligence UI (iOS 18.1+) established glowing pill buttons as a premium pattern. Current buttons in `CleaningLabView.denoiseActionButton` and `MixingStationView.emptyState` use `RoundedRectangle(cornerRadius: 12)` — upgrading to `Capsule` with inner glow overlay transforms every primary CTA from utilitarian to premium. Darkroom and Bear use this same pattern. | LOW | Three call sites: `CleaningLabView.denoiseActionButton`, `MixingStationView.emptyState` import button, `MergeTimelineView.mergeOutputCard` export button. Pattern: replace `.clipShape(RoundedRectangle(cornerRadius: 12))` with `.clipShape(Capsule())`. Add `.overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))` for inner glow. Add `shadow(color: accentAction.opacity(0.4), radius: 10)` outer ambient. On press: `scaleEffect(0.96)` + `.sensoryFeedback(.impact)`. Encapsulate in a single `PillButtonStyle` `ButtonStyle` struct. |
| **Mesh gradient waveform bars (Deep Indigo → Purple)** | Every competitor (Ferrite, TapeRecorder, Voice Memos) uses a single flat color for waveform bars. A `LinearGradient` fill (Deep Indigo → Purple → transparent) — upgrading to `MeshGradient` on iOS 18 — makes each audio card feel visually distinctive and premium. The waveform is the identity of each clip; making it gradient reinforces that identity. | MEDIUM | `WaveformThumbnailView` in `ClipCardView.swift` (Canvas draw loop) and `WaveformCanvasView` in `CleaningLabView.swift`. Currently: `context.fill(path, with: .color(accentBlue))`. Change to: `context.fill(path, with: .linearGradient(Gradient(colors: [Color(hex: "#5856D6").opacity(0.9), Color(hex: "#A042D4").opacity(0.5)]), startPoint: .init(x: 0, y: 0), endPoint: .init(x: 0, y: 1)))`. For iOS 18: wrap in `#available(iOS 18, *)` and upgrade to `MeshGradient` with 3×3 grid and animated color stops (indigo → purple → transparent). Fallback (`LinearGradient`) must be visually acceptable as the primary path for iOS 17 devices. |
| **AI Orb visualizer (pulsating nebula sphere)** | No iOS audio utility competitor has an animated AI identity element. Moises.ai and similar tools use animated gradient blobs for their AI brand — SonicMerge's AI Orb is the equivalent native iOS pattern. Transforms the flat `Image(systemName: "cpu")` in `CleaningLabView.onDeviceAIHero` into a living visual that communicates "AI is actively processing." Significant brand differentiation in this market. | HIGH | `CleaningLabView.onDeviceAIHero` is the replacement target — currently a plain `HStack` with a system icon. New `AIOrb` view: `ZStack` of three concentric `Circle` views. Outer: `scale(1.0→1.18)` + `opacity(0.3→0.0)`. Middle: `scale(1.0→1.09)` + `opacity(0.5→0.2)`. Core: static `RadialGradient` fill `#5856D6` → `#A042D4`. Animate with `withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true))` at staggered `.delay(0.3)` offsets. Animate ONLY when `viewModel.isProcessing == true`. Stop animation in idle state — always-on animation causes GPU contention with `AVAudioEngine`. Must guard with `accessibilityReduceMotion`. |
| **Vertical timeline connecting line** | GarageBand, Ferrite, and Reaper all use a visual track lane or timeline spine to communicate audio sequencing. The Mixing Station's List of clips currently reads as a generic to-do list. A 2pt Deep Indigo vertical line connecting card midpoints communicates "these clips play in order" without adding UI chrome. Functional-aesthetic pattern unique to purpose-built audio tools. | MEDIUM-HIGH | `MergeTimelineView.swift` currently uses `List` with `.onMove`. A connecting line requires knowing each row's vertical position. Two approaches: (A) Keep `List`, overlay a `ZStack` connector using `GeometryReader` + `PreferenceKey` to track row Y-offsets — complex but preserves `List` drag handle. (B) Migrate to `ScrollView + LazyVStack` with custom drag gesture — higher drag complexity but simpler connector geometry. **Approach A is recommended to avoid rewriting drag-reorder.** Risk: `List` section insets may make vertical alignment math imprecise. |
| **Elevated drag shadow with spring animation** | Things 3, Craft, and Ferrite all visually elevate the "held" card during drag reorder — scale increases slightly, shadow deepens. This micro-interaction communicates physical weight and distinguishes premium list implementations from default `List` drag handles. Current drag uses default `editMode` handle with no card-level feedback. | MEDIUM | `MergeSlotRow.swift` (called from `MergeTimelineView`). Add `@State private var isDragging = false`. On drag start: `withAnimation(.easeOut(duration: 0.15)) { scale = 1.03; shadowToken = .cardLifted }`. On drop: `withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { scale = 1.0; shadowToken = .cardResting }`. Note: iOS 17 `DragGesture.Value` does not expose velocity (added in iOS 26). Use fixed spring parameters — do not attempt velocity-based damping. |

---

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Full-screen animated mesh gradient background** | Looks impressive in mockups. Makes the "spatial" aesthetic feel immersive. | `MeshGradient` animation is GPU-intensive per frame. Full-screen animation on A15 and older devices causes thermal throttling — degrading `AVAudioEngine` audio processing performance simultaneously. Also iOS 18 only, excluding all iOS 17 users. | Mesh gradient scoped to waveform bars inside cards only, gated with `#available(iOS 18, *)`. Full-screen background stays pure `#000000` / `#FBFBFC`. Zero GPU cost, maximum contrast. |
| **Always-on AI Orb animation** | A constantly pulsating orb looks premium in screenshots. | An always-running `repeatForever` animation fires continuous GPU tasks alongside `AVAudioEngine` processing. This has been reported to cause audio buffer dropouts on constrained A-series devices where GPU/CPU/Neural Engine share a power budget. Animation also loses semantic meaning when it runs all the time. | Animate the orb only when `viewModel.isProcessing == true`. Show a static, non-animated orb in idle state. The animation carries more impact when reserved for the active AI state. |
| **Glassmorphism on every card (glass cards)** | Extends the glass language from header to all cards. Looks cohesive in Figma. | Glass cards require live blur compositing behind every card in the scroll view. On a Mixing Station list with 10+ clips, N simultaneous `blur()` layers cause visible jank on iPhone 12 and earlier. Apple's own HIG explicitly warns against overusing materials. NN/G research confirms glassmorphism at this density reduces readability. | Reserve `.ultraThinMaterial` for the sticky header and trust strip only. Audio cards use semi-opaque solid fills. Contrast between glass header and solid cards reinforces depth hierarchy. |
| **Particle system / floating blobs in background** | "Spatial" aesthetic seen in visionOS concept demos. Popular on Dribbble. | Requires SpriteKit or `CAEmitterLayer` UIKit bridge (non-native). Constant CPU load. No semantic relationship to audio workflow. Competes with audio visualization for GPU budget. | Deep Indigo on pure black achieves spatial aesthetic at zero performance cost. |
| **Custom third-party display font** | Creates typographic brand differentiation. | SF Pro is tuned for Dynamic Type, VoiceOver, and accessibility across all sizes. Third-party fonts introduce: load overhead at launch, Dynamic Type breakage at larger accessibility sizes, VoiceOver label mismatches, and App Store review friction if license is not correctly embedded. The restyle aesthetic is expressed through color, depth, and shape. | `Font.system(.body, design: .rounded)` for display headings (SF Pro Rounded — built-in, zero overhead, passes all checks). Everything else stays at `.system` default. |
| **Per-clip unique color coding** | Makes timeline feel dynamic. Users can identify clips without reading names. | Requires persistent color state keyed to clip identity, clash detection, and the visual problem of color reassignment on reorder. This is a ViewModel concern — the restyle prohibits ViewModel changes. | Visual variation comes from waveform shape (driven by actual audio amplitude data already stored in sidecar files) and clip duration. No arbitrary color assignment needed. |
| **Metal shader AI Orb (this milestone)** | Metal shaders produce genuinely organic, non-repeating visual noise — more premium than CSS-style concentric circles. | Metal shader + `AVAudioEngine` simultaneously can cause resource contention. Shipping Metal effects before validating Tier 1 stability creates two unknowns. Metal MSL also adds a new test surface and build complexity. | Ship Tier 1 (SwiftUI concentric circles) in v1.1. Evaluate Metal upgrade in a focused v1.2 pass after audio regression testing confirms no GPU contention. |
| **Neumorphism (embossed shadows)** | Tactile aesthetic popular 2020–2022. | Systematically fails WCAG contrast requirements. Apple HIG explicitly discourages it. Considered dated by 2024. | Elevated directional shadows (`y: 4`) on solid card fills communicate depth without contrast failures. |

---

## Feature Dependencies

```
[SonicMergeSemantic token system (v2 extended)]  ← Phase 1 — must ship first
    └──required-by──> [Pure Black + Deep Indigo dark mode]
    └──required-by──> [Lime Green accentAI token]
    └──required-by──> [Glassmorphism trust strip + nav header]
    └──required-by──> [Pill buttons inner glow]
    └──required-by──> [Mesh gradient waveforms]
    └──required-by──> [AI Orb visualizer]
    └──required-by──> [Elevated drag shadow tokens]

[Squircle 24pt cards]  ← Phase 1
    └──required-by──> [Mesh gradient waveforms]   (gradient fills inside the card clip shape)
    └──required-by──> [Elevated drag shadow]       (shadow attached to card container)

[Shadow elevation tokens (cardResting / cardLifted)]
    └──required-by──> [Elevated drag shadow spring animation]

[Pill buttons inner glow]
    └──must-ship-with──> [.sensoryFeedback haptics]   (visual scale + haptic desync is perceptible if split)

[Mesh gradient waveforms]
    └──conflicts-with──> [iOS 17 deployment target]
        └──resolution──> [#available(iOS 18, *) guard + LinearGradient fallback — mandatory]

[AI Orb visualizer (Tier 1)]
    └──requires──> [accessibilityReduceMotion guard — built-in from start, not retrofit]
    └──requires──> [animation active only when viewModel.isProcessing == true]
    └──replaces──> [CleaningLabView.onDeviceAIHero HStack]
    └──enhanced-by──> [Lime Green accentAI token]

[AI Orb Tier 2 Metal shader]
    └──requires──> [Tier 1 confirmed stable with no audio processing regressions]
    └──deferred-to──> [v1.2 or later]

[Vertical timeline connecting line]
    └──may-require──> [List → ScrollView + LazyVStack migration]
    └──conflicts-with──> [List.onMove drag reorder if migrated to LazyVStack]  — evaluate Approach A first

[Reduced Motion compliance]
    └──gates──> [AI Orb pulse animation]
    └──gates──> [Elevated drag shadow spring animation]
    └──gates──> [any future TimelineView-driven animation]
```

### Dependency Notes

- **Token system extends first, replaces never.** `SonicMergeSemantic` already exists and is environment-injected. The restyle adds new tokens (`accentAI`, `glassOverlay`, `timelineLine`) and updates existing color values. Never replace the struct — only extend it. This keeps all existing views functional during incremental restyle phases.
- **Squircle cards before mesh gradients.** The gradient is applied as a fill inside the card's clip shape. Card shape definition must exist before styling its fill.
- **Mesh gradient requires `#available(iOS 18, *)` guard — non-negotiable.** `MeshGradient` is iOS 18+ per Apple Developer Documentation (confirmed, HIGH confidence). Shipping without the guard causes a runtime crash on iOS 17. Design the `LinearGradient` fallback as the primary path; treat `MeshGradient` as progressive enhancement.
- **AI Orb animation must be state-gated from day one.** A `repeatForever` animation that is never stopped keeps the GPU active indefinitely. Gate with `viewModel.isProcessing`. Do not build the Orb as always-on and then try to conditionally stop it — SwiftUI `repeatForever` animations are difficult to stop cleanly mid-cycle.
- **Haptic + visual press state must ship together.** The `scaleEffect(0.96)` press animation and `.sensoryFeedback` must live in the same `ButtonStyle.body(configuration:)` closure. Splitting them creates a perceptible desync.
- **Vertical timeline line decision is gated on approach.** If Approach A (`List` + `PreferenceKey` Y-offset tracking) proves geometrically imprecise after a prototype pass, migrating to `ScrollView + LazyVStack` must include a complete drag-reorder replacement — significant scope increase. This feature should be prototyped first and descoped to v1.2 if the `List` approach proves unmaintainable.

---

## MVP Definition for v1.1 Restyle

A partial restyle that leaves views in the old style is worse than no restyle — visual seams destroy credibility. MVP is the minimum that achieves a coherent new identity across all existing screens.

### Launch With (v1.1)

- [ ] **Token system v2** (new colors + tokens) — foundation; everything else references this
- [ ] **Pure black + Deep Indigo dark mode** — 4 color value changes in `darkConveyor()`; zero risk
- [ ] **Squircle 24pt cards** — single constant change in `SonicMergeTheme.Radius`; ripples everywhere
- [ ] **Shadow elevation tokens + ViewModifier** — replaces 5 ad-hoc `shadow()` calls across views
- [ ] **Pill buttons + inner glow + `.sensoryFeedback`** — `PillButtonStyle` applied to 3 call sites
- [ ] **Fix hardcoded colors** — `staleBanner` in `CleaningLabView` must be tokenized; other hardcoded values
- [ ] **Glassmorphism trust strip + nav header** — `.ultraThinMaterial` on `LocalFirstTrustStrip` + `.toolbarBackground` on navigation bars
- [ ] **Mesh gradient waveforms with `#available(iOS 18, *)` fallback** — `WaveformThumbnailView` and `WaveformCanvasView`
- [ ] **Haptic feedback on all primary CTAs** — `.sensoryFeedback` at Export, Import, Denoise, drag events
- [ ] **Reduced Motion compliance on all animated components** — `accessibilityReduceMotion` guard in every `repeatForever` animation

### Add After Validation (v1.x)

- [ ] **AI Orb visualizer (Tier 1 SwiftUI)** — High visual impact but high complexity. Warrants its own phase after token foundation is stable. Trigger: v1.1 ships without App Store review issues.
- [ ] **Vertical timeline connecting line** — Prototype Approach A (List + PreferenceKey). If clean, ship in v1.x. If messy, defer.

### Future Consideration (v2+)

- [ ] **AI Orb Tier 2 Metal shader** — Only after Tier 1 stable with confirmed no audio regression
- [ ] **Animated mesh gradient background** — Only if iOS 18 adoption makes the iOS 17 fallback path negligible and GPU budget is confirmed safe
- [ ] **Elevated drag shadow** — Nice-to-have micro-interaction; can ship independently once P1 features are stable

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Token system v2 | HIGH | LOW | P1 |
| Pure black + Deep Indigo dark mode | HIGH | LOW | P1 |
| Squircle 24pt cards | HIGH | LOW | P1 |
| Fix hardcoded colors (e.g., staleBanner) | HIGH | LOW | P1 |
| Shadow elevation system | MEDIUM | LOW | P1 |
| Pill buttons + glow + haptics | HIGH | LOW | P1 |
| Nav header glassmorphism | MEDIUM | LOW | P1 |
| Trust strip glassmorphism | HIGH | MEDIUM | P1 |
| Mesh gradient waveforms + iOS 17 fallback | HIGH | MEDIUM | P1 |
| Reduced Motion compliance | HIGH | LOW | P1 |
| AI Orb Tier 1 (SwiftUI circles) | HIGH | HIGH | P2 |
| Vertical timeline connecting line | MEDIUM | HIGH | P2 |
| Elevated drag shadow | MEDIUM | MEDIUM | P2 |
| AI Orb Tier 2 (Metal shader) | MEDIUM | HIGH | P3 |
| Animated mesh gradient background | LOW | HIGH | P3 |

**Priority key:**
- P1: Must ship in v1.1 — omitting creates a visually incomplete or inconsistent restyle
- P2: High value; phase separately after P1 is proven stable
- P3: Defer — unknown user value, high risk, or iOS 17 compat constraints

---

## Competitor Feature Analysis

Direct visual pattern comparison across premium iOS audio and utility apps.

| Visual Pattern | Ferrite Recording Studio | Dark Noise | Capo | Logic Remote | SonicMerge v1.1 Target |
|----------------|--------------------------|------------|------|--------------|------------------------|
| Dark mode background | Dark grey (#1C1C1E) | **Pure black #000000 OLED** — benchmark | System dark (near-black) | **Pure black, dark slate accents** | Pure `#000000` — matches Logic Remote / Dark Noise standard |
| Card corners | ~12pt rounded rect | ~20pt continuous | System list style | Flat panels, minimal radius | **24pt `.continuous` squircle** — most expressive in the set |
| Header treatment | Plain navigation bar | System nav bar + blur | System nav bar | Plain dark bar | **`.ultraThinMaterial` + Deep Indigo glow** — unique in this set |
| Primary button | Standard rounded rect | Capsule fills (sound tiles) | Standard system buttons | Capsule transport controls | **Capsule + inner glow + haptic** — matches Logic Remote register |
| AI / processing indicator | None | None | Auto-chord spinner | None | **Pulsating nebula orb** — unique differentiator in this market |
| Accent color | Teal/green | No specific accent (neutral) | System blue | Standard grey/white | **Deep Indigo #5856D6 primary, Lime Green #A7C957 AI** — unique palette |
| Timeline / list layout | Horizontal track lanes | Sound tile grid | Horizontal scrolling timeline | Horizontal mixer | **Vertical timeline with connecting line** — matches DAW conceptual model |
| Waveform fill | **Green linear gradient** on dark | No waveforms | Waveform with chord markers (no gradient) | No waveform display | **Mesh gradient (iOS 18) / Deep Indigo linear (iOS 17)** — most premium in set |
| Haptics | Transport controls only | Sound tile selection | Minimal | Heavy — transport + controls | **All CTAs + drag lift/drop** — matches Logic Remote standard |

---

## What Makes Premium vs Gimmicky — Synthesis

From reference app analysis and 2025 iOS design patterns:

**Premium signals (use these):**
- Restraint: glassmorphism on 1–2 surface layers only (header, trust strip). Cards use solid fills.
- Motion with purpose: AI Orb pulses because AI is "thinking." The animation communicates state, not decoration. Stop it when idle.
- Material depth: use system materials (`.ultraThinMaterial`) — they automatically adapt to dark/light and are accessibility-tested by Apple.
- Haptics matched to visual weight: `heavy` for destructive delete, `light` for toggle, `selection` for picker segments.
- Consistent rhythm: one card radius (24pt), two shadow tokens, one button shape (Capsule) — coherence is what reads "designed."

**Gimmick signals (avoid these):**
- Continuous background animation with no state meaning — particles, shifting gradients on idle screens.
- Glassmorphism on every surface — readability collapses and GPU load spikes during scroll.
- Orb/blob animations that do not pause on Reduce Motion — accessibility review flag and App Store rejection risk.
- Pure decorative shadow layers that hit compositing budget without adding depth information.
- Custom nav transitions fighting UIKit — breaks accessibility and VoiceOver.

---

## Sources

- Ferrite Recording Studio (App Store, v3, 2024–2025 design): https://apps.apple.com/us/app/ferrite-recording-studio/id1018780185
- Dark Noise (OLED dark mode reference): https://darknoise.app/releases.html
- Capo (dark mode follow-through, iOS 13+): https://apps.apple.com/us/app/capo-learn-music-by-ear/id887497388
- Apple HIG — Dark Mode: https://developer.apple.com/design/human-interface-guidelines/dark-mode
- Apple HIG — Reduced Motion (App Store accessibility): https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria/
- Apple Developer Documentation — MeshGradient (iOS 18+): https://developer.apple.com/documentation/swiftui/meshgradient
- Donny Wals — Mesh Gradients in SwiftUI (iOS 18 availability confirmed): https://www.donnywals.com/getting-started-with-mesh-gradients-on-ios-18/
- SwiftUI sensoryFeedback modifier (iOS 17): https://useyourloaf.com/blog/swiftui-sensory-feedback/
- Apple Intelligence glow effect pattern: https://livsycode.com/swiftui/an-apple-intelligence-style-glow-effect-in-swiftui/
- iOS 2025 design trends — spatial / micro-interaction: https://medium.com/@bhumibhuva18/the-ios-ui-trends-actually-winning-in-2025-9d6372757f7a
- Glassmorphism best practices (NN/G): https://www.nngroup.com/articles/glassmorphism/
- Apple Liquid Glass (WWDC 2025 design language): https://www.everydayux.net/glassmorphism-apple-liquid-glass-interface-design/
- SwiftUI squircle continuous corner style: https://medium.com/@zvyom/parametric-corner-smoothing-in-swiftui-108acea52874

---

*Feature research for: SonicMerge v1.1 Modern Spatial Utility UI Restyle*
*Researched: 2026-04-11*
