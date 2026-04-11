# Architecture Research

**Domain:** iOS SwiftUI UI Restyle — Modern Spatial Utility aesthetic over existing MVVM app (SonicMerge v1.1)
**Researched:** 2026-04-11 (updated; original 2026-04-08)
**Confidence:** HIGH (based on direct codebase inspection; all integration points verified against existing Swift files; critical MeshGradient availability correction applied 2026-04-11)

---

## CRITICAL CONSTRAINT: MeshGradient Requires iOS 18

**SwiftUI's `MeshGradient` struct was introduced at WWDC 2024 and requires iOS 18+.** SonicMerge targets iOS 17.0+. Direct use of `MeshGradient` in any view will cause a compile error or runtime crash on iOS 17 without an availability guard.

**Resolution:** `MeshWaveformView` must NOT use `MeshGradient`. It uses `LinearGradient` with the Deep Indigo → Purple color stops instead — same visual goal, compatible with iOS 17.0+. The name "Mesh Gradient waveform" in the milestone description refers to the visual aesthetic (multi-stop gradient coloring on bars), not the `MeshGradient` API. If a true `MeshGradient` background is desired for iOS 18 users, wrap it with `if #available(iOS 18, *) { MeshGradient(...) } else { LinearGradient(...) }`.

**Confidence:** HIGH — verified against [Apple Developer Documentation](https://developer.apple.com/documentation/SwiftUI/MeshGradient) and [Donny Wals — Mesh Gradients in SwiftUI](https://www.donnywals.com/getting-started-with-mesh-gradients-on-ios-18/).

---

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                     DESIGN SYSTEM LAYER (EXTENDED + NEW)              │
│  ┌──────────────────┐  ┌─────────────────────┐  ┌─────────────────┐  │
│  │  SonicMergeTheme │  │  SonicMergeSemantic  │  │  SpacialTokens  │  │
│  │  (EXTENDED)      │  │  (EXTENDED)          │  │  (NEW file)     │  │
│  │  +squircleRadius │  │  +gradientStart      │  │  +glowRadius    │  │
│  │  +glowIntensity  │  │  +gradientEnd        │  │  +timelineStroke│  │
│  │                  │  │  +aiHighlight        │  │  +glassBlur     │  │
│  │                  │  │  +glassOpacity       │  │                 │  │
│  └──────────────────┘  └─────────────────────┘  └─────────────────┘  │
├──────────────────────────────────────────────────────────────────────┤
│                    SHARED COMPONENT LAYER (NEW)                        │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────────┐   │
│  │  SquircleCard    │  │  PillButton      │  │  MeshWaveformView │   │
│  │  (ViewModifier)  │  │  (ButtonStyle)   │  │  (Canvas View)    │   │
│  └──────────────────┘  └──────────────────┘  └───────────────────┘   │
│  ┌──────────────────┐  ┌──────────────────┐                           │
│  │  GlassmorphHeader│  │  AIOrb           │                           │
│  │  (View)          │  │  (View)          │                           │
│  └──────────────────┘  └──────────────────┘                           │
├──────────────────────────────────────────────────────────────────────┤
│                      VIEW LAYER (MODIFIED FILES)                       │
│  ┌─────────────────────┐  ┌──────────────────┐  ┌─────────────────┐  │
│  │  MixingStationView  │  │  CleaningLabView  │  │  MergeSlotRow   │  │
│  │  MergeTimelineView  │  │  (AIOrb injected) │  │  ClipCardView   │  │
│  │  (timeline line)    │  │                   │  │  GapRowView     │  │
│  └─────────────────────┘  └──────────────────┘  └─────────────────┘  │
├──────────────────────────────────────────────────────────────────────┤
│              VIEWMODEL + SERVICE LAYER (UNTOUCHED — hard constraint)   │
│  MixingStationViewModel  CleaningLabViewModel  ImportViewModel         │
│  AudioMergerService  NoiseReductionService  WaveformService            │
│  LUFSNormalizationService  AudioNormalizationService                   │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Status |
|-----------|----------------|--------|
| `SonicMergeTheme` | Static UIColor palette, corner radii | EXTENDED — add `spatialRadius=24`, `glowIntensity` |
| `SonicMergeSemantic` | Light/dark resolved semantic colors via EnvironmentKey | EXTENDED — add `gradientStart/End`, `aiHighlight`, `glassOpacity`, `cardGlowColor` |
| `SpacialTokens` | Spatial-specific rendering constants (blur, glow radius, timeline stroke, shadow specs) | NEW file in `DesignSystem/` |
| `SquircleCard` | ViewModifier: 24pt squircle + glass fill + `LinearGradient` overlay + optional glow border | NEW in `Components/`; replaces 5 separate `.background/.clipShape/.shadow` blocks |
| `PillButton` | `ButtonStyle`: capsule shape + inner glow + haptic impact on press + scale animation | NEW in `Components/`; use `ButtonStyle` (not `ViewModifier`) so `.disabled` state propagates correctly |
| `MeshWaveformView` | Canvas view: accepts `[Float]` peaks, renders symmetrical bars filled with `LinearGradient(gradientStart → gradientEnd)` | NEW in `Components/`; replaces three private waveform Canvas structs; uses `LinearGradient` NOT `MeshGradient` |
| `GlassmorphHeader` | SwiftUI View: `.ultraThinMaterial` banner + "Private by Design" text + Deep Indigo glow border | NEW in `Components/` |
| `AIOrb` | SwiftUI View: `TimelineView(.animation)` + `Canvas` pulsating nebula sphere; accepts `isActive: Bool` | NEW in `Components/` |
| `MixingStationView` | Root screen; injects `sonicMergeSemantic` into environment | MODIFIED — toolbar pills, nav header supplement |
| `MergeTimelineView` | Vertical timeline scroll content | MODIFIED — central connector line overlay, section header typography |
| `MergeSlotRow` | Clip card row with waveform thumbnail, name, preview button, drag handle | MODIFIED — `SquircleCard` modifier, `MeshWaveformView` |
| `ClipCardView` | Compact clip card (Share Extension HUD and legacy context) | MODIFIED — `SquircleCard` modifier, `MeshWaveformView` mini |
| `GapRowView` | Segmented gap/crossfade control between clips | MODIFIED — glass background, pill segment style |
| `CleaningLabView` | Denoise screen | MODIFIED — `AIOrb` replaces `onDeviceAIHero`, `MeshWaveformView` replaces `WaveformCanvasView` |
| `TrustSignalViews` | `LocalFirstTrustStrip` trust banner | MODIFIED — `SquircleCard` modifier replaces manual background block |

---

## Recommended Project Structure

```
SonicMerge/
├── DesignSystem/
│   ├── SonicMergeTheme.swift              # EXTENDED: +spatialRadius (24), +glowIntensity
│   ├── SonicMergeTheme+Appearance.swift   # EXTENDED: +gradientStart/End, +aiHighlight,
│   │                                      #           +glassOpacity, +cardGlowColor
│   ├── SpacialTokens.swift                # NEW: squircleRadius=24, cardShadowRadius=12,
│   │                                      #      dragShadowRadius=20, glassBlurRadius=16,
│   │                                      #      timelineStrokeWidth=2, glowBorderWidth=1
│   └── TrustSignalViews.swift             # MODIFIED: SquircleCard + glassmorphism
│
├── Components/                            # NEW top-level folder
│   ├── SquircleCard.swift                 # ViewModifier
│   ├── PillButton.swift                   # ButtonStyle
│   ├── MeshWaveformView.swift             # Shared Canvas waveform renderer (LinearGradient, iOS 17+)
│   ├── GlassmorphHeader.swift             # Glass banner View
│   └── AIOrb.swift                        # Animated orb View (TimelineView + Canvas)
│
└── Features/
    ├── MixingStation/
    │   ├── MixingStationView.swift        # MODIFIED: GlassmorphHeader, PillButton toolbar
    │   ├── MergeTimelineView.swift        # MODIFIED: connector line, output card restyle
    │   ├── MergeSlotRow.swift             # MODIFIED: SquircleCard, MeshWaveformView
    │   ├── ClipCardView.swift             # MODIFIED: SquircleCard, MeshWaveformView mini
    │   ├── GapRowView.swift               # MODIFIED: glass background, pill segments
    │   ├── ExportFormatSheet.swift        # MODIFIED: PillButton on action buttons
    │   └── ExportProgressSheet.swift      # MODIFIED: progress bar glow style
    └── Denoising/
        └── CleaningLabView.swift          # MODIFIED: AIOrb + MeshWaveformView
    # Import/, Services/, Models/, SpeechEnhancement/ — UNTOUCHED
```

### Structure Rationale

- **`DesignSystem/` extensions:** Token additions sit beside existing token files. Reviewers see existing and new properties together; no context switching between folders.
- **`Components/` new folder:** Clear boundary between "shared styled primitives" (used by multiple features) and "feature views." `SquircleCard` and `MeshWaveformView` are both consumed by MixingStation and CleaningLab — they belong in neither feature folder.
- **Feature folder structure unchanged:** ViewModels and Services are not modified per project constraint. Only View-layer `.swift` files change; they stay in their existing feature subfolders.

---

## Architectural Patterns

### Pattern 1: Token Extension — Additive, Not Replacement

**What:** New color and spatial tokens are added to `SonicMergeSemantic` as additional properties alongside existing ones. Views currently not being restyled keep using their existing token names. No existing property is renamed or removed.

**When to use:** Every new design value needed for the v1.1 aesthetic — gradient colors, AI highlight color, glass opacity, glow border color.

**Trade-offs:**
- Pro: Zero risk for views not yet touched in the current build step; the app compiles at every intermediate state.
- Pro: Easy rollback — remove new properties to revert.
- Con: `SonicMergeSemantic` struct grows temporarily; prune unused old tokens in a cleanup commit after the restyle is complete.

**Example:**
```swift
// SonicMergeTheme+Appearance.swift — additive extension
struct SonicMergeSemantic {
    // Existing (unchanged)
    var surfaceBase: UIColor
    var surfaceSlot: UIColor
    var surfaceElevated: UIColor
    var accentAction: UIColor
    var accentWaveform: UIColor
    var textPrimary: UIColor
    var textSecondary: UIColor
    var trustIcon: UIColor

    // NEW for v1.1 Spatial
    var gradientStart: UIColor   // Deep Indigo #5856D6
    var gradientEnd: UIColor     // Purple #9B59B6 (dark) or transparent lavender (light)
    var aiHighlight: UIColor     // Lime Green #A7C957 (dark) / Deep Indigo (light)
    var glassOpacity: Double     // 0.72 light / 0.60 dark
    var cardGlowColor: UIColor   // accentAction at reduced alpha, used for pill border glow
}
```

### Pattern 2: ViewModifier as Styled Shell (SquircleCard)

**What:** `SquircleCard` is a `ViewModifier` applied with a `.squircleCard()` extension method. It wraps any view's existing content without requiring structural changes to view bodies — the existing `HStack`/`VStack` layout is preserved; only the `.background/.clipShape/.shadow` tail is replaced.

**When to use:** Any time the squircle shape + glass fill + border + shadow combination appears across 2+ views. Currently: `MergeSlotRow`, `ClipCardView`, `LocalFirstTrustStrip`, output card in `MergeTimelineView`, intensity slider card in `CleaningLabView`.

**Trade-offs:**
- Pro: Composable — can layer modifiers (`.squircleCard().dragShadow()`).
- Pro: View body structure (HStack, VStack) is unchanged; diff is minimal.
- Con: Cannot inject named subview slots (header/footer regions) into a modifier; structured shell layouts need a wrapper `View` instead.

**Example:**
```swift
// Components/SquircleCard.swift
struct SquircleCardModifier: ViewModifier {
    @Environment(\.sonicMergeSemantic) private var semantic
    var applyGlow: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: SpacialTokens.squircleRadius, style: .continuous)
                    .fill(Color(uiColor: semantic.surfaceSlot))
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color(uiColor: semantic.gradientStart).opacity(0.18),
                                Color(uiColor: semantic.gradientEnd).opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: SpacialTokens.squircleRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SpacialTokens.squircleRadius, style: .continuous)
                    .strokeBorder(
                        applyGlow
                            ? Color(uiColor: semantic.cardGlowColor).opacity(0.45)
                            : Color(uiColor: semantic.accentAction).opacity(0.18),
                        lineWidth: SpacialTokens.glowBorderWidth
                    )
            )
            .shadow(color: Color.black.opacity(0.14), radius: SpacialTokens.cardShadowRadius, x: 0, y: 5)
    }
}

extension View {
    func squircleCard(glow: Bool = false) -> some View {
        modifier(SquircleCardModifier(applyGlow: glow))
    }
}
```

### Pattern 3: ButtonStyle for PillButton (not ViewModifier)

**What:** `PillButton` conforms to `ButtonStyle` (not `ViewModifier`) via `makeBody(configuration:)`. `ButtonStyle` receives a `configuration.isPressed` boolean natively and participates in `.disabled()` propagation — both behaviors are unavailable to `ViewModifier`.

**When to use:** All interactive buttons that need the pill shape + inner glow + haptic + scale press animation. Replacing the ad-hoc `.background(RoundedRectangle)` blocks on the Import, Export, Denoise, and A/B comparison buttons.

**Trade-offs:**
- Pro: `.disabled()` on a parent view correctly greys out a `ButtonStyle`; `ViewModifier` does not receive disabled state.
- Pro: `configuration.isPressed` removes the need for a manual `DragGesture` press detector.
- Con: `ButtonStyle` wraps only `Button` views; cannot be applied to non-Button tappable views (those stay as `ViewModifier` + `TapGesture`).

**Example:**
```swift
// Components/PillButton.swift
struct PillButtonStyle: ButtonStyle {
    @Environment(\.sonicMergeSemantic) private var semantic
    var variant: Variant = .primary

    enum Variant { case primary, secondary }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundStyle(variant == .primary
                ? Color(uiColor: semantic.surfaceBase)
                : Color(uiColor: semantic.accentAction))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(variant == .primary
                        ? Color(uiColor: semantic.accentAction)
                        : Color(uiColor: semantic.accentAction).opacity(semantic.glassOpacity * 0.2))
                    .shadow(
                        color: Color(uiColor: semantic.cardGlowColor).opacity(configuration.isPressed ? 0 : 0.35),
                        radius: SpacialTokens.glowBorderWidth * 8, x: 0, y: 0
                    )
            )
            .overlay(Capsule().strokeBorder(
                Color(uiColor: semantic.accentAction).opacity(variant == .secondary ? 0.6 : 0),
                lineWidth: 1.5
            ))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressing in
                if pressing {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }
}
```

### Pattern 4: MeshWaveformView — Shared Renderer with LinearGradient

**What:** A standalone `MeshWaveformView` accepts `[Float]` peaks (50 values, same array already loaded by `MergeSlotRow`, `ClipCardView`, and `CleaningLabView`) and renders symmetrical center-origin bars filled with a `LinearGradient` using `gradientStart/End` semantic tokens. Uses `LinearGradient` (iOS 13+), not `MeshGradient` (iOS 18+). No WaveformService dependency; no new data loading logic.

**When to use:** Replace three private Canvas structs — `MergeSlotWaveformView` in `MergeSlotRow.swift`, `WaveformThumbnailView` in `ClipCardView.swift`, and `WaveformCanvasView` in `CleaningLabView.swift` — with a single shared renderer.

**Trade-offs:**
- Pro: One renderer to maintain; consistent gradient appearance across all screens by construction.
- Pro: Zero changes to `WaveformService` or `loadPeaks()` data loading. The `[Float]` array contract is unchanged.
- Con: Three private structs in three different files must be deleted; each file gets a dependency on the new shared component.

**Data flow:**
```
WaveformService (unchanged) → writes .waveform sidecar (50 x Float32)
    ↓
clip.waveformSidecarURL → Data → [Float]  (existing loadPeaks() in owning view, unchanged)
    ↓
MeshWaveformView(peaks: peaks)             <- new shared component (iOS 17+ safe)
    Canvas {
        bars filled with LinearGradient(
            colors: [semantic.gradientStart, semantic.gradientEnd],
            startPoint: .top, endPoint: .bottom
        )
    }
```

### Pattern 5: AIOrb — Self-Contained Animation View

**What:** `AIOrb` is a fully self-contained `View` driven by `TimelineView(.animation)` and an internal `@State var phase: Double`. It renders a pulsating nebula sphere using `Canvas` with layered radial gradients. The only external input is `isActive: Bool`, which controls pulse speed (fast while processing, slow breathe when idle).

**When to use:** Injected into `CleaningLabView` to replace the existing `onDeviceAIHero` computed property (the static HStack with `cpu` system icon). `viewModel.isProcessing` — already a published `Bool` on `CleaningLabViewModel` — is passed directly as the `isActive` parameter.

**Trade-offs:**
- Pro: Zero coupling to business logic. `CleaningLabViewModel` is not modified at all.
- Pro: `TimelineView(.animation)` is the correct iOS 15+ API for continuous Canvas animation without triggering full SwiftUI view tree re-renders on each frame.
- Con: `TimelineView(.animation)` runs a persistent render loop while `CleaningLabView` is on screen. Pause it via an internal `@State var orbVisible: Bool` controlled by `.onAppear`/`.onDisappear` to prevent the loop when a sheet covers the view.

**Integration into CleaningLabView:**
```swift
// BEFORE (existing onDeviceAIHero — to be removed)
private var onDeviceAIHero: some View {
    HStack(alignment: .top, spacing: 10) {
        Image(systemName: "cpu") ...
    }
}

// AFTER (restyle — replaces onDeviceAIHero in body VStack)
AIOrb(isActive: viewModel.isProcessing)
    .frame(width: 140, height: 140)
    .padding(.vertical, 12)

// CleaningLabViewModel is untouched — isProcessing: Bool is already there
```

### Pattern 6: Central Timeline Connector Line

**What:** A 2pt vertical line overlaid on `MergeTimelineView`'s content using a `ZStack` wrapper around the `List`. The line runs vertically along a fixed left-offset position. It is purely decorative with no data or interaction.

**When to use:** `MergeTimelineView.body` modification only — no ViewModel, no model changes.

**Trade-offs:**
- Pro: Pure rendering; zero logic risk.
- Con: SwiftUI `List` does not expose inner coordinate space reliably. Use a fixed left offset of `36pt` (matching the 16pt `listRowInsets` leading + card padding origin). The line is a visual decoration, not a data-bound position.

**Implementation approach:**
```swift
// MergeTimelineView.body — wrap existing List in ZStack
ZStack(alignment: .topLeading) {
    // existing List(...)

    // Connector line overlay — behind list content, clipped to content area
    Rectangle()
        .fill(Color(uiColor: semantic.accentAction).opacity(0.25))
        .frame(width: SpacialTokens.timelineStrokeWidth)
        .padding(.leading, 36)
        .padding(.vertical, 80)   // inset from first/last item
        .allowsHitTesting(false)
}
```

### Pattern 7: Theme Switching — Existing Mechanism, Zero Changes

**What:** Theme switching already works via `@AppStorage("sonicMergeThemePreference")` → `ThemePreference` enum → `SonicMergeSemantic.resolved(colorScheme:preference:)` in `MixingStationView` → `.environment(\.sonicMergeSemantic, semantic)`. All new components in the `Components/` folder read via `@Environment(\.sonicMergeSemantic)`. No new injection mechanism is needed.

**When to use:** No code is needed here — this pattern is already operational. New tokens (`gradientStart/End`, `aiHighlight`, etc.) just need to be populated in both `lightClassic()` and `darkConveyor()` branches of `SonicMergeSemantic`.

**Trade-offs:**
- Pro: Zero architecture change for theme switching. The existing `@AppStorage` picker in the toolbar menu continues to work.
- Con: `SonicMergeSemantic` is a struct injected as a value type. If `lightClassic()` or `darkConveyor()` forgets to set a new property, it compiles fine (struct init) — but review both branches when adding each new token.

---

## Data Flow

### Design Token → Rendered Pixel

```
AppStorage("sonicMergeThemePreference")      [user preference, persisted]
    ↓
SonicMergeSemantic.resolved(colorScheme:preference:)    [MixingStationView, computed property]
    ↓  .environment(\.sonicMergeSemantic, semantic)
All descendant views read via @Environment(\.sonicMergeSemantic)
    ↓
semantic.gradientStart / semantic.aiHighlight / semantic.glassOpacity
    ↓
MeshWaveformView(peaks:)      →  Canvas LinearGradient bars (iOS 17+)
AIOrb(isActive:)              →  Canvas radialGradient pulsation
SquircleCardModifier          →  RoundedRectangle + LinearGradient overlay
GlassmorphHeader              →  .ultraThinMaterial + indigo glow border
PillButtonStyle               →  Capsule shape + glow shadow + haptic
```

### Waveform Gradient Data Flow

```
WaveformService.generate()        [actor, unchanged]
    → writes .waveform sidecar binary (50 x Float32) to App Group container

MergeSlotRow / ClipCardView / CleaningLabView
    loadPeaks()                   [existing func, unchanged]
    → @State var peaks: [Float]

MeshWaveformView(peaks: peaks)    [new shared component]
    Canvas { context, size in
        for (i, peak) in peaks.enumerated() {
            // bar rect centered on y-axis
            context.fill(path, with: .linearGradient(
                Gradient(colors: [gradientStart, gradientEnd]),
                startPoint: topCenter, endPoint: bottomCenter
            ))
        }
    }
```

### AIOrb Animation Data Flow

```
CleaningLabViewModel.isProcessing: Bool   [unchanged @Observable property]
    ↓ passed as value parameter (not observed inside AIOrb)

AIOrb(isActive: viewModel.isProcessing)
    TimelineView(.animation) { context in
        let phase = context.date.timeIntervalSince1970.truncatingRemainder(dividingBy: period)
        // period = isActive ? 0.8s : 2.5s
    }
    Canvas { context, size in
        // radialGradient(aiHighlight, transparent) at scale driven by sin(phase)
        // opacity = 0.6 + 0.4 * sin(phase * .pi * 2)
        // scale  = 0.85 + 0.15 * sin(phase * .pi * 2)
    }
```

### PillButton Haptic Flow

```
PillButtonStyle.makeBody(configuration:)
    configuration.isPressed: Bool        [native ButtonStyle, no DragGesture needed]
    .onChange(of: configuration.isPressed) { _, pressing in
        if pressing { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }
    → .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
    → inner glow shadow opacity: pressed=0, released=0.35
    [No ViewModel involvement — pure rendering state within ButtonStyle]
```

---

## Integration Points

### Existing Token Usage → New Replacement Mapping

| Existing Pattern in Views | Current Token | Restyle Change |
|--------------------------|---------------|----------------|
| `SonicMergeTheme.Radius.card` (12pt) on clip cards | 12pt | Replace with `SpacialTokens.squircleRadius` (24pt) for card shapes; keep 12pt for inner elements like chips |
| `accentWaveform` UIColor flat fill in Canvas bars | Solid `accentWaveform` | Replace with `LinearGradient(gradientStart, gradientEnd)` in `MeshWaveformView` |
| `.shadow(color: .black.opacity(0.06), radius: 8)` ad-hoc | Hardcoded | Centralize to `SpacialTokens.cardShadowRadius = 12`; drag state uses `SpacialTokens.dragShadowRadius = 20` |
| `Color(uiColor: semantic.accentAction).opacity(0.12)` as glass-like background | Ad-hoc opacity | Replace with `semantic.glassOpacity` for consistent glass depth; use `.ultraThinMaterial` where blur is desired |
| `semantic.trustIcon` on `onDeviceAIHero` cpu icon | trustIcon | Replaced entirely by `AIOrb` component; `trustIcon` remains for `LocalFirstTrustStrip` |

### New Component → Injection Point Map

| New Component | File Modified | Injection Point |
|---------------|---------------|-----------------|
| `SquircleCard` modifier | `MergeSlotRow.swift` | Replace `.background(RoundedRectangle...)/.clipShape/.shadow` block |
| `SquircleCard` modifier | `ClipCardView.swift` | Replace `.background(Color(uiColor: semantic.cardSurface))/.clipShape/.shadow` block |
| `SquircleCard` modifier | `TrustSignalViews.swift` — `LocalFirstTrustStrip` | Replace `.background/.clipShape/.overlay/.shadow` block |
| `SquircleCard` modifier | `MergeTimelineView.swift` — `mergeOutputCard` | Replace `RoundedRectangle.fill(surfaceSlot)` + `.overlay` block |
| `SquircleCard` modifier | `CleaningLabView.swift` — `intensitySlider` | Replace `.background/.clipShape/.shadow` |
| `MeshWaveformView` | `MergeSlotRow.swift` | Delete private `MergeSlotWaveformView` struct; pass `peaks` to `MeshWaveformView` |
| `MeshWaveformView` | `ClipCardView.swift` | Delete private `WaveformThumbnailView` struct; pass `peaks` to `MeshWaveformView` |
| `MeshWaveformView` | `CleaningLabView.swift` | Delete private `WaveformCanvasView` struct; pass `viewModel.waveformPeaks` to `MeshWaveformView` |
| `AIOrb` | `CleaningLabView.swift` | Delete `onDeviceAIHero` computed var; insert `AIOrb(isActive: viewModel.isProcessing)` at top of body VStack |
| `PillButtonStyle` | `MixingStationView.swift` — empty state button | Apply `.buttonStyle(PillButtonStyle())` to "Import Audio" button |
| `PillButtonStyle` | `MergeTimelineView.swift` — export button | Apply `.buttonStyle(PillButtonStyle())` to output card export button |
| `PillButtonStyle` | `CleaningLabView.swift` — `denoiseActionButton`, `abComparisonButton` | Apply `.buttonStyle(PillButtonStyle(variant: .secondary))` to A/B button |
| `GlassmorphHeader` | `MixingStationView.swift` | Add as `.safeAreaInset(edge: .top)` or as a `Section` header in `NavigationStack` |
| Timeline connector line | `MergeTimelineView.swift` | Wrap existing `List` body in `ZStack`; add overlay `Rectangle` |
| `GapRowView` glass style | `GapRowView.swift` | Replace `.background(surfaceElevated.opacity(0.65))` with `.ultraThinMaterial` + tinted overlay |

### Internal Boundaries (Restyle-Specific)

| Boundary | Communication | Constraint |
|----------|---------------|------------|
| DesignSystem ↔ Components | `@Environment(\.sonicMergeSemantic)` | Components only read tokens from environment; never import ViewModels or Services |
| Components ↔ Feature Views | SwiftUI composition (`.modifier()`, `.buttonStyle()`, direct init) | No callbacks or state flow upward from Components to Feature Views |
| `AIOrb` ↔ `CleaningLabView` | Single `isActive: Bool` value parameter | `CleaningLabViewModel` is not injected into `AIOrb`; animation logic is fully isolated |
| `MeshWaveformView` ↔ Feature Views | `peaks: [Float]` value array only | `MeshWaveformView` has no reference to `WaveformService` or `AudioClip`; data flows one way |
| `SonicMergeSemantic` tokens ↔ new components | Same `EnvironmentKey` path already established | No new injection mechanism; `MixingStationView` already injects `.environment(\.sonicMergeSemantic, semantic)` which propagates to all descendants including new `Components/` views |

---

## Suggested Build Order

Build from stable foundation to complex consumers. Each step leaves the app in a compilable, runnable state.

```
STEP 1 — Token Foundation  [no visual change; pure Swift additions]
  - Extend SonicMergeTheme: add spatialRadius=24, glowIntensity constant
  - Extend SonicMergeSemantic: add gradientStart/End, aiHighlight, glassOpacity, cardGlowColor
      populate both lightClassic() and darkConveyor() branches
  - New SpacialTokens.swift: squircleRadius=24, cardShadowRadius=12, dragShadowRadius=20,
      glassBlurRadius=16, timelineStrokeWidth=2, glowBorderWidth=1

STEP 2 — Shared Components  [no feature files touched; fully testable in Previews]
  - SquircleCard.swift (ViewModifier)        depends on: SpacialTokens, SonicMergeSemantic
  - PillButton.swift (ButtonStyle)           depends on: SpacialTokens, SonicMergeSemantic
  - MeshWaveformView.swift (Canvas View)    depends on: SonicMergeSemantic (gradient tokens)
  At this point: all three can be previewed with mock data. Zero feature file changes.

STEP 3 — Clip Card Layer  [highest-frequency component; validates SquircleCard + MeshWaveformView]
  - MergeSlotRow.swift: delete MergeSlotWaveformView, inject MeshWaveformView, apply SquircleCard
  - ClipCardView.swift: delete WaveformThumbnailView, inject MeshWaveformView mini, apply SquircleCard
  Risk: These components appear on the main screen on every app launch.
  Verify dark + light mode. Confirm 24pt squircle radius matches target spec.

STEP 4 — Gap Row + Timeline Structure  [after clip cards are stable]
  - GapRowView.swift: glass background (.ultraThinMaterial + tint overlay), pill segment visuals
  - MergeTimelineView.swift: central connector line ZStack, output card SquircleCard, section headers

STEP 5 — MixingStation Header + Navigation  [after timeline content is stable]
  - GlassmorphHeader.swift: .ultraThinMaterial banner component, indigo glow border
  - MixingStationView.swift: inject GlassmorphHeader, PillButtonStyle on empty state button
  - TrustSignalViews.swift: apply SquircleCard to LocalFirstTrustStrip

STEP 6 — CleaningLab + AIOrb  [after token + waveform components are proven stable]
  - AIOrb.swift: TimelineView-driven pulsating nebula sphere, isActive:Bool parameter
  - CleaningLabView.swift:
      delete onDeviceAIHero, insert AIOrb(isActive: viewModel.isProcessing)
      delete WaveformCanvasView, inject MeshWaveformView(peaks: viewModel.waveformPeaks)
      apply PillButtonStyle to denoiseActionButton and abComparisonButton
      apply SquircleCard to intensitySlider card

STEP 7 — Dark Mode Validation Pass  [verification, not a build step]
  - Verify all new SonicMergeSemantic tokens produce correct contrast in darkConveyor():
      aiHighlight: Lime Green #A7C957
      gradientStart: Deep Indigo #5856D6
      surfaceBase: pure black #000000
  - Manual device check: AIOrb visibility, MeshWaveformView bar contrast, PillButton glow readability
  - Confirm MeshWaveformView renders correctly on iOS 17 device/simulator (LinearGradient path)
```

**Rationale for this order:**

- Steps 1–2 produce zero visible change and establish a stable, shared API. All later steps reference named tokens and modifiers that will not change names.
- Step 3 is the highest-risk visual change because clip cards appear immediately on the main screen. Done early while `CleaningLabView` is untouched — a regression in clip cards is isolated and easy to bisect.
- Step 6 (AIOrb + CleaningLab) comes after `MeshWaveformView` is proven. `CleaningLabView` receives both `AIOrb` and `MeshWaveformView` in the same step; doing `MeshWaveformView` first (Step 2) reduces compound risk.
- Step 7 is validation, not development. Dark mode tokens are populated in Step 1 but visually verified end-to-end only after all screens are complete.

---

## Anti-Patterns

### Anti-Pattern 1: Using MeshGradient API Directly

**What people do:** Use `MeshGradient(width: 3, height: 3, points: [...], colors: [...])` in `MeshWaveformView` or as a card background.

**Why it's wrong:** `MeshGradient` requires iOS 18+. SonicMerge targets iOS 17.0+. Any use without `if #available(iOS 18, *)` causes a compile error in Xcode or a crash on iOS 17 at runtime. The milestone description says "mesh gradient waveforms" — this is a visual aesthetic goal (multi-color gradient bars), not an API mandate.

**Do this instead:** Use `LinearGradient` with Deep Indigo → Purple stops inside `Canvas` for the waveform renderer. If a background `MeshGradient` is later deemed important for iOS 18 users, wrap it: `if #available(iOS 18, *) { MeshGradient(...) } else { LinearGradient(...) }`.

### Anti-Pattern 2: Hardcoding Colors Directly in View Bodies

**What people do:** Write `Color(red: 88/255, green: 86/255, blue: 214/255)` or `Color(#colorLiteral(...))` directly in `MergeSlotRow.body` or `CleaningLabView.body` for new gradient colors.

**Why it's wrong:** Creates a parallel second design system diverging from `SonicMergeSemantic` immediately. The existing codebase already has one instance of this — hardcoded amber values in `CleaningLabView.staleBanner` — which is exactly the kind of tech debt this restyle should not repeat.

**Do this instead:** Every new color lives as a token in `SonicMergeSemantic` (adaptive values) or `SpacialTokens` (structural constants). Views reference token names only.

### Anti-Pattern 3: Animating ViewModel Properties for Visual State

**What people do:** Add `@Published var orbPulsePhase: Double` or `@Published var waveformGradientOffset: Double` to `CleaningLabViewModel`, drive it with a `Timer`, and bind animated views to it.

**Why it's wrong:** Animation state is rendering state, not business state. Leaking it into the ViewModel violates MVVM boundaries and creates spurious test surface for UI concerns. The project constraint explicitly states ViewModels are untouched.

**Do this instead:** Use `TimelineView(.animation)` + internal `@State` inside `AIOrb`. The ViewModel exposes only `isProcessing: Bool` — a semantic fact, not a visual instruction.

### Anti-Pattern 4: Replacing Existing Token Names

**What people do:** Rename `accentAction` to `indigoAccent`, or change `surfaceSlot`'s value to match the new dark aesthetic.

**Why it's wrong:** Every existing view uses `semantic.accentAction` and `semantic.surfaceSlot`. Renaming causes a compile-error cascade across all files simultaneously, forcing a big-bang migration that cannot be incremental or safely bisected.

**Do this instead:** Add new properties (`gradientStart`, `aiHighlight`). Existing properties keep their exact names and values. After all views are fully restyled, consolidate in a follow-up cleanup commit.

### Anti-Pattern 5: Building a Separate ThemeManager / EnvironmentObject

**What people do:** Create a new `@Observable ThemeManager` class, inject it as `.environmentObject`, and have new components read from it instead of `SonicMergeSemantic`.

**Why it's wrong:** `SonicMergeSemantic` already exists as a SwiftUI `EnvironmentKey` with correct light/dark resolution and user-preference override via `@AppStorage`. Adding a parallel mechanism creates two sources of truth for theme state.

**Do this instead:** Extend the existing `SonicMergeSemantic` struct with new properties. No new injection mechanism is needed; new components read via the same `@Environment(\.sonicMergeSemantic)` key already present in the codebase.

### Anti-Pattern 6: Using ViewModifier Instead of ButtonStyle for Pill Buttons

**What people do:** Apply `.modifier(PillButtonModifier())` to a `Button` and track press state with a manual `DragGesture(minimumDistance: 0)`.

**Why it's wrong:** `ViewModifier` does not receive `.disabled()` state from the parent hierarchy. A disabled button wrapped in a `ViewModifier` will still render as if active. `DragGesture` press tracking is also unreliable — it can miss the initial touch if the scroll view intercepts it.

**Do this instead:** Conform to `ButtonStyle`. `configuration.isPressed` is accurate, and `.disabled()` from the parent (e.g., `.disabled(viewModel.isExporting)`) correctly dims the button.

### Anti-Pattern 7: Modifying WaveformService for Visual Output

**What people do:** Change `WaveformService` to also return gradient color stops, or add a `renderingStyle: WaveformRenderingStyle` parameter.

**Why it's wrong:** `WaveformService` is a Service layer actor (data extraction). It returns `[Float]` amplitude values — format-agnostic and shared between the main app and future consumers. Rendering decisions belong in the View layer.

**Do this instead:** `MeshWaveformView` owns the rendering decision in full. It accepts `[Float]` from the existing `loadPeaks()` result and applies gradient coloring inside its `Canvas`. `WaveformService` is untouched.

---

## Sources

- Direct codebase inspection (HIGH confidence): `SonicMergeTheme.swift`, `SonicMergeTheme+Appearance.swift`, `MergeSlotRow.swift`, `ClipCardView.swift`, `CleaningLabView.swift`, `MergeTimelineView.swift`, `GapRowView.swift`, `WaveformService.swift`, `TrustSignalViews.swift`, `MixingStationView.swift`
- `MeshGradient` iOS 18 minimum requirement — [Apple Developer Documentation: MeshGradient](https://developer.apple.com/documentation/SwiftUI/MeshGradient) and [Donny Wals: Mesh Gradients in SwiftUI](https://www.donnywals.com/getting-started-with-mesh-gradients-on-ios-18/) (HIGH confidence, official source verified)
- `ButtonStyle` protocol for `.disabled()` propagation and `configuration.isPressed` — [SwiftUI ButtonStyle: Antoine van der Lee](https://www.avanderlee.com/swiftui/swiftui-button-styles/) and [fatbobman: Custom Button Style in SwiftUI](https://fatbobman.com/en/posts/custom-button-style-in-swiftui/) (HIGH confidence, verified against Apple docs behavior)
- `EnvironmentKey` for design token propagation — existing pattern already operational in `SonicMergeTheme+Appearance.swift` (HIGH confidence, directly verified)
- `RoundedRectangle(cornerRadius: 24, style: .continuous)` as SwiftUI squircle — [Apple Developer Documentation: RoundedCornerStyle.continuous](https://developer.apple.com/documentation/swiftui/roundedcornerstyle/continuous) (HIGH confidence)
- `.ultraThinMaterial` for glassmorphism backgrounds — iOS 15+ SwiftUI Material API (HIGH confidence)
- `TimelineView(.animation)` + `Canvas` for continuous animation without full view tree re-render — iOS 15+ SwiftUI API, pattern already used in existing Canvas waveform renderers in the project (HIGH confidence)
- `UIImpactFeedbackGenerator` for haptic response — standard iOS pattern, iOS 10+ (HIGH confidence)

---

*Architecture research for: SonicMerge v1.1 Modern Spatial Utility Restyle*
*Researched: 2026-04-11 (updated from 2026-04-08)*
