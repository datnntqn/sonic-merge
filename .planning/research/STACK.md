# Stack Research

**Domain:** iOS audio processing utility (merge + on-device AI denoising) + Modern Spatial Utility UI restyle
**Researched:** 2026-04-11 (v1.1 UI restyle re-verified); original audio stack 2026-03-08
**Confidence:** HIGH (all UI-restyle APIs verified against Apple Developer Documentation, WWDC session notes, and multiple authoritative developer sources; audio stack unchanged from v1.0)

---

## iOS Version Impact — UI Restyle

The entire restyle can be implemented within the existing iOS 17.0+ minimum. Only `MeshGradient` requires iOS 18, and a `#available(iOS 18, *)` guard with a `LinearGradient` fallback makes it non-blocking. **No minimum version bump is required.**

| Visual Effect | Required iOS | API | Notes |
|--------------|-------------|-----|-------|
| Glassmorphism / frosted glass header | iOS 15.0 | `Material` (.ultraThinMaterial) | Well within iOS 17 floor |
| Squircle corners 24pt | iOS 13.0 | `RoundedRectangle(cornerRadius:style:.continuous)` | `.continuous` produces Apple superellipse; `.cornerRadius()` modifier deprecated iOS 17+ |
| Per-corner radius | iOS 17.0 | `UnevenRoundedRectangle` | At project floor; use if pill-top/square-bottom variants emerge |
| AI Orb pulsating animation | iOS 15.0 | `Canvas` + `TimelineView(.animation)` | No extra dependency; sine-wave modulation over concentric ellipses |
| Multi-phase orb / button animation | iOS 17.0 | `PhaseAnimator` / `KeyframeAnimator` | Cleaner declarative alternative to raw TimelineView for discrete named states |
| Pill-shaped buttons | iOS 13.0 | `Capsule` shape | |
| Inner glow on buttons | iOS 16.0 | `ShadowStyle.inner(color:radius:x:y:)` | Well within iOS 17 floor |
| Outer colored glow / shadow | iOS 13.0 | `shadow(color:radius:x:y:)` | Apply as standalone modifier, not inside `visualEffect` block |
| Elevated drag shadow micro-interaction | iOS 13.0 | `DragGesture` + `scaleEffect` + `shadow` | No new API; standard pattern |
| Haptic-responsive button states | iOS 17.0 | `sensoryFeedback(_:trigger:)` | Native SwiftUI haptics; no UIKit bridge needed |
| Scroll-driven card entrance | iOS 17.0 | `scrollTransition(_:axis:transition:)` | At project floor |
| Non-layout visual transforms | iOS 17.0 | `visualEffect(_:)` | Safe for geometry-dependent effects without layout cost |
| Mesh gradient waveforms | **iOS 18.0** | `MeshGradient` | Requires `#available(iOS 18, *)` guard + LinearGradient fallback; iOS 18 confirmed by WWDC24 |
| Vertical timeline layout | iOS 15.0 | `LazyVStack` + `ZStack` + `Rectangle` (1pt line) | Pure SwiftUI composition |
| Design token color system | iOS 13.0 | `Color` static extension | Semantic naming via `static let deepIndigo`, `limeGreen`, etc. |

---

## Part 1: UI Restyle — Modern Spatial Utility Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| SwiftUI | iOS 17+ (project floor) | All UI layer | Native; all restyle effects achievable without third-party libraries |
| `Canvas` | iOS 15+ | AI Orb nebula drawing | Imperative 2D drawing within SwiftUI; renders outside layout engine; GPU-accelerated via Metal; supports time-driven mutation via TimelineView |
| `TimelineView(.animation)` | iOS 15+ | Drive orb pulse loop at display refresh rate | Updates at display cadence (60/120fps); pairs with Canvas for continuous sine-wave pulsation without @State churn |
| `PhaseAnimator` / `KeyframeAnimator` | iOS 17+ | Multi-phase orb and button state animations | Declarative named phases replace manual state machines; no availability guard needed at iOS 17 floor |
| `Material` (SwiftUI) | iOS 15+ | Glassmorphism frosted-glass header | Real-time Gaussian blur backed by `UIVisualEffectView`; `.ultraThinMaterial` is thinnest/most translucent — correct for tinted glass header |
| `MeshGradient` | **iOS 18+** | Animated mesh waveform overlay on audio cards | 2D grid-of-colors gradient rendered fast on GPU; wrap with `if #available(iOS 18, *)` and fall back to animated `LinearGradient` |

### Supporting APIs

| API | iOS Min | Purpose | Notes |
|-----|---------|---------|-------|
| `RoundedRectangle(cornerRadius: 24, style: .continuous)` | iOS 13 | Squircle audio cards | Use `.clipShape()`, never deprecated `.cornerRadius()` modifier; `.continuous` produces the Apple superellipse ("squircle") |
| `UnevenRoundedRectangle` | iOS 17 | Per-corner radius | Not needed for uniform 24pt cards; available if variants emerge |
| `Capsule` shape | iOS 13 | Pill-shaped button container | Produces perfect semicircle ends; combine with `.overlay(Capsule().inset(by:1).stroke(...))` for inner highlight ring |
| `ShadowStyle.inner(color:radius:x:y:)` | iOS 16 | Inner glow simulation on button face | Renders shadow inside shape boundary; available since iOS 16.0 |
| `shadow(color:radius:x:y:)` | iOS 13 | Outer colored glow / elevated drag shadow | Compose as separate modifier outside `visualEffect` |
| `DragGesture` + `@GestureState` | iOS 13 | Elevated card shadow on drag | `isDragging` GestureState drives `scaleEffect(1.04)` + `shadow(radius: 20)` |
| `scrollTransition(_:axis:transition:)` | iOS 17 | Card entrance/exit scroll animation | Phases: `.identity` (visible), `.topLeading`, `.bottomTrailing`; apply scale + opacity for spatial depth |
| `visualEffect(_:)` | iOS 17 | Geometry-dependent transforms without layout cost | Does not trigger expensive layout recalculation; ideal for scroll-linked parallax |
| `sensoryFeedback(_:trigger:)` | iOS 17 | Haptic feedback on button tap and drag events | `.impact(.medium)` for tap; `.selection` for reorder; no UIKit bridge |
| `withAnimation(.spring(response:dampingFraction:))` | iOS 13 | Spring micro-interactions | Tuned spring for elastic card lift and settle |
| `Color` static extension (design tokens) | iOS 13 | Semantic color token system | `static let deepIndigo = Color(hex: "#5856D6")`, `limeGreen = Color(hex: "#A7C957")`, etc. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 16+ | Required to compile `MeshGradient` code paths | Even with iOS 17 floor, Xcode 16 is needed to resolve the `#available(iOS 18, *)` branch |
| SwiftUI Previews (`#Preview` macro) | Live iteration on isolated visual components | Use `.colorScheme(.dark)` and `.colorScheme(.light)` variants in the same preview macro |
| Instruments > Metal System Trace | Validate Canvas / TimelineView orb GPU load | Confirms stable 60fps on A14+ devices; Canvas draws on Metal |

---

### Implementation Patterns

#### Design Token Color System

```swift
// Extensions/Color+Theme.swift
extension Color {
    // Brand
    static let deepIndigo   = Color(hex: "#5856D6")
    static let limeGreen    = Color(hex: "#A7C957")
    static let pureBlack    = Color(hex: "#000000")
    static let offWhite     = Color(hex: "#FBFBFC")

    // Semantic tokens
    static var appBackground: Color { Color(uiColor: .systemBackground) }
    static var cardBackground:  Color { Color(uiColor: .secondarySystemBackground) }
    static var primaryLabel:    Color { Color(uiColor: .label) }
}
```

Use `Color(uiColor:)` with semantic `UIColor` system values for any token that needs automatic light/dark adaptation. Use explicit hex only for brand-fixed values (Deep Indigo, Lime Green) that do not change between modes.

#### Glassmorphism Header

```swift
.background {
    ZStack {
        Color.deepIndigo.opacity(0.12)         // Indigo tint layer
        Rectangle().fill(.ultraThinMaterial)   // Frosted blur layer
    }
    .ignoresSafeArea()
}
```

`Material` requires visually distinct background content scrolling behind it to produce visible blur. Ensure audio cards scroll beneath the header, not beside it.

#### Squircle Cards (24pt radius)

```swift
.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
.background(
    RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(Color.cardBackground)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
)
```

Never use `.cornerRadius(24)` — deprecated in iOS 17 and silently uses the older `.circular` arc style.

#### MeshGradient Waveform with iOS 17 Fallback

```swift
Group {
    if #available(iOS 18, *) {
        MeshGradient(
            width: 3, height: 3,
            points: animatedPoints,    // @State var toggled in withAnimation
            colors: [
                Color(hex: "#3D3593"), Color(hex: "#5856D6"), Color(hex: "#9B8FFF"),
                Color(hex: "#5856D6"), Color(hex: "#7B6FE8"), Color(hex: "#5856D6"),
                Color(hex: "#3D3593"), Color(hex: "#5856D6"), Color(hex: "#9B8FFF")
            ]
        )
    } else {
        LinearGradient(
            colors: [Color(hex: "#3D3593"), Color(hex: "#5856D6"), Color(hex: "#9B8FFF")],
            startPoint: .leading, endPoint: .trailing
        )
    }
}
.opacity(0.35)   // semi-transparent overlay on waveform area
```

Animate MeshGradient points via `withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true))` toggling between two point configurations. Point positions are `SIMD2<Float>` values in the `[0,1]` unit square.

#### AI Orb (Pulsating Nebula) — TimelineView + Canvas Approach

```swift
TimelineView(.animation) { timeline in
    Canvas { context, size in
        let t = timeline.date.timeIntervalSinceReferenceDate
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for layer in 0..<4 {
            let phase  = Double(layer) * .pi / 2
            let pulse  = (sin(t * 1.4 + phase) + 1) / 2   // 0...1
            let radius = 40 + pulse * 20 + Double(layer) * 12
            let opacity = 0.6 - Double(layer) * 0.12
            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - radius, y: center.y - radius,
                    width: radius * 2,    height: radius * 2
                )),
                with: .color(Color.deepIndigo.opacity(opacity))
            )
        }
    }
}
```

#### AI Orb — PhaseAnimator Approach (preferred for discrete states)

Use `PhaseAnimator` (iOS 17) when the orb has named discrete states (idle → processing → complete):

```swift
PhaseAnimator([OrbPhase.idle, .pulsing, .done], trigger: isProcessing) { phase in
    OrbView(scale: phase.scale, glowRadius: phase.glowRadius, color: phase.color)
} animation: { phase in
    .spring(response: 0.6, dampingFraction: 0.5)
}
```

PhaseAnimator is cleaner than raw TimelineView when there are more than two named animation states. Use TimelineView + Canvas when the orb must animate continuously every frame regardless of processing state.

#### Pill Buttons with Inner Glow

```swift
Button(action: { tapCount += 1; onTap() }) {
    Text(label)
        .fontWeight(.semibold)
        .padding(.horizontal, 32).padding(.vertical, 14)
        .foregroundStyle(.white)
}
.background(
    Capsule()
        .fill(Color.deepIndigo)
        .shadow(color: Color.deepIndigo.opacity(0.55), radius: 12, y: 4)   // outer glow
)
.overlay(
    Capsule()
        .inset(by: 1)
        .stroke(Color.white.opacity(0.25), lineWidth: 1.5)   // inner highlight ring
)
.sensoryFeedback(.impact(.medium), trigger: tapCount)
```

The "inner glow" is achieved by two separate layers: `ShadowStyle.inner` applied via `.fill(.shadow(.inner(...)))` adds inward blur, while the `.inset(by:1).stroke(...)` overlay adds the visible highlight ring. Both together produce the lit-from-inside effect.

#### Elevated Drag Shadows (Micro-interaction)

```swift
@GestureState private var isDragging = false

cardView
    .scaleEffect(isDragging ? 1.04 : 1.0)
    .shadow(
        color: .black.opacity(isDragging ? 0.28 : 0.08),
        radius: isDragging ? 20 : 6,
        y: isDragging ? 8 : 2
    )
    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
    .gesture(
        DragGesture(minimumDistance: 0)
            .updating($isDragging) { _, state, _ in state = true }
    )
```

#### Vertical Timeline Layout (Connecting Line)

```swift
LazyVStack(alignment: .leading, spacing: 12) {
    ForEach(clips) { clip in
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                Circle().fill(Color.deepIndigo)
                    .frame(width: 10, height: 10)
                    .padding(.top, 14)
                Rectangle().fill(Color.deepIndigo.opacity(0.3))
                    .frame(width: 2)
            }
            .frame(width: 24)
            AudioCardView(clip: clip)
                .padding(.leading, 8)
        }
    }
}
```

---

### Alternatives Considered — UI Restyle

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `Canvas` + `TimelineView` for orb | `SceneKit` / `RealityKit` sphere | Only if orb needs genuine 3D lighting with specular highlights; overkill for 2D pulsing circle |
| `.ultraThinMaterial` | `UIVisualEffectView` via `UIViewRepresentable` | Only if a custom blur style not in SwiftUI's `Material` enum is needed (e.g., `.systemChromeMaterial`) |
| `MeshGradient` with `#available` guard | Third-party gradient library | Never — project constraint is native frameworks only |
| `PhaseAnimator` for orb states | `withAnimation` + multiple `@State` flags | PhaseAnimator cleaner for > 2 named states; raw `@State` fine for simple two-state toggle |
| `sensoryFeedback` (iOS 17) | `UIImpactFeedbackGenerator` | Use `UIImpactFeedbackGenerator` only when haptic timing must be triggered from a non-SwiftUI callback (e.g., AVFoundation completion handler) |

### What NOT to Use — UI Restyle

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `.cornerRadius()` modifier | Deprecated iOS 17+; silently uses `.circular` arc, not the squircle `.continuous` style | `.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))` |
| Third-party animation or gradient packages | Project constraint: native Apple frameworks only; no SPM additions for UI | `MeshGradient`, `Canvas`, `PhaseAnimator` |
| `SpriteKit` for the orb | Heavy game-framework overhead for a 2D pulsating circle; adds 1–2MB to binary | `Canvas` + `TimelineView` — zero overhead, runs on Metal |
| Placing `shadow()` inside `visualEffect` block | Shadow is a rendering modifier, not a geometric transform; ignored or silently broken inside `visualEffect` | Apply `shadow()` as a separate standalone modifier outside `visualEffect` |
| Calling `MeshGradient` without `#available` guard | `MeshGradient` is iOS 18+ only; compile error on Xcode 15 / iOS 17 targets | `if #available(iOS 18, *) { MeshGradient(...) } else { LinearGradient(...) }` |
| Raising minimum deployment to iOS 18 | Excludes all users still on iOS 17; unnecessary — only one feature needs the guard | Keep iOS 17.0 floor; gate MeshGradient only |
| Metal `.metal` shader files for orb | Correct tool for complex GPU effects, but adds `.metal` build phase + shader compilation overhead for an effect achievable with Canvas | `Canvas` + `TimelineView` sufficient; add Metal only if orb needs per-pixel noise/distortion effects |

---

## Part 2: Audio Stack (Unchanged from v1.0)

*(Original stack research preserved below — no changes for v1.1 milestone)*

### Core Technologies

| Technology | Version / Requirement | Purpose | Why Recommended |
|---|---|---|---|
| Swift 6 | Xcode 16+ | Language | Strict concurrency enforces correct audio pipeline isolation; Sendable-aware async/await prevents data races in AVFoundation callbacks |
| SwiftUI | iOS 17.0+ | UI layer | Native to the platform; Timeline, drag-and-drop, and gesture APIs are mature enough for the clip-ordering UX |
| AVFoundation / AVMutableComposition | iOS 4.0+ (stable API) | Audio composition and export | The canonical Apple API for non-destructive multi-track audio assembly; no alternative exists at this level that remains first-party |
| AVFAudio / AVAudioEngine | iOS 8.0+ | DSP graph, voice processing | Hosts the denoising pipeline; supports offline manual rendering mode for file-based (non-realtime) processing |
| AVAudioEngine Voice Processing (setVoiceProcessingEnabled) | iOS 13.0+ | On-device noise suppression | Native, zero-model-file approach; Apple tuned for speech; integrates directly into AVAudioEngine graph; no Core ML model to ship or maintain |
| Accelerate / vDSP | iOS 4.0+ | PCM downsampling for waveform | Vectorized math; 50,000%+ faster than naive loops for amplitude downsampling across millions of audio frames |
| UniformTypeIdentifiers | iOS 14.0+ | Audio UTType matching in Share Extension | Modern replacement for string-based UTI; UTType.audio, UTType.wav, UTType.m4a are strongly typed |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---|---|---|---|
| DSWaveformImage | 14.0.0 (SPM) | Waveform rendering from audio file | Use for per-clip waveform thumbnails in the card UI; supports async/await and SwiftUI WaveformView natively. iOS 15.0+ minimum. |
| spfk-loudness | latest (SPM) | EBU R128 / LUFS loudness measurement | Use when computing integrated loudness before normalization gain calculation; wraps libebur128 via Obj-C bridge; gives LUFS, true peak, LRA |

Note: Both libraries are optional. DSWaveformImage can be replaced by a pure native approach (see Stack Patterns). spfk-loudness can be replaced by manual ITU-R BS.1770 implementation using vDSP — but that is significant DSP work.

### Decisions by Feature Area

#### Audio Composition: AVMutableComposition

**Use:** `AVMutableComposition` + `AVMutableCompositionTrack` + `AVAssetExportSession`

**Rationale:** AVMutableComposition is the only first-party API for constructing a non-destructive, time-indexed multi-track composition from existing audio assets. Alternatives (raw PCM buffer concatenation via AVAudioFile) work but forfeit seeking, time-range precision, and the clean separation between editing model and export.

**Swift 6 note:** `AVAssetExportSession` does not conform to `Sendable` and the native async `.export(to:as:isolation:)` method is iOS 18+ only. For iOS 17 targets, wrap `exportAsynchronously(completionHandler:)` in `withCheckedContinuation`. Keep the export session and its composition off `@MainActor` to avoid isolation crossing errors.

**Silent gaps:** Insert a silent audio file (generated as AVAudioPCMBuffer of zeroed samples, written to a temp file) at the appropriate `CMTime` offset using `insertTimeRange`. Do not attempt gap-by-offset arithmetic alone — use a real silent asset so AVMutableComposition can correctly propagate duration metadata.

**Crossfade:** Apply via `AVMutableAudioMixInputParameters` volume ramps. Set a ramp-down on the ending clip's tail and a ramp-up on the next clip's head over the overlap window.

#### Noise Reduction: AVAudioEngine Voice Processing

**Use:** `inputNode.setVoiceProcessingEnabled(true)` + `AVAudioSinkNode` to capture processed PCM buffers + `AVAudioFile` to write output.

**Critical limitation — NOT an offline renderer.** `setVoiceProcessingEnabled` requires a live I/O audio session. It cannot be used with `enableManualRenderingMode(.offline)`. These two modes are mutually exclusive.

**Working pipeline for file-based denoising:**
```
1. Set AVAudioSession category to .playAndRecord
2. Set inputNode.setVoiceProcessingEnabled(true) BEFORE starting engine
3. Observe AVAudioEngineConfigurationChange — restart engine on config change
4. Play the source file through AVAudioPlayerNode → inputNode (via loopback)
5. Tap processed output via AVAudioSinkNode or installTap on mainMixerNode
6. Write captured buffers to AVAudioFile (output)
```

**Intensity slider (0–100%):** Voice Processing IO does not expose a continuous intensity parameter. Implement by blending processed and unprocessed buffers: `output = (intensity * denoisedBuffer) + ((1 - intensity) * originalBuffer)` using vDSP.

#### LUFS Normalization

**Use:** spfk-loudness (EBU R128 / ITU-R BS.1770 measurement) + gain adjustment pass.

```
1. Analyze exported audio file → measure integrated loudness (LUFS)
2. Compute gain = targetLUFS - measuredLUFS
3. Apply gain: re-export via AVAudioEngine with gain multiplication via vDSP.vsmul
```

**Apple's target:** -16 LUFS (Apple Music standard per AES TD1008). Podcast target is typically -16 LUFS.

#### Share Extension

**Use:** App Extension target (Share Extension), `UIViewController` subclass hosting a SwiftUI view, `NSItemProvider` with `UTType.audio` conformance, App Groups for file handoff.

Key rules:
1. `SLComposeServiceViewController` is deprecated-in-practice; use `UIViewController` + `UIHostingController` wrapping SwiftUI instead.
2. Audio files must be copied to the App Group shared container; original sandbox access is revoked after extension completes.
3. Do not run `AVAudioEngine` or `AVMutableComposition` inside the Share Extension (120 MB memory limit, no background execution).

---

## Version Compatibility (Full)

| Component | iOS Minimum | Notes |
|---|---|---|
| Swift 6 strict concurrency | Xcode 16 | Language version, not runtime |
| SwiftUI (project feature set) | iOS 17.0 | PROJECT.md sets iOS 17.0+ minimum |
| `MeshGradient` | **iOS 18.0** | Guard with `#available(iOS 18, *)`; use LinearGradient fallback on iOS 17 |
| `PhaseAnimator` / `KeyframeAnimator` | iOS 17.0 | At project floor; no guard needed |
| `sensoryFeedback` | iOS 17.0 | At project floor; no guard needed |
| `scrollTransition` | iOS 17.0 | At project floor; no guard needed |
| `visualEffect` | iOS 17.0 | At project floor; no guard needed |
| `UnevenRoundedRectangle` | iOS 17.0 | At project floor; no guard needed |
| `ShadowStyle.inner` | iOS 16.0 | Well within iOS 17 floor |
| `Material` (.ultraThinMaterial) | iOS 15.0 | Well within iOS 17 floor |
| `Canvas` / `TimelineView` | iOS 15.0 | Well within iOS 17 floor |
| `AVMutableComposition` | iOS 4.0+ | Stable; no breaking changes in iOS 17 |
| `setVoiceProcessingEnabled` | iOS 13.0+ | Well within iOS 17+ target |
| `AVAssetExportSession` async/await | iOS 18.0+ | Use `withCheckedContinuation` wrapper for iOS 17 |
| DSWaveformImage 14.0 | iOS 15.0+ | Well within iOS 17+ target |
| spfk-loudness | iOS 13+ (estimated) | Verify in Package.swift before integrating |

---

## Sources

**UI Restyle APIs (verified 2026-04-11):**
- [MeshGradient — Apple Developer Documentation](https://developer.apple.com/documentation/SwiftUI/MeshGradient) — iOS 18.0+ confirmed (HIGH)
- [WWDC 2024: What's new in SwiftUI](https://developer.apple.com/videos/play/wwdc2024/10144/) — MeshGradient, PhaseAnimator introduced iOS 18/17 (HIGH)
- [WWDC 2024: Create custom visual effects with SwiftUI](https://developer.apple.com/videos/play/wwdc2024/10151/) — Metal shader modifiers, visualEffect, scrollTransition (HIGH)
- [Mesh Gradients in SwiftUI explained — Donny Wals](https://www.donnywals.com/getting-started-with-mesh-gradients-on-ios-18/) — iOS 18 requirement and animation patterns (HIGH)
- [Material — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/material/) — iOS 15+ availability (HIGH)
- [ultraThinMaterial — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/shapestyle/ultrathinmaterial) — iOS 15+ confirmed (HIGH)
- [RoundedCornerStyle.continuous — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/roundedcornerstyle/continuous) — squircle style (HIGH)
- [SensoryFeedback — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/sensoryfeedback) — iOS 17+ confirmed (HIGH)
- [ShadowStyle.inner — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/shadowstyle/inner(color:radius:x:y:)) — iOS 16+ confirmed (HIGH)
- [Sensory feedback in SwiftUI — Swift with Majid](https://swiftwithmajid.com/2023/10/10/sensory-feedback-in-swiftui/) — sensoryFeedback vs UIImpactFeedbackGenerator comparison (MEDIUM)
- [TimelineView + Canvas — Kodeco](https://www.kodeco.com/27594491-using-timelineview-and-canvas-in-swiftui) — iOS 15+, pulsating patterns (MEDIUM)
- [Scroll transition effects iOS 17 — swdevnotes](https://swdevnotes.com/swift/2024/scroll-transition-effects-in-ios-17/) — scrollTransition iOS 17 (MEDIUM)
- [Inner Shadow — Design+Code Handbook](https://designcode.io/swiftui-handbook-inner-shadow/) — ShadowStyle.inner usage patterns (MEDIUM)
- [SwiftUI Glow Gradient Button iOS 17 — Dev Genius](https://blog.devgenius.io/swiftui-creating-a-custom-glow-gradient-button-in-ios-17-d17ffc4af97a) — pill button glow patterns (MEDIUM)

**Audio Stack:**
- Apple Developer Documentation — AVMutableComposition: https://developer.apple.com/documentation/avfoundation/avmutablecomposition
- Apple Developer Documentation — setVoiceProcessingEnabled: https://developer.apple.com/documentation/avfaudio/avaudioionode/setvoiceprocessingenabled(_:)
- Apple Developer Documentation — Performing Offline Audio Processing: https://developer.apple.com/documentation/avfaudio/audio_engine/performing_offline_audio_processing
- DSWaveformImage GitHub: https://github.com/dmrschmidt/DSWaveformImage
- AudioKit GitHub Issue #2606 — VoiceProcessing conflict: https://github.com/AudioKit/AudioKit/issues/2606

---

*Stack research for: SonicMerge — audio pipeline (v1.0) + Modern Spatial Utility UI restyle (v1.1)*
*Last updated: 2026-04-11*
