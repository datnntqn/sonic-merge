# Pitfalls Research

**Domain:** iOS SwiftUI visual restyle — glassmorphism, mesh gradients, design tokens, animated orbs
**Milestone:** v1.1 Modern Spatial Utility Restyle
**Researched:** 2026-04-11
**Confidence:** HIGH (verified against Apple Developer Documentation, WWDC sessions, community post-mortems, and official API availability tables)

> **Scope note:** This document covers pitfalls specific to the v1.1 UI restyle milestone. For audio pipeline pitfalls (AVFoundation, AVAudioEngine, Share Extension), see the v1.0 research archive.

---

## iOS 17 vs iOS 18 API Availability Matrix

This is the single most important reference for the entire milestone. The app targets iOS 17.0+. Any API in the "iOS 18+" row requires an `@available` guard and a fallback implementation.

| API / Feature | Min iOS | Status for SonicMerge | Action Required |
|---|---|---|---|
| `MeshGradient` | iOS 18.0 | BLOCKED on iOS 17 | Must implement fallback — see Pitfall 1 |
| `.ultraThinMaterial`, `.thinMaterial` | iOS 15.0 | Available | Safe to use directly |
| `RoundedRectangle(cornerRadius:style:.continuous)` | iOS 13.0 | Available | Safe to use — this is the squircle |
| `TimelineView` | iOS 15.0 | Available | Safe to use |
| `Canvas` | iOS 15.0 | Available | Preferred for waveform rendering |
| `@Observable` (Observation framework) | iOS 17.0 | Available | Safe to use |
| `accessibilityReduceMotion` env value | iOS 13.0 | Available | Must check in all animated views |
| `accessibilityReduceTransparency` env value | iOS 13.0 | Available | Must check in glassmorphism views |
| `colorSchemeContrast` env value | iOS 13.0 | Available | Must check for high-contrast users |
| `UIImpactFeedbackGenerator` | iOS 10.0 | Available | Safe to use |
| `sensoryFeedback(_:trigger:)` modifier | iOS 17.0 | Available | Preferred over direct UIKit feedback |
| Liquid Glass materials | iOS 26.0 | Out of scope | Do not use — too new |

---

## Critical Pitfalls

### Pitfall 1: MeshGradient Is iOS 18-Only — Used on an iOS 17 Target

**What goes wrong:**
`MeshGradient` is introduced in iOS 18 (WWDC 2024). SonicMerge targets iOS 17.0+. Referencing `MeshGradient` without an `@available(iOS 18, *)` guard will cause the app to crash on any device running iOS 17. Because this is a restyle milestone, developers focus on visual output and may not notice until a TestFlight user on iOS 17 files a crash report. This affects the "mesh gradient waveform" feature on audio cards and any background gradient usage.

**Why it happens:**
Xcode autocomplete suggests `MeshGradient` and the compiler does not error if the project deployment target is iOS 17 but strict availability checks are turned off. Previews and simulators default to the latest OS, so the crash never appears during development — only on real devices running iOS 17.

**How to avoid:**
Every usage of `MeshGradient` must be wrapped:

```swift
@ViewBuilder
func waveformBackground() -> some View {
    if #available(iOS 18, *) {
        MeshGradient(
            width: 3, height: 3,
            points: [...],
            colors: [.indigo, .purple, ...]
        )
    } else {
        // iOS 17 fallback: angular or linear gradient approximation
        LinearGradient(
            colors: [Color(hex: "#5856D6"), Color(hex: "#7B68EE")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .opacity(0.8)
    }
}
```

The iOS 17 fallback should use a `LinearGradient` or `AngularGradient` with the same Deep Indigo to Purple color range. It won't be as fluid but maintains the visual identity.

**Warning signs:**
- Xcode does not flag `MeshGradient` without `@available` unless the "Swift Strict Concurrency" level or "Upcoming Features" flags are set
- Previews always show the gradient correctly because Canvas preview uses current OS
- TestFlight crash: `EXC_BAD_INSTRUCTION` or `dyld: Symbol not found: _$s7SwiftUI12MeshGradientV`

**Phase to address:** Design system phase (first phase) — before any audio card or waveform component is built. Establish the `@available` wrapper pattern as a design system primitive.

---

### Pitfall 2: Glassmorphism Without Accessibility Fallbacks — Invisible Text for Users

**What goes wrong:**
`.ultraThinMaterial` blurs the content behind the view and makes the glass surface semi-transparent. This is visually appealing when the background is a neutral color. However:
1. When the user enables **Reduce Transparency** in Settings > Accessibility, the blur is disabled system-wide and materials render as flat, often low-contrast solids. If the text color was chosen to contrast against the blurred background, it may have near-zero contrast against the fallback flat color.
2. When the user enables **Increase Contrast** in Settings > Accessibility, foreground colors shift and any "glow" effect on text or icons may disappear entirely or produce visual noise.
3. Glassmorphic elements over a deep background (e.g., the "Private by Design" banner over the dark header) can drop below the WCAG 4.5:1 contrast minimum for body text even in normal mode.

**Why it happens:**
Developers test glassmorphism visually in Simulator against a static background. They never toggle Reduce Transparency. The material looks fine in development but the accessibility fallback is never designed.

**How to avoid:**
Check `accessibilityReduceTransparency` in every view that uses a material:

```swift
@Environment(\.accessibilityReduceTransparency) var reduceTransparency

var body: some View {
    ZStack {
        if reduceTransparency {
            // Solid, high-contrast fallback
            Color(hex: "#1A1A2E")
                .opacity(0.95)
        } else {
            Rectangle()
                .fill(.ultraThinMaterial)
        }
        content
    }
}
```

Run the Accessibility Inspector against every glassmorphic component. Aim for 4.5:1 contrast ratio minimum in both material and reduced transparency states.

**Warning signs:**
- Label contrast ratio below 4.5:1 when checked in Accessibility Inspector
- UI test screenshots look washed out on high-contrast devices
- User feedback: "I can't read the header text"

**Phase to address:** Design system phase — establish the `reduceTransparency` modifier pattern as part of the glass card component definition before any screen uses it.

---

### Pitfall 3: Multiple Blur Layers Compound GPU Cost — Frame Drops on iPhone 12 and Older

**What goes wrong:**
`.ultraThinMaterial` renders a real-time blur of the content behind the view. Each material view adds a blur pass to the GPU pipeline. If the Mixing Station screen has: a glassmorphic header (one blur), each audio card with a semi-transparent background (N blurs for N cards), and a floating action button with a material background (one blur), the GPU is running 5–10 simultaneous blur passes. On A14 and older chips (iPhone 12 and earlier), this causes visible frame drops during scroll, particularly when combined with any concurrent animation (drag reorder shadows, gradient animations).

**Why it happens:**
Materials look cheap in Simulator because the simulator uses the Mac GPU. Developers do not test on physical devices until late in the phase.

**How to avoid:**
- Limit blur layers to 2 per screen — one structural (header), one interactive (cards if dragging)
- Use a single opaque card background for the list items. Only the header and active-drag card need real blur
- When `accessibilityReduceTransparency` is active, remove all blur passes automatically (free optimization + accessibility win)
- Test on physical devices — specifically iPhone 12 or older — in each sprint, not just at phase end
- Use Instruments → Core Animation → "Offscreen Rendered" overlay to identify GPU-heavy blur pass accumulation

**Performance budget:** Maximum 2 simultaneous active `.material` backgrounds on any single screen. Drag interaction may add a third temporarily.

**Warning signs:**
- Instruments shows sustained GPU > 70% during normal scrolling
- Frame counter drops below 55fps on iPhone 12 during scroll of a 5-card list
- "Offscreen Rendered" overlay in Simulator Debug > Color Offscreen-Rendered shows orange for all list cells

**Phase to address:** Design system phase — establish the rule as a constraint on the glass card component. Card backgrounds default to semi-transparent solid color, not `.material`, unless actively being dragged.

---

### Pitfall 4: AI Orb Animation Overloads the Main Thread With Multiple Concurrent Animations

**What goes wrong:**
The AI Orb visualizer for the Cleaning Lab is described as a "pulsating nebula sphere" — implying multiple concurrent animations: scale pulsing, color cycling, rotation, glow radius oscillation, and possibly a particle/noise layer. Each `withAnimation` or `.animation` modifier in SwiftUI triggers view diffs and layout recalculation every frame. Running 4+ simultaneous `withAnimation` loops (each on `.easeInOut(duration: 1.5).repeatForever()`) can produce visible stutter on mid-range devices because SwiftUI's diffing cost per frame compounds.

**Why it happens:**
Each layer of the orb is built as a separate SwiftUI view with its own animation modifier. Developers layer circle overlays, gradients, and blur effects independently. The combined update cost is only discovered when all layers run simultaneously.

**How to avoid:**
Use `Canvas` or `TimelineView` for the orb instead of stacked SwiftUI views:

```swift
// Preferred: Single Canvas render pass — no per-layer SwiftUI diffing
TimelineView(.animation) { timeline in
    Canvas { context, size in
        let t = timeline.date.timeIntervalSinceReferenceDate
        // Draw all orb layers in a single Metal-backed pass
        drawOrbLayers(context: context, size: size, time: t)
    }
}
```

This collapses N SwiftUI view updates into one Canvas draw call per frame, which is Metal-backed and far cheaper than N separate `@State` animation loops. Use `drawingGroup()` if Canvas is not feasible, as it composites to a single off-screen Metal texture before display.

Respect `accessibilityReduceMotion` — when enabled, show a static version of the orb with no animation:

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

var orbView: some View {
    if reduceMotion {
        StaticOrbView()
    } else {
        AnimatedOrbView()
    }
}
```

**Warning signs:**
- Instruments shows main thread CPU > 40% with just the orb running and no audio processing
- Animation stutters when the user scrolls any overlapping scroll view
- Frame rate drops below 55fps on iPhone 12 during AI processing state

**Phase to address:** Cleaning Lab restyle phase — build the orb as a `TimelineView + Canvas` component from day one rather than refactoring from stacked views.

---

### Pitfall 5: Design Token Color System Accidentally Shadows SwiftUI's Built-In Colors

**What goes wrong:**
When you define a `Color` extension with names like `.primary`, `.secondary`, `.background`, or `.accent`, you shadow SwiftUI's built-in semantic colors. Any developer who types `Color.background` expecting the system adaptive color now gets your token instead. This creates silent visual inconsistencies: components that previously used system semantic colors (native sheets, alerts, context menus) pick up the wrong token, and the bug is invisible until switching color schemes or devices.

Furthermore, SwiftUI's `ShapeStyle` hierarchy means `Color.myToken.secondary` compiles correctly even if `.secondary` is not defined in your token set — it silently falls through to SwiftUI's own `.secondary` modifier, which multiplies opacity rather than using a distinct token.

**Why it happens:**
Token systems often use common names (primary, secondary, background, surface) that collide with SwiftUI built-ins. The compiler does not warn about shadowing. Developers discover the issue when a system component renders with the wrong color mid-milestone.

**How to avoid:**
Use a namespaced token approach — never put tokens directly on `Color`:

```swift
// WRONG — shadows SwiftUI's Color.primary
extension Color {
    static let primary = Color(hex: "#5856D6")
}

// CORRECT — namespaced, no collision
extension Color {
    enum Token {
        static let accent = Color(hex: "#5856D6")
        static let aiHighlight = Color(hex: "#A7C957")
        static let surfaceDark = Color(hex: "#000000")
        static let surfaceLight = Color(hex: "#FBFBFC")
    }
}
// Usage: Color.Token.accent — unambiguous, cannot shadow system colors
```

Alternatively, use a `Theme` struct with `@Environment` injection, which provides type safety and theme-switching capability.

**Warning signs:**
- System alerts appear with unexpected background or text colors
- `.foregroundStyle(.secondary)` renders differently than expected after design system is installed
- `Color.primary` in Xcode autocomplete resolves to your custom color rather than the system semantic

**Phase to address:** Design system phase — first thing. The token naming strategy must be established before any component uses colors.

---

### Pitfall 6: Drag Shadow Causes Off-Screen Render Pass — Drops to 30fps During List Reorder

**What goes wrong:**
Adding `shadow(radius:)` to a view that is being dragged (via `.onDrag` or a custom drag gesture) triggers an off-screen render pass for every frame of the drag. On ProMotion devices, this means 120 off-screen composites per second. On non-ProMotion devices, shadow rendering still causes consistent frame budget overruns when combined with the animation of sibling rows rearranging during the drag.

The specific issue: `shadow()` in SwiftUI uses `Core Graphics` drop shadow, which requires the view to be rendered to an off-screen buffer, the shadow to be blurred separately, then composited. This happens every frame during animation.

**Why it happens:**
Shadow on static views is not visually noticeable as a performance issue. Developers add shadow to the "elevated drag state" and test it with a slow drag on the latest device. Only during fast reorder animations on older hardware does the problem manifest.

**How to avoid:**
Use the `background` layer shadow technique instead of `shadow()` on the view itself:

```swift
// WRONG — triggers off-screen composite every frame
audioCard
    .shadow(color: .black.opacity(0.3), radius: 12, y: 6)

// CORRECT — shadow on background shape, view clips within it
audioCard
    .background(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.Token.surfaceDark)
            .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
    )
```

Using `background` with a shape avoids the global off-screen pass. The shadow is composited with the background geometry, not the entire view tree.

For the drag-elevated state specifically, use a conditional shadow that only activates when dragging — not on every cell at rest:

```swift
.background(
    RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(cardColor)
        .shadow(color: .black.opacity(isDragging ? 0.4 : 0.1),
                radius: isDragging ? 20 : 6,
                y: isDragging ? 10 : 3)
)
```

**Warning signs:**
- Instruments → Core Animation → "Color Offscreen-Rendered" shows orange on every list cell
- `UIKit FPS` drops during drag on iPhone 12
- Drag animation feels "sticky" or inconsistent in speed

**Phase to address:** Mixing Station layout phase (audio card component) — establish the shadow pattern in the card component before building drag behavior.

---

### Pitfall 7: Haptic Feedback on Every Interaction Feels Mechanical, Not Premium

**What goes wrong:**
Adding `UIImpactFeedbackGenerator` or `sensoryFeedback` to every button tap, slider change, and toggle produces a constant mechanical buzz that users associate with cheap apps, not premium ones. The design intent is "haptic-responsive button states," but overuse destroys the premium perception the restyle is trying to create. Additionally, haptic feedback fires even when the action has no visible consequence (e.g., pressing a disabled button, triggering a no-op state transition), which violates Apple's HIG guidance.

**Why it happens:**
Adding haptics is a one-liner in SwiftUI — developers add it everywhere during a "make it feel polished" pass without considering semantic appropriateness. Each feature gets haptics independently, and the aggregate is only felt at integration time.

**How to avoid:**
Reserve haptics for semantically meaningful moments only:

| Action | Haptic | Type |
|--------|--------|------|
| Button press that triggers navigation | Yes | `.light` |
| Drag reorder "snap" to new position | Yes | `.medium` |
| AI processing started | Yes | `.medium` (one shot) |
| AI processing completed | Yes | `.success` notification |
| Slider value change (continuous) | No | Creates continuous buzz |
| Toggle switch state change | Yes | `.light` (system default) |
| Audio card delete confirm | Yes | `.warning` notification |
| Scroll position changes | No | Too frequent |
| Every button tap regardless of state | No | Mechanical overuse |

Use SwiftUI's `sensoryFeedback(_:trigger:)` modifier (iOS 17+) rather than direct `UIImpactFeedbackGenerator` calls — it is automatically suppressed when the device has haptics disabled or when the user has enabled "Reduce Motion."

**Warning signs:**
- QA tester reports "the whole app buzzes" during normal use
- Haptic fires on tapping disabled buttons
- Haptic fires on the same gesture multiple times due to state propagation

**Phase to address:** Interactive states phase — review all haptic triggers as a group after individual components are built, not per-component during development.

---

### Pitfall 8: Continuous Corner Radius (`clipShape`) Triggers Off-Screen Rendering on Complex Nested Views

**What goes wrong:**
`clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))` clips the view, which requires an off-screen render pass for any view with complex subviews (gradients, blur, shadows). When applied to the entire audio card (which contains a waveform Canvas, metadata labels, and a blur background), the clip triggers a composite of the full card hierarchy every frame — even when the card is static.

**Why it happens:**
`clipShape` works by masking the composited output of the view. For views with materials or shadows, this forces an off-screen composite pass. The `.continuous` style is visually superior (true Apple squircle) but has the same compositing cost as `.circular`.

**How to avoid:**
Use `background` with a shaped fill instead of `clipShape` for the card container:

```swift
// WRONG — clips complex hierarchy, forces off-screen composite
audioCard
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

// CORRECT — shape is on the background, not a clip
audioCard
    .background(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(cardBackgroundColor)
    )
```

If rounded corners are needed on an image inside the card, use `clipShape` only on the image itself — not the entire card.

Reserve `clipShape` for simple views (images, single-layer shapes). For compositionally complex cards, use background shapes.

**Warning signs:**
- Instruments → Core Animation shows "Offscreen Rendered" on all list cells during scroll
- "Color Offscreen-Rendered" overlay (yellow/orange) covers every card

**Phase to address:** Design system / card component phase — establish this pattern in the base card component before adding content to it.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Skip `@available` guard on `MeshGradient` | Faster to write | App crashes on iOS 17 (35%+ of installed base) | Never |
| Use `clipShape` on all cards uniformly | Simpler code | Off-screen render pass on every card | Never — use background shape instead |
| Hardcode hex colors instead of tokens | Fast iteration | Cannot switch dark/light, impossible to maintain | Only in throwaway prototypes |
| Shadow on every card at rest | Premium look | GPU cost during list scroll | Never — shadow only on dragging state |
| Haptics on every button | Feels polished in isolation | Feels mechanical in aggregate | Never for continuous interactions |
| Ignore `reduceTransparency` | Simpler component | Fails accessibility, potential App Store rejection for accessibility issues | Never |
| Ignore `reduceMotion` on orb | Simpler orb code | Causes nausea for vestibular users — accessibility failure | Never |
| Use stacked SwiftUI views for orb layers | Easier to build | Frame drops on A14 and older during AI processing | Only for static preview/prototype |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Multiple `.material` layers in a List | Scroll drops to 40fps on iPhone 12 | Max 2 blur layers per screen; cells use solid backgrounds | 4+ cells visible simultaneously |
| `shadow()` on dragged view | Drag animation stutters at fast swipe speed | Use `background` shape with shadow instead of view-level shadow | Any drag on iPhone 12/older |
| 4+ concurrent `withAnimation` loops in orb | CPU > 40% idle, stutter during scroll | Use `TimelineView + Canvas` for orb | On any device with orb + active processing |
| `MeshGradient` animated per frame on every audio card | Thermal throttle within 2 minutes on iPhone 12 | `MeshGradient` is iOS 18 only (fallback to `LinearGradient`); never animate per-card | More than 3 cards visible |
| `clipShape` on complex material views | Offscreen render on every cell in list | Use `background` shape, not `clipShape` on cards | Always — triggered on render, not at scale |
| Waveform rendered with SwiftUI `Path` per sample | Scroll hitches with long audio files | Use `Canvas` with downsampled waveform data | Files > 30 seconds long |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Glassmorphism with insufficient contrast | Unreadable text for all users, inaccessible for low-vision users | Test 4.5:1 contrast ratio on every text over glass surface |
| Lime Green (#A7C957) AI highlights in light mode | Too bright on off-white, causes visual fatigue | Use a slightly desaturated variant in light mode; reserve full-saturation for dark mode |
| Pure black (#000000) background with bright accents | Can cause halation on OLED for some users | True black is correct for OLED; pair with muted (not maximum contrast) accents |
| Pulsating orb during audio processing with no progress indicator | User cannot tell how long processing will take | Orb animation indicates activity, but add a duration estimate or progress bar alongside it |
| Haptics on drag reorder fired too aggressively | Medium haptic on every pixel of movement | Haptic only at "snap" point when card crosses threshold into new position |
| Design token names matching role (e.g., "surfaceElevated") but applied inconsistently | Screens look visually inconsistent | Token documentation with visual examples; enforce via code review |

---

## Accessibility Pitfalls

### Reduce Motion — Every Animated View Must Respond

`@Environment(\.accessibilityReduceMotion)` must be checked in:
- AI Orb (provide static state)
- Drag shadow transition (use instant state change, no spring animation)
- Pill button press states (immediate fill change vs. spring bounce)
- Any gradient animation or color-cycle animation

Apple's HIG states: "Don't animate the change of a view to a new state when reduced motion is active." This is not optional — it is an accessibility requirement.

### Reduce Transparency — Glass Must Have a Solid Fallback

`@Environment(\.accessibilityReduceTransparency)` must be checked in:
- Glassmorphism header
- Any card with `.material` background
- Floating action buttons with material surfaces

Fallback must be a solid color with minimum 4.5:1 contrast ratio against the foreground text.

### Dynamic Type — Token Typography Must Scale

All font sizes in the design system must use `Font.system(.body)` (or appropriate text style) rather than fixed `Font.system(size: 14)`. Fixed sizes do not scale with Dynamic Type. The "Modern Spatial Utility" aesthetic frequently uses fixed-size decorative text — these must remain decorative and not carry essential information.

---

## "Looks Done But Isn't" Checklist

- [ ] **MeshGradient:** `@available(iOS 18, *)` guard present — test on an iOS 17 simulator to verify fallback renders correctly, not blank
- [ ] **Glassmorphism:** `reduceTransparency` path tested with Settings > Accessibility > Reduce Transparency enabled — no text is unreadable
- [ ] **AI Orb:** `reduceMotion` path renders a static orb — tested with Settings > Accessibility > Reduce Motion enabled
- [ ] **Design tokens:** No `Color.primary` / `Color.secondary` / `Color.background` direct extensions — verify via `grep "static let primary" Color` finds zero results in token files
- [ ] **Haptics:** All haptic calls reviewed as a group — no continuous-trigger haptics (slider value change, scroll)
- [ ] **Drag shadow:** `Offscreen Rendered` overlay in Simulator shows no orange on resting list cells — only on the actively dragged cell
- [ ] **Dark mode:** Every screen tested in both modes — no hardcoded color literals in any view file (`grep "#[0-9A-Fa-f]{6}" Sources/` finds zero results in view files)
- [ ] **Waveform rendering:** Audio cards tested with a 5-minute audio file — scroll is smooth (no Path-per-sample rendering)
- [ ] **Orb performance:** iPhone 12 (physical device) runs AI processing with orb animating — no frame drops below 55fps
- [ ] **Contrast:** Accessibility Inspector run on every screen — all text passes 4.5:1 minimum

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| MeshGradient crash on iOS 17 discovered post-release | HIGH | Emergency patch: wrap all `MeshGradient` calls with `@available(iOS 18, *)`, deploy linear gradient fallback, expedited App Store review |
| Frame drops discovered late in phase | MEDIUM | Profile with Instruments, identify which layers cause off-screen render, replace `clipShape` with background shapes, reduce concurrent blur layers |
| Design token name collision discovered mid-milestone | MEDIUM | Rename all tokens to namespaced form, find-and-replace across codebase, test every screen in both color schemes |
| Orb causing thermal throttle on older devices | MEDIUM | Migrate stacked SwiftUI views to `TimelineView + Canvas` implementation; static orb on older devices |
| Haptics feel mechanical after full integration | LOW | Single pass: remove haptics from continuous interactions, tune impact styles down one level (`.medium` → `.light`) |
| Accessibility audit failure before App Store submission | HIGH | Schedule accessibility audit early (after design system phase), not at end — remediation at card/screen level is much cheaper than post-integration fixes |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| MeshGradient iOS 17 crash (Pitfall 1) | Phase 1: Design system | Run app on iOS 17 simulator — waveform background renders as linear gradient, not blank |
| Glassmorphism without accessibility fallbacks (Pitfall 2) | Phase 1: Design system | Toggle Reduce Transparency — every glass surface shows solid opaque fallback |
| Multiple blur layers frame drops (Pitfall 3) | Phase 2: Mixing Station layout | iPhone 12 physical device: scroll 5-card list at 60fps sustained |
| AI Orb concurrent animation overload (Pitfall 4) | Phase 3: Cleaning Lab restyle | iPhone 12 physical device: orb + audio processing runs at 55fps+ |
| Token color shadowing SwiftUI built-ins (Pitfall 5) | Phase 1: Design system | System alert and sheet backgrounds use correct system colors, not tokens |
| Drag shadow off-screen render (Pitfall 6) | Phase 2: Mixing Station layout | Offscreen-Rendered overlay shows clean cells at rest; orange only on dragged cell |
| Haptic overuse (Pitfall 7) | Phase 4: Interactive states polish | QA tactile review: no continuous buzz, no haptic on disabled button press |
| clipShape off-screen render on complex cards (Pitfall 8) | Phase 1: Design system / card base | Instruments: zero offscreen-rendered on resting list cells with 5 cards visible |

---

## Sources

- [MeshGradient — Apple Developer Documentation](https://developer.apple.com/documentation/SwiftUI/MeshGradient) — confirms iOS 18 minimum
- [Getting started with MeshGradients on iOS 18 — Donny Wals](https://www.donnywals.com/getting-started-with-mesh-gradients-on-ios-18/)
- [Mesh Gradients in SwiftUI — nil Coalescing](https://nilcoalescing.com/blog/MeshGradientsInSwiftUI/)
- [SwiftUI Accessibility: Supporting specific accessibility needs — Hacking with Swift](https://www.hackingwithswift.com/books/ios-swiftui/supporting-specific-accessibility-needs-with-swiftui)
- [Supporting Reduced Motion in SwiftUI — tanaschita.com](https://tanaschita.com/ios-accessibility-reduced-motion/)
- [Glassmorphism accessibility — NN/g Nielsen Norman Group](https://www.nngroup.com/articles/glassmorphism/)
- [Enabling high-performance Metal rendering with drawingGroup() — Hacking with Swift](https://www.hackingwithswift.com/books/ios-swiftui/enabling-high-performance-metal-rendering-with-drawinggroup)
- [Advanced SwiftUI Animations Part 5: Canvas — The SwiftUI Lab](https://swiftui-lab.com/swiftui-animations-part5/)
- [SwiftUI Design System Considerations: Semantic Colors — magnuskahr.dk](https://www.magnuskahr.dk/posts/2025/06/swiftui-design-system-considerations-semantic-colors/)
- [Building a SwiftUI Design System — Color — Design Systems Collective](https://www.designsystemscollective.com/building-a-swiftui-design-system-part-1-color-2ea75035e691)
- [Haptic Feedback in iOS — HackerNoon](https://hackernoon.com/the-ios-guide-to-haptic-feedback)
- [How to add visual effect blurs — Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-visual-effect-blurs)
- [Clip Shape and Smooth Corners — Design+Code SwiftUI Handbook](https://designcode.io/swiftui-handbook-clip-shape-and-smooth-corners/)
- [Demystify SwiftUI performance — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10160/)
- [Create custom visual effects with SwiftUI — WWDC24](https://developer.apple.com/videos/play/wwdc2024/10151/)
- [Continuous corners in SwiftUI — cargath.github.io](https://cargath.github.io/blog/2019/06/23/SwiftUI-Rounded-Corners)
- [Better performance with Canvas in SwiftUI — swdevnotes.com](https://swdevnotes.com/swift/2022/better-performance-with-canvas-in-swiftui/)

---
*Pitfalls research for: iOS SwiftUI visual restyle — glassmorphism, mesh gradients, design tokens, animated orbs*
*Milestone: v1.1 Modern Spatial Utility Restyle*
*Researched: 2026-04-11*
