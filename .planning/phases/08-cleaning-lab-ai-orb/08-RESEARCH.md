# Phase 8: Cleaning Lab + AI Orb — Research

**Researched:** 2026-04-16
**Domain:** SwiftUI view-layer restyle — TimelineView + Canvas animation, custom gesture-based slider, PillButtonStyle extension, SquircleCard migration
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**AI Orb Rendering Approach**
- **D-01:** Blob parameters (baseRadius, phaseOffset, frequency, gradient stops, blendMode) are structured as a static `[BlobConfig]` array. The Canvas iterates the array to draw each blob. This separates data from rendering and makes individual blobs easy to tune.
- **D-02:** The outer bloom (Lime Green glow extending beyond the 240pt orb) is rendered as a separate SwiftUI View layer in a ZStack — NOT inside the Canvas. `.blur(radius: 24)` is applied to this separate layer. This keeps Canvas draw calls minimal and follows the UI-SPEC recommendation ("outside Canvas — cheaper this way").
- **D-03:** The idle state (no denoising, no result) reuses the same static t=0 nebula composition as the reduceMotion fallback. Label switches to "Ready to denoise" in muted `textSecondary`. No dimming or desaturation — the orb looks identical whether idle or reduceMotion, just without animation.
- **D-04:** The progress ring animates smoothly with `.easeOut(duration: 0.25)` per each discrete progress callback from the ViewModel. Ring sweeps smoothly between values rather than jumping.

**LimeGreenSlider Gesture Tuning**
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

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CL-01 | AI Orb visualizer displays a pulsating nebula sphere animation (TimelineView + Canvas) during denoising, with reduceMotion static fallback | TimelineView(.animation(paused:)) + Canvas RadialGradient blobs; BlobConfig array pattern; t=0 static composition as fallback |
| CL-02 | AI-specific controls use Lime Green (#A7C957) accent color for denoise progress, slider, and action indicators | `semantic.accentAI` already wired in both light/dark palettes since Phase 6; mode-conditional text contrast rule for light mode |
| CL-03 | All Cleaning Lab controls use PillButton style and design system color tokens for full dark mode support | PillButtonStyle extension with Tint enum; SquircleCard wrapping; 6 hardcoded `Color(red:)` literals to migrate in staleBanner |
</phase_requirements>

---

## Summary

Phase 8 is a pure view-layer restyle of `CleaningLabView.swift` with two new component files (`AIOrbView.swift`, `LimeGreenSlider.swift`). No ViewModel or service changes are permitted — the `CleaningLabViewModel` contract is frozen. The design system tokens required (`accentAI`, `accentGradientEnd`, `accentAction`, `surfaceCard`, `Spacing.*`, `Radius.card`) all exist in the codebase since Phase 6/7; Phase 8 is the first consumer of `accentAI`.

The highest-complexity deliverable is `AIOrbView` — a `TimelineView(.animation)` + `Canvas` nebula sphere with four radial gradient blobs animated via sine/cosine phase offsets. The architecture decision (BlobConfig array, separate bloom layer outside Canvas) is locked. The second new component is `LimeGreenSlider` — a gesture-based custom slider that replaces the iOS system `Slider` to achieve a Deep Indigo thumb with Lime Green glow.

The main migration risk is the `.sheet(isPresented: .constant(viewModel.isProcessing))` denoising progress modal removal — the export sheets (three separate `.sheet` modifiers) must survive untouched. The six hardcoded `Color(red:green:blue:)` literals in `staleBanner` are the primary dark-mode debt that Phase 8 eliminates.

**Primary recommendation:** Sequence as Wave 0 (test stubs) → Wave 1 (PillButtonStyle.Tint extension + foundation) → Wave 2 (new components: AIOrbView + LimeGreenSlider) → Wave 3 (CleaningLabView full restyle integrating both components and removing the denoising modal).

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI `TimelineView` | iOS 15+ (project min iOS 17) | Drive continuous Canvas animation at 60 FPS | Only SwiftUI-native API for time-driven continuous rendering without timers |
| SwiftUI `Canvas` | iOS 15+ | Immediate-mode 2D drawing for blob radial gradients | No UIKit required; composable with SwiftUI environment; GPU-accelerated |
| SwiftUI `DragGesture(minimumDistance: 0)` | iOS 13+ | Track-tappable slider gesture | Same gesture handles both tap-to-jump and continuous drag per D-06 |
| `RadialGradient` | iOS 13+ | Per-blob nebula color field | Pure SwiftUI, no Core Graphics boilerplate, composable blend modes |
| `.sensoryFeedback(_:trigger:)` | iOS 17+ | Declarative haptic feedback | Project pattern established in Phase 6; replaces UIImpactFeedbackGenerator |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `GeometryReader` | iOS 13+ | Resolve LimeGreenSlider track width for gesture math | Only in `LimeGreenSlider` — avoid elsewhere (breaks layout predictability) |
| `@Environment(\.accessibilityReduceMotion)` | iOS 13+ | Pause TimelineView for reduceMotion users | Read inside `AIOrbView`; pass as `paused:` parameter |
| `@Environment(\.accessibilityReduceTransparency)` | iOS 13+ | Reduce thumb glow radius/opacity per D-07 | Read inside `LimeGreenSlider` |
| `@Environment(\.colorScheme)` | iOS 13+ | Mode-conditional Lime Green vs Deep Indigo for text | Required for intensity "%" readout and "Denoising…" label per contrast rules |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `TimelineView(.animation)` + `Canvas` | `SpriteKit` scene | SpriteKit adds framework dependency and breaks SwiftUI layout; Canvas is the correct iOS 15+ answer |
| Custom `DragGesture` slider | System `Slider` with `.tint` | System Slider cannot style the thumb — Deep Indigo thumb + Lime Green glow requires custom implementation |
| BlobConfig array (D-01) | Inline hardcoded parameters | Array enables per-blob tuning without touching render logic; locked per D-01 |

**Installation:** No new packages. All APIs are SwiftUI built-ins available since iOS 15/17.

---

## Architecture Patterns

### Recommended Project Structure

New files added in this phase:

```
SonicMerge/Features/Denoising/
├── CleaningLabView.swift        # Restyle existing; remove denoising modal sheet
├── CleaningLabViewModel.swift   # FROZEN — do not touch
├── AIOrbView.swift              # NEW — TimelineView + Canvas nebula sphere
└── LimeGreenSlider.swift        # NEW — custom gesture-based slider
SonicMerge/DesignSystem/
└── PillButtonStyle.swift        # Extend with Tint enum
```

### Pattern 1: BlobConfig Array + Canvas Iterator (D-01 locked)

**What:** A static array of value-type configs (one per blob). The Canvas closure iterates the array and draws each blob using its parameters modulated by the current time `t`.

**When to use:** Any multi-layer Canvas animation where individual layer parameters need tuning in isolation.

**Example:**

```swift
// Source: CONTEXT.md D-01, 08-UI-SPEC.md AI Orb spec
struct BlobConfig {
    let baseRadius: CGFloat
    let phaseOffset: Double   // radians
    let frequency: Double     // Hz
    let gradient: (center: Color, edge: Color)
    let blendMode: GraphicsContext.BlendMode
    let baseCenter: CGPoint   // offset from canvas center
}

let blobs: [BlobConfig] = [
    // Core: Deep Indigo, normal blend
    BlobConfig(baseRadius: 40, phaseOffset: 0.0, frequency: 0.35,
               gradient: (Color(uiColor: semantic.accentAction).opacity(0.95), .clear),
               blendMode: .normal, baseCenter: CGPoint(x: 120, y: 120)),
    // Mid 1: Purple, screen blend
    BlobConfig(baseRadius: 70, phaseOffset: 1.57, frequency: 0.50,
               gradient: (Color(uiColor: semantic.accentGradientEnd).opacity(0.75), .clear),
               blendMode: .screen, baseCenter: CGPoint(x: 120, y: 120)),
    // Mid 2: Purple, screen blend, larger
    BlobConfig(baseRadius: 95, phaseOffset: 3.14, frequency: 0.65,
               gradient: (Color(uiColor: semantic.accentGradientEnd).opacity(0.50), .clear),
               blendMode: .screen, baseCenter: CGPoint(x: 120, y: 120)),
    // Rim: Lime Green donut, screen blend — anchored
    BlobConfig(baseRadius: 115, phaseOffset: 4.71, frequency: 0.80,
               gradient: (.clear, Color(uiColor: semantic.accentAI).opacity(0.35)),
               blendMode: .screen, baseCenter: CGPoint(x: 120, y: 120)),
]
```

### Pattern 2: TimelineView paused branch for idle/reduceMotion (D-03 locked)

**What:** `TimelineView(.animation(minimumInterval: 1.0/60.0, paused: shouldPause))`. When `shouldPause == true`, Canvas draws one frame at `t = 0` and never re-invokes. The `t = 0` composition is the canonical "at rest" state by mathematical design (all blobs at base radius, sin(0) = 0).

**When to use:** Any continuous Canvas animation that must degrade gracefully for reduceMotion or idle states.

```swift
// Source: 08-UI-SPEC.md AI Orb spec
@Environment(\.accessibilityReduceMotion) private var reduceMotion

private var shouldPause: Bool {
    reduceMotion || !viewModel.isProcessing
}

var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: shouldPause)) { timeline in
        Canvas { ctx, size in
            let t = timeline.date.timeIntervalSinceReferenceDate
            for blob in blobs {
                let radius = blob.baseRadius * (1 + 0.08 * sin(t * blob.frequency * 2 * .pi + blob.phaseOffset))
                let cx = blob.baseCenter.x + cos(t * blob.frequency * 2 * .pi + blob.phaseOffset) * 12
                let cy = blob.baseCenter.y + sin(t * blob.frequency * 1.3 * 2 * .pi + blob.phaseOffset) * 12
                // draw radial gradient at (cx, cy) with radius
            }
        }
    }
    .frame(width: 240, height: 240)
    .saturation(1.15)
}
```

### Pattern 3: Separate Bloom Layer Outside Canvas (D-02 locked)

**What:** A distinct SwiftUI `View` layer in a `ZStack` applies `.blur(radius: 24)` to the Lime Green outer bloom. This is cheaper than a Canvas `drawLayer` + blur because SwiftUI composites it separately.

**Critical constraint:** This adds 1 blur layer. Combined with the glassmorphism nav header (Phase 6), total = 2 blur layers = at the v1.1 GPU budget ceiling. No further blurs permitted.

```swift
// Source: CONTEXT.md D-02, 08-UI-SPEC.md GPU budget
ZStack {
    // Outer bloom — separate View layer, NOT inside Canvas
    Circle()
        .fill(
            RadialGradient(
                colors: [Color(uiColor: semantic.accentAI).opacity(0.18), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 144   // 288pt / 2 — fades to transparent
            )
        )
        .frame(width: 288, height: 288)
        .blur(radius: 24)
        .blendMode(.screen)

    // Canvas orb
    TimelineView(...) { timeline in
        Canvas { ... }
    }
    .frame(width: 240, height: 240)

    // Progress ring overlay
    Circle()
        .trim(from: 0, to: CGFloat(viewModel.progress))
        .stroke(Color(uiColor: semantic.accentAI),
                style: StrokeStyle(lineWidth: 4, lineCap: .round))
        .rotationEffect(.degrees(-90))
        .frame(width: 256, height: 256)
        .animation(.easeOut(duration: 0.25), value: viewModel.progress)
}
```

### Pattern 4: PillButtonStyle Tint Extension (backward-compatible)

**What:** Add `enum Tint { case accent, ai }` and `let tint: Tint` to `PillButtonStyle`. Default `tint: .accent` preserves Phase 6/7 behavior byte-for-byte. Only call sites opting into `.ai` change.

**Critical:** `labelColor` must branch on `(variant, tint)` — Lime Green filled pills use `SonicMergeTheme.ColorPalette.primaryText` (#1C1C1E) as the label, not white. White on Lime Green = 1.98:1, failing WCAG. Dark `#1C1C1E` on Lime Green = 7.38:1, passing AAA.

```swift
// Source: 08-UI-SPEC.md PillButtonStyle Lime Green Override
enum Tint { case accent, ai }

init(variant: Variant = .filled, size: Size = .regular, tint: Tint = .accent) {
    self.variant = variant
    self.size = size
    self.tint = tint
}

private var labelColor: Color {
    switch (variant, tint) {
    case (.filled, .accent): return .white                              // Phase 6/7 unchanged
    case (.filled, .ai):     return Color(uiColor: SonicMergeTheme.ColorPalette.primaryText)
    case (.outline, _):      return Color(uiColor: semantic.textPrimary)
    }
}

private var backgroundFill: some View {
    // (.filled, .accent) → accentAction (Deep Indigo)
    // (.filled, .ai)     → accentAI     (Lime Green)
    // (.outline, _)      → Color.clear
}
```

### Pattern 5: LimeGreenSlider — GeometryReader + DragGesture(minimumDistance: 0)

**What:** Wrap track in `GeometryReader` to get width. Apply `DragGesture(minimumDistance: 0)` to the full track frame so tap-to-jump and drag both work via the same gesture (D-06).

```swift
// Source: CONTEXT.md D-05, D-06; 08-UI-SPEC.md LimeGreenSlider spec
GeometryReader { geo in
    ZStack(alignment: .leading) {
        // Unfilled track
        Capsule().fill(trackUnfilled).frame(height: 6)
        // Filled track
        Capsule().fill(Color(uiColor: semantic.accentAI))
            .frame(width: max(0, geo.size.width * CGFloat(value)), height: 6)
        // Thumb
        Circle()
            .fill(Color(uiColor: semantic.accentAction))
            .frame(width: 28, height: 28)
            .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
            .shadow(color: Color(uiColor: semantic.accentAI).opacity(thumbGlowOpacity),
                    radius: thumbGlowRadius, x: 0, y: 0)
            .contentShape(Rectangle().size(width: 44, height: 44))  // D-05: 44pt touch target
            .offset(x: max(0, geo.size.width * CGFloat(value)) - 14)
    }
    .gesture(
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                let ratio = (drag.location.x / geo.size.width).clamped(to: 0...1)
                value = Double(ratio)
                if !isEditing { isEditing = true; onEditingChanged?(true) }
            }
            .onEnded { _ in isEditing = false; onEditingChanged?(false) }
    )
}
.frame(height: 44)  // Min touch height per HIG
```

### Pattern 6: Denoising Modal Removal — Sheet Isolation

**What:** Remove `.sheet(isPresented: .constant(viewModel.isProcessing))` (the denoising progress sheet) while leaving the three export sheets untouched.

**Critical:** There are FOUR `.sheet` modifiers in `CleaningLabView`. Only the last one (`isPresented: .constant(viewModel.isProcessing)`) is removed. The other three (`showExportSheet`, `showExportProgressSheet`, `showShareSheet`) must survive byte-for-byte.

The cancel action moves inline into `AIOrbView` as a `PillButtonStyle(.outline, .compact, .accent)` pill visible only when `viewModel.isProcessing`.

### Anti-Patterns to Avoid

- **Using `.blur()` inside Canvas:** Canvas draw calls do not inherit SwiftUI modifiers. Apply `.blur()` outside the Canvas on a sibling View layer (D-02).
- **Animating `TimelineView` with `withAnimation`:** TimelineView drives its own continuous schedule. Using `withAnimation` on timeline-driven state creates double-animation artifacts.
- **Hardcoding `Color.white` for Lime Green pill labels:** White fails WCAG on Lime Green (1.98:1). Use `SonicMergeTheme.ColorPalette.primaryText` (#1C1C1E).
- **Adding `.medium` font weight:** Phase 8 continues Phase 6/7 enforcement — only `.regular` and `.semibold` are permitted. The existing `intensitySlider` label uses `.weight(.medium)` and must be migrated.
- **Modifying CleaningLabViewModel:** The ViewModel is frozen. Any visual requirement that needs a new `@Published` property is a BLOCKER and must be redesigned at the view layer.
- **Additional blur layers:** At 2 blur layers (nav header + orb bloom), the screen is at the GPU budget ceiling. No `LimeGreenSlider` thumb glow uses `.shadow()` not `.blur()` — do not promote it to `.blur()`.
- **Using three-period ellipsis `...`:** All ellipsis characters must be the single Unicode character `…`. Check "Processing..." in waveformSection.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Lime Green glow on slider thumb | Custom UIView or CALayer glow | SwiftUI `.shadow(color: accentAI.opacity(0.35), radius: 12)` | Shadow modifier is GPU-composited, zero boilerplate, respects reduceTransparency branch |
| A/B compare hold interaction | Custom recognizer | `.onLongPressGesture(minimumDuration: 0, pressing:)` | Already implemented in existing code — Phase 8 only wraps it in PillButtonStyle, gesture is preserved byte-for-byte |
| Progress ring | CAShapeLayer + stroke animation | `Circle().trim(from: 0, to: progress).stroke(...)` + `.animation(.easeOut(duration: 0.25), value: progress)` | SwiftUI implicit animation handles smooth sweep; no CAAnimation setup |
| Haptic feedback | `UIImpactFeedbackGenerator` | `.sensoryFeedback(.impact(weight: .light), trigger:)` | Project-established pattern (Phase 06-02); iOS 17+ declarative; weight: label required per STATE.md |
| Dark mode color switching | `@State var isDark` + manual swap | `@Environment(\.colorScheme)` + ternary on read | Environment propagates automatically; no state management |

**Key insight:** This is a pure view-layer restyle. Every functional pattern (A/B playback, intensity blend, cancel, export) already works in the ViewModel. The view layer's job is presentation only — resist any temptation to move logic into views.

---

## Common Pitfalls

### Pitfall 1: Removing the wrong `.sheet` modifier

**What goes wrong:** CleaningLabView has four `.sheet` modifiers chained. Deleting the wrong one breaks file export or the share sheet.

**Why it happens:** All four look structurally similar. The denoising modal is `isPresented: .constant(viewModel.isProcessing)` (a constant binding, non-dismissible). The export sheets use `$showExportSheet`, `$showExportProgressSheet`, `$showShareSheet` (state bindings).

**How to avoid:** Identify by the binding type — `.constant(viewModel.isProcessing)` is the one to remove. Grep for `isProcessing` inside `.sheet` blocks.

**Warning signs:** After removal, the app no longer shows denoising progress visually — correct. If export stops working, the wrong sheet was removed.

### Pitfall 2: Light mode Lime Green text contrast failure

**What goes wrong:** Using `accentAI` for the intensity percentage "65%" or "Denoising…" label in light mode. Lime Green on white `surfaceCard` = 1.71:1 — fails WCAG AA for text.

**Why it happens:** The color works perfectly in dark mode (11.32:1 AAA), so it's tempting to use it everywhere.

**How to avoid:** Apply the mode-conditional swap: `colorScheme == .dark ? Color(uiColor: semantic.accentAI) : Color(uiColor: semantic.accentAction)` on text elements. Graphics (progress ring, slider track, button fills, orb rim) are exempt — HIG exempts decorative graphics from 4.5:1.

**Warning signs:** Any `accentAI` foreground on a text element in a SquircleCard without a `colorScheme` branch is a bug.

### Pitfall 3: Lime Green pill labels using white

**What goes wrong:** `PillButtonStyle(.filled, .ai)` inherits the existing `.white` label color from the `.filled` case.

**Why it happens:** The current `labelColor` returns `.white` for all `.filled` variants.

**How to avoid:** Branch explicitly: `case (.filled, .ai): return Color(uiColor: SonicMergeTheme.ColorPalette.primaryText)`. Dark `#1C1C1E` on `#A7C957` = 7.38:1 AAA.

**Warning signs:** Lime Green buttons with white text look washed out on device.

### Pitfall 4: `sensoryFeedback` dropping the `weight:` label

**What goes wrong:** Compiler error in Xcode 26.2 when using `.sensoryFeedback(.impact(.light), trigger:)` without the `weight:` label.

**Why it happens:** iOS 26.2 SDK changed the enum case to require the `weight:` label. This is documented in STATE.md Phase 06-02.

**How to avoid:** Always write `.sensoryFeedback(.impact(weight: .light), trigger:)` — with the `weight:` label.

**Warning signs:** Build errors referencing `impact` enum case with incorrect argument labels.

### Pitfall 5: Canvas drawing `RadialGradient` with SwiftUI Color instead of CGColor

**What goes wrong:** `Canvas` context's `fill(_:with:)` method accepts `GraphicsContext.Shading`, not a SwiftUI `View`. Passing a `RadialGradient` view directly does not compile.

**Why it happens:** RadialGradient is a SwiftUI `ShapeStyle` / `View`, not a `Canvas` shading.

**How to avoid:** Use `GraphicsContext.Shading.radialGradient(Gradient(...), center:, startRadius:, endRadius:)` and draw with `ctx.fill(path, with: shading)`. Alternatively, use `ctx.drawLayer { ... }` to embed a SwiftUI gradient.

**Verified pattern from Phase 7 WaveformCanvasView (existing code):**
```swift
// WaveformCanvasView uses .color shading; for radial gradients:
let shading = GraphicsContext.Shading.radialGradient(
    Gradient(colors: [accentColor.opacity(0.95), .clear]),
    center: center,
    startRadius: 0,
    endRadius: radius
)
context.fill(Circle().path(in: rect), with: shading)
```

### Pitfall 6: `waveform.badge.magnifyingglass` availability on iOS 17

**What goes wrong:** The A/B compare button currently uses `waveform.and.magnifyingglass` which is an invalid SF Symbol name. The UI-SPEC migrates it to `waveform.badge.magnifyingglass` — but this must be verified available on iOS 17 SDK before shipping.

**How to avoid:** Verify in Xcode SF Symbols app before commit. If unavailable on iOS 17, fall back to `waveform` (plain).

**Warning signs:** Symbol renders as an empty square on device.

### Pitfall 7: `font(.subheadline).fontWeight(.semibold)` split form requirement

**What goes wrong:** `.font(.subheadline.weight(.semibold))` chained form fails to compile on `ButtonStyleConfiguration.Label` in Xcode 26.2.

**Why it happens:** Compiler issue with chained modifier on generic label type (established in Phase 06-02, STATE.md).

**How to avoid:** Always use the split two-modifier form: `.font(.subheadline).fontWeight(.semibold)`. This applies inside `PillButtonStyle.makeBody`.

### Pitfall 8: CleaningLabViewModel observability — `@State private var viewModel`

**What goes wrong:** Adding new `@Published` / `@Observable` properties to `CleaningLabViewModel` to support view state. This mutates a frozen contract.

**How to avoid:** Any transient view state (e.g., `isEditing` for slider) lives in `@State` variables inside the view or the new component. The ViewModel exposes: `isProcessing`, `progress`, `intensity`, `hasDenoisedResult`, `isHoldingOriginal`, `showsStaleResultBanner`, `waveformPeaks`, `errorMessage`, `denoisedTempURL`. These are all that Phase 8 may consume.

---

## Code Examples

### AIOrbView skeleton (verified patterns)

```swift
// Source: CONTEXT.md D-01/D-02/D-03; 08-UI-SPEC.md AI Orb spec
struct AIOrbView: View {
    let viewModel: CleaningLabViewModel

    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    private var shouldPause: Bool {
        reduceMotion || !viewModel.isProcessing
    }

    var body: some View {
        VStack(spacing: SonicMergeTheme.Spacing.sm) {
            ZStack {
                // D-02: outer bloom — separate View layer, NOT in Canvas
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(uiColor: semantic.accentAI).opacity(0.18), .clear],
                        center: .center, startRadius: 0, endRadius: 144
                    ))
                    .frame(width: 288, height: 288)
                    .blur(radius: reduceTransparency ? 8 : 24)
                    .blendMode(.screen)

                // D-01: Canvas iterates BlobConfig array
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: shouldPause)) { timeline in
                    Canvas { ctx, size in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        for blob in makeBlobs() {
                            let r = blob.baseRadius * (1 + 0.08 * sin(t * blob.frequency * 2 * .pi + blob.phaseOffset))
                            let cx = blob.baseCenter.x + cos(t * blob.frequency * 2 * .pi + blob.phaseOffset) * 12
                            let cy = blob.baseCenter.y + sin(t * blob.frequency * 1.3 * 2 * .pi + blob.phaseOffset) * 12
                            let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                            let shading = GraphicsContext.Shading.radialGradient(
                                Gradient(colors: blob.gradientColors),
                                center: CGPoint(x: cx, y: cy),
                                startRadius: 0, endRadius: r
                            )
                            ctx.blendMode = blob.blendMode
                            ctx.fill(Ellipse().path(in: rect), with: shading)
                        }
                    }
                }
                .frame(width: 240, height: 240)
                .saturation(1.15)

                // Progress ring (D-04: .easeOut(0.25))
                if viewModel.isProcessing {
                    Circle()
                        .trim(from: 0, to: CGFloat(viewModel.progress))
                        .stroke(Color(uiColor: semantic.accentAI),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 256, height: 256)
                        .animation(.easeOut(duration: 0.25), value: viewModel.progress)
                }
            }

            // State-dependent label
            Text(orbLabel)
                .font(.title3)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundStyle(colorScheme == .dark
                    ? Color(uiColor: semantic.accentAI)
                    : Color(uiColor: semantic.accentAction))
                .accessibilityLabel(orbAccessibilityLabel)
                .accessibilityAddTraits(.updatesFrequently)

            if viewModel.isProcessing {
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
                    .monospacedDigit()

                Button("Cancel denoising") { viewModel.cancelDenoising() }
                    .buttonStyle(PillButtonStyle(variant: .outline, size: .compact, tint: .accent))
                    .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.isProcessing)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var orbLabel: String {
        if viewModel.isProcessing { return "Denoising\u{2026}" }          // single ellipsis char
        if viewModel.hasDenoisedResult { return "Denoised" }
        return "Ready to denoise"
    }
}
```

### staleBanner migration (6 hardcoded colors → semantic tokens)

```swift
// Source: 08-UI-SPEC.md staleBanner migration table
private var staleBanner: some View {
    SquircleCard(glassEnabled: false, glowEnabled: false) {
        HStack(spacing: SonicMergeTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.orange)   // was Color(red: 0.8, green: 0.4, blue: 0.0)

            VStack(alignment: .leading, spacing: 2) {
                Text("Clips have changed.")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))  // was Color(red: 0.5, ...)

                Text("Re-process to update the denoised audio.")
                    .font(.caption)
                    .foregroundStyle(Color(uiColor: semantic.textSecondary)) // was Color(red: 0.5, ...)
            }

            Spacer()

            Button("Re-process") {
                viewModel.startDenoising(mergedFileURL: mergedFileURL)
            }
            .buttonStyle(PillButtonStyle(variant: .filled, size: .compact, tint: .ai))
            // was: Color(red: 0.7, ...) foreground + Color(red: 1.0, ...) background — both deleted
        }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Stale result warning. Clips have changed. Re-process to update the denoised audio.")
}
```

### Dark mode text contrast conditional (intensity readout + orb label)

```swift
// Source: 08-UI-SPEC.md WCAG contrast table — mode-conditional swap
Text("\(Int(viewModel.intensity * 100))%")
    .font(.title3)
    .fontWeight(.semibold)
    .monospacedDigit()
    .foregroundStyle(
        colorScheme == .dark
            ? Color(uiColor: semantic.accentAI)      // 11.32:1 AAA on #0F0F0F
            : Color(uiColor: semantic.accentAction)  //  6.24:1 AA  on #FFFFFF
    )
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| System `Slider` with `.tint()` | Custom `LimeGreenSlider` with `DragGesture` | Phase 8 | Enables Deep Indigo thumb + Lime Green glow; system Slider thumb is not styleable |
| `ExportProgressSheet` modal for denoising progress | Inline AI Orb with integrated progress ring | Phase 8 | Non-blocking; spatial utility aesthetic; ViewModel contract unchanged |
| `UIImpactFeedbackGenerator` (Phase 3) | `.sensoryFeedback(.impact(weight:), trigger:)` | Phase 6 | Declarative, no imperative setup; `weight:` label required in Xcode 26.2 |
| `RoundedRectangle(cornerRadius: 12)` card wrappers | `SquircleCard(glassEnabled: false, glowEnabled: false)` | Phase 7 (for Mixing Station), Phase 8 (for Cleaning Lab) | Continuous 24pt corner radius; consistent elevation shadow; no per-card shadow math |
| Hardcoded `Color(red:green:blue:)` in staleBanner | `semantic.textPrimary`, `.textSecondary`, `Color.orange` | Phase 8 | Automatic dark mode; zero custom color values |

**Deprecated/outdated in Phase 8:**
- `.sheet(isPresented: .constant(viewModel.isProcessing)) { ExportProgressSheet }` — removed, replaced by inline AIOrbView
- `waveform.and.magnifyingglass` SF Symbol name — invalid; replaced with `waveform.badge.magnifyingglass`
- `.weight(.medium)` on `Text` in Cleaning Lab — forbidden per Phase 6/7 rules; migrate to `.regular` or `.semibold`
- Three-period ellipsis `"Processing..."` — replaced with single Unicode `"Processing…"`

---

## Open Questions

1. **`waveform.badge.magnifyingglass` availability on iOS 17**
   - What we know: UI-SPEC mandates it; current code uses invalid `waveform.and.magnifyingglass`
   - What's unclear: Whether `waveform.badge.magnifyingglass` is available in the iOS 17 SDK (not just iOS 18)
   - Recommendation: Executor must verify in Xcode SF Symbols app before commit. Fallback: `waveform` (plain). Plan should include explicit verification step.

2. **`GraphicsContext.BlendMode` vs `View.blendMode` in Canvas**
   - What we know: Canvas uses `GraphicsContext.blendMode` (a property on `inout ctx`), not the SwiftUI `.blendMode()` modifier
   - What's unclear: The exact API to set blend mode per-draw call inside Canvas (`ctx.blendMode = .screen` before each fill)
   - Recommendation: Executor uses `ctx.blendMode = blob.blendMode` before each `ctx.fill(...)` call; reset to `.normal` after each blob.

3. **`font(.title3).fontWeight(.semibold)` split form inside non-ButtonStyle views**
   - What we know: The split form is required inside `PillButtonStyle.makeBody` due to a compiler issue with `ButtonStyleConfiguration.Label`
   - What's unclear: Whether the split form is also required in regular `Text` views in `AIOrbView`
   - Recommendation: Use split form throughout all Phase 8 views for consistency; the penalty for using it unnecessarily is zero.

---

## Environment Availability

Step 2.6: Phase 8 is a pure SwiftUI view-layer change with no external tool dependencies beyond Xcode and the iOS SDK. No new Swift packages, CLI tools, databases, or services are introduced.

**Skip condition:** No external dependencies beyond Xcode (already used) and iOS 17+ SDK (already the deployment target). SKIPPED.

---

## Validation Architecture

`nyquist_validation` is enabled (config.json `workflow.nyquist_validation: true`).

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (`import Testing`) — per STATE.md Phase 03 decision |
| Config file | PBXFileSystemSynchronizedRootGroup — zero config (STATE.md Phase 01-01) |
| Quick run command | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SonicMergeTests/PillButtonStyleTests 2>&1 \| tail -20` |
| Full suite command | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 \| tail -30` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CL-01 | AIOrbView renders static frame when `isProcessing = false` (idle state) | unit | Not fully automatable — Canvas rendering requires visual inspection. Smoke: `AIOrbView` initializes without crash | ❌ Wave 0 |
| CL-01 | Progress ring `trim(to:)` value matches `viewModel.progress` | unit | Assert on bound value | ❌ Wave 0 |
| CL-02 | `PillButtonStyle(.filled, .ai)` uses `accentAI` background fill | unit | Assert `tint == .ai` → `accentAI` color path | ❌ Wave 0 |
| CL-02 | Intensity percentage uses `accentAI` in dark mode, `accentAction` in light mode | manual | Visual inspection on device | manual-only |
| CL-03 | `PillButtonStyle(tint: .accent)` with no `tint` arg preserves Phase 6/7 behavior | unit | Existing call sites compile without edits | ❌ Wave 0 |
| CL-03 | `CleaningLabView` contains zero `Color(red:` literals after restyle | unit | `grep` check (can be a test or a verify step) | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `xcodebuild build -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5` (build-only gate)
- **Per wave merge:** `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `SonicMergeTests/PillButtonStyleTintTests.swift` — covers CL-02/CL-03: `Tint` enum cases, `labelColor` branches, backward-compat default
- [ ] `SonicMergeTests/LimeGreenSliderTests.swift` — covers CL-02/CL-03: value binding clamp, `onEditingChanged` callbacks
- [ ] `SonicMergeTests/AIOrbViewTests.swift` — covers CL-01: view instantiates without crash; `orbLabel` returns correct string per state

---

## Sources

### Primary (HIGH confidence)

- `SonicMerge/Features/Denoising/CleaningLabView.swift` — Current view structure, 4 sheet modifiers identified, 6 hardcoded colors confirmed, existing patterns read
- `SonicMerge/Features/Denoising/CleaningLabViewModel.swift` — Frozen contract confirmed: `isProcessing`, `progress`, `intensity`, `hasDenoisedResult`, `isHoldingOriginal`, `showsStaleResultBanner`, `waveformPeaks`, `errorMessage`, `denoisedTempURL`, `cancelDenoising()`
- `SonicMerge/DesignSystem/PillButtonStyle.swift` — Current Variant/Size enums, `labelColor`/`backgroundFill` structure confirmed; Tint extension insertion point identified
- `SonicMerge/DesignSystem/SquircleCard.swift` — `glassEnabled`/`glowEnabled` API, `Spacing.md` (16pt) internal padding confirmed
- `SonicMerge/DesignSystem/SonicMergeTheme.swift` — `limeGreen`, `systemPurple`, all spacing/radius tokens confirmed present
- `SonicMerge/DesignSystem/SonicMergeTheme+Appearance.swift` — `accentAI`, `accentGradientEnd` slots confirmed in both light and dark palettes
- `.planning/phases/08-cleaning-lab-ai-orb/08-CONTEXT.md` — All locked decisions (D-01 through D-07) and discretion areas
- `.planning/phases/08-cleaning-lab-ai-orb/08-UI-SPEC.md` — Complete visual contract, component specs, color story, layout order, animation inventory, haptics inventory, accessibility contract, dark mode audit table

### Secondary (MEDIUM confidence)

- `.planning/STATE.md` — Phase 06-02 `sensoryFeedback` weight: label requirement; Phase 07 PillButtonStyle patterns; GPU budget rule (max 2 blur layers)
- `.planning/phases/07-mixing-station-restyle/07-01-PLAN.md` — Plan structure reference for how Phase 7 extended PillButtonStyle

### Tertiary (LOW confidence — needs executor verification)

- `waveform.badge.magnifyingglass` SF Symbol iOS 17 availability — referenced in UI-SPEC but not verified against iOS 17 SDK symbol set; executor must check in Xcode SF Symbols app

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — All APIs (TimelineView, Canvas, DragGesture, RadialGradient, sensoryFeedback) are iOS 15-17 built-ins confirmed in existing project
- Architecture: HIGH — All patterns derived directly from CONTEXT.md locked decisions and UI-SPEC; existing code confirms design system token availability
- Pitfalls: HIGH — Derived from code inspection (existing 6 hardcoded colors confirmed), STATE.md decisions, and UI-SPEC contrast math
- Test architecture: MEDIUM — Swift Testing framework confirmed; specific test files are gaps (Wave 0)

**Research date:** 2026-04-16
**Valid until:** 2026-05-16 (stable SwiftUI APIs — 30-day window)

## Project Constraints (from CLAUDE.md)

CLAUDE.md does not exist in this project. No additional project-level directives to enforce beyond what is documented in STATE.md, CONTEXT.md, and the UI-SPEC.

The following project-level constraints are extracted from STATE.md and CONTEXT.md for planner reference:

| Constraint | Source | Enforcement |
|------------|--------|-------------|
| No ViewModel / service changes — view layer only | UI-SPEC Implementation Constraints #1 | Any PR touching CleaningLabViewModel is a BLOCKER |
| iOS 17 minimum — no MeshGradient, no iOS 18+ APIs | UI-SPEC Implementation Constraints #2 | All new APIs must be iOS 15–17 compatible |
| Max 2 blur layers per screen | STATE.md v1.1 Roadmap decision | Phase 8 is at ceiling (nav header + orb bloom); no additional blurs |
| No hardcoded `Color(red:green:blue:)` — semantic tokens only | UI-SPEC Implementation Constraints #5 | `grep -n 'Color(red:' CleaningLabView.swift` must return 0 after Phase 8 |
| Forbidden font weights: `.heavy`, `.bold`, `.medium`, `.black`, `.light`, `.thin`, `.ultraLight` | UI-SPEC Typography | Every touched file must use only `.regular` / `.semibold` |
| `PillButtonStyle(tint: .accent)` default must be backward-compatible | UI-SPEC PillButtonStyle Tint extension | No Phase 6/7 call sites may require changes |
| `sensoryFeedback(.impact(weight: .light))` — `weight:` label required | STATE.md Phase 06-02 | Xcode 26.2 compiler enforces; missing label = build error |
| `.font(.subheadline).fontWeight(.semibold)` split form in ButtonStyle | STATE.md Phase 06-02 | Chained form fails on ButtonStyleConfiguration.Label in Xcode 26.2 |
| Export sheet plumbing untouched | UI-SPEC Implementation Constraints #9 | `showExportSheet`, `showExportProgressSheet`, `showShareSheet` modifiers survive |
