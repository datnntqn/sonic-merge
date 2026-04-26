---
plan: premium-studio-polish
date: 2026-04-26
branch: phase-11-premium-studio-polish
spec: inline (no separate brainstorm doc — direct user spec via /writing-plans)
---

# Premium Studio Polish Implementation Plan

> **For agentic workers:** REQUIRED: Use `superpowers:subagent-driven-development` (if subagents available) or `superpowers:executing-plans` to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Elevate visual fidelity to a "Premium Studio" feel by adding mesh-gradient backgrounds, a breathing AI Orb with a glass overlay, continuous glowing waveform paths, button specular highlights, and distinct per-interaction haptics in the junction Menu — without changing layout, ViewModels, services, or the established design tokens.

**Architecture:** Pure visual-layer additions on top of Phase 6/7/8/10 surfaces. Five independent refinements, each in its own atomic commit so any one can revert without touching the others. Zero ViewModel/service diff. iOS 18+ uses `MeshGradient` natively; iOS 17 falls back to `LinearGradient` (same pattern already in `MergeSlotWaveformView`). All animation is gated on `accessibilityReduceMotion`.

**Tech Stack:** SwiftUI (iOS 17+), `MeshGradient` (iOS 18+), `Canvas`, `TimelineView`, `RadialGradient`, `LinearGradient`, `UIImpactFeedbackGenerator` (UIKit), `@Environment(\.sonicMergeSemantic)`, existing `PillButtonStyle` overlay slots.

**Reference skills:** @superpowers:verification-before-completion (build + regression test + human device check before claiming done), @superpowers:systematic-debugging (if any chunk fails build).

**Test strategy:** Visual changes are not unit-testable in this repo (no snapshot harness — same as Phases 8/9/10). Strategy is: build verify per chunk + regression test suite at the end + human device pass on iPhone 17 Sim (iOS 26.2). Same baseline applies (53/58 expected pass; 5 pre-existing failures from Phase 5/3/2 stubs).

---

## File Structure

| File | Action | Reason |
|------|--------|--------|
| `SonicMerge/DesignSystem/PremiumBackground.swift` | **Create** | New shared background view — mesh gradient w/ iOS 17 fallback |
| `SonicMerge/DesignSystem/WaveformPathView.swift` | **Create** | Shared continuous glowing-path renderer used by both clip cards and the Cleaning Lab waveform |
| `SonicMerge/Features/MixingStation/MixingStationView.swift` | Modify | Replace plain `surfaceBase` background with `PremiumBackground` |
| `SonicMerge/Features/Denoising/CleaningLabView.swift` | Modify | Replace plain `surfaceBase` background with `PremiumBackground`; swap waveform renderer |
| `SonicMerge/Features/Denoising/AIOrbView.swift` | Modify | Add breathing scale modulation + glass-overlay highlight on top of orb |
| `SonicMerge/Features/MixingStation/MergeSlotRow.swift` | Modify | Swap `MergeSlotWaveformView` (bar) for `WaveformPathView` (continuous glow) |
| `SonicMerge/DesignSystem/PillButtonStyle.swift` | Modify | Add `specularHighlight` overlay layer alongside existing `innerGlowOverlay` |
| `SonicMerge/Features/MixingStation/JunctionView.swift` | Modify | Replace single `.sensoryFeedback` with explicit per-action `UIImpactFeedbackGenerator` calls |

**No new SwiftData models. No new ViewModel methods. No new design tokens. No new Swift package dependencies.**

---

## Pre-flight

- [ ] **P0: Verify on `main` and clean** — `git status` shows no Phase-11-relevant uncommitted changes (the long-standing `.claude/settings.local.json`, `STATE.md`, etc. unrelated working-tree files are OK to leave).

  Run: `git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge branch --show-current`
  Expected: `main`

- [ ] **P1: Create branch from main**

  Run: `git checkout -b phase-11-premium-studio-polish main`
  Expected: `Switched to a new branch 'phase-11-premium-studio-polish'`

- [ ] **P2: Baseline build + test**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/sm-p11-baseline.log | tail -8
  ```
  Expected: `** TEST FAILED **` with exactly **5** baseline failures (3× ShareExtension, 1× ABPlayback, 1× AudioMergerService crossfade) and 53 passes. Anything else means main has drifted — investigate before proceeding.

---

## Chunk 1: Premium Background — Mesh Gradient

Replace flat `surfaceBase` background on the two main screens with a 3×3 mesh gradient that lays a 3%-opacity Deep Indigo wash over the corners. iOS 18+ uses `MeshGradient` directly; iOS 17 falls back to a corner-anchored `LinearGradient` overlay (same `if #available(iOS 18.0, *)` pattern already used in `MergeSlotWaveformView`).

### Task 1.1: Create `PremiumBackground.swift`

**Files:**
- Create: `SonicMerge/Features/...` — actually `SonicMerge/DesignSystem/PremiumBackground.swift`

- [ ] **Step 1: Create the file**

  Use Write to create `SonicMerge/DesignSystem/PremiumBackground.swift` with the full content below. The file is included in the build target via `fileSystemSynchronizedGroups` — no project.pbxproj edit needed (verified pattern from Phase 10 `JunctionView` creation).

  ```swift
  // PremiumBackground.swift
  // SonicMerge
  //
  // Phase 11 (Premium Studio Polish): subtle mesh gradient that lays a 3%
  // Deep Indigo wash over the four screen corners on top of the existing
  // semantic.surfaceBase fill. iOS 18+ uses native MeshGradient; iOS 17
  // falls back to a corner-anchored LinearGradient overlay.
  //
  // Decorative — accessibilityHidden. No animation, no motion, no a11y impact.

  import SwiftUI
  import UIKit

  struct PremiumBackground: View {
      @Environment(\.sonicMergeSemantic) private var semantic

      private static let cornerOpacity: Double = 0.03

      var body: some View {
          ZStack {
              Color(uiColor: semantic.surfaceBase)

              if #available(iOS 18.0, *) {
                  MeshGradient(
                      width: 3,
                      height: 3,
                      points: [
                          [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                          [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                          [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                      ],
                      colors: [
                          accentTint,    Color.clear, accentTint,
                          Color.clear,   Color.clear, Color.clear,
                          accentTint,    Color.clear, accentTint
                      ]
                  )
              } else {
                  // iOS 17 fallback — symmetrical corner wash via two crossed
                  // LinearGradients. Visually close to the mesh result.
                  LinearGradient(
                      colors: [accentTint, Color.clear, accentTint],
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing
                  )
                  LinearGradient(
                      colors: [accentTint, Color.clear, accentTint],
                      startPoint: .topTrailing,
                      endPoint: .bottomLeading
                  )
              }
          }
          .ignoresSafeArea()
          .accessibilityHidden(true)
      }

      private var accentTint: Color {
          Color(uiColor: semantic.accentAction).opacity(Self.cornerOpacity)
      }
  }

  #Preview("PremiumBackground") {
      PremiumBackground()
          .frame(width: 390, height: 844)
  }
  ```

- [ ] **Step 2: Verify build**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -3; echo "EXIT=$?"
  ```
  Expected: `** BUILD SUCCEEDED **` and `EXIT=0`. If the iOS 18 `MeshGradient` symbol is unavailable in your Xcode SDK, the `#available` guard falls back automatically.

### Task 1.2: Apply `PremiumBackground` in MixingStationView

**Files:**
- Modify: `SonicMerge/Features/MixingStation/MixingStationView.swift`

- [ ] **Step 1: Locate the current background**

  Use Read on `MixingStationView.swift` near line 38. Confirm the current code is:
  ```swift
  Color(uiColor: semantic.surfaceBase)
      .ignoresSafeArea()
  ```

- [ ] **Step 2: Replace with `PremiumBackground`**

  Use Edit. Old string:
  ```swift
                  Color(uiColor: semantic.surfaceBase)
                      .ignoresSafeArea()
  ```
  New string:
  ```swift
                  PremiumBackground()
  ```
  (`PremiumBackground` already calls `.ignoresSafeArea()` internally.)

- [ ] **Step 3: Verify build**

  Run the same build command as Task 1.1 Step 2. Expected: `** BUILD SUCCEEDED **`.

### Task 1.3: Apply `PremiumBackground` in CleaningLabView

**Files:**
- Modify: `SonicMerge/Features/Denoising/CleaningLabView.swift`

- [ ] **Step 1: Locate the current background**

  Read CleaningLabView around line 97. Confirm the chain reads:
  ```swift
  .background(Color(uiColor: semantic.surfaceBase))
  .navigationTitle("Cleaning Lab")
  ```

- [ ] **Step 2: Replace `.background(...)` with `PremiumBackground`**

  Use Edit. Old string:
  ```swift
          .background(Color(uiColor: semantic.surfaceBase))
  ```
  New string:
  ```swift
          .background { PremiumBackground() }
  ```
  The trailing-closure `.background { ... }` form embeds `PremiumBackground` as the background view; `.ignoresSafeArea()` inside the component extends it under the navigation bar safely.

- [ ] **Step 3: Verify build**

  Run the same build command. Expected: `** BUILD SUCCEEDED **`.

### Task 1.4: Commit Chunk 1

- [ ] **Step 1: Commit**

  ```bash
  git add SonicMerge/DesignSystem/PremiumBackground.swift \
          SonicMerge/Features/MixingStation/MixingStationView.swift \
          SonicMerge/Features/Denoising/CleaningLabView.swift
  git commit -m "$(cat <<'EOF'
  feat(11-w1): add PremiumBackground mesh gradient on main + cleaning lab

  Subtle 3% Deep Indigo wash anchored at the four screen corners over the
  existing semantic.surfaceBase fill. iOS 18+ uses native MeshGradient;
  iOS 17 falls back to two crossed LinearGradients (visually close).

  - New: SonicMerge/DesignSystem/PremiumBackground.swift
  - MixingStationView: replaces Color(...).ignoresSafeArea() at the root
    ZStack with PremiumBackground (which ignoresSafeArea internally).
  - CleaningLabView: replaces .background(Color(...)) with
    .background { PremiumBackground() }.

  No animation. accessibilityHidden. Zero new tokens; opacity literal 0.03
  is a Phase 11 visual constant kept inside the component (no broader reuse).

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Chunk 2: AI Orb Liquid Morph + Glass Overlay

Two additions to `AIOrbView`:

1. **Breathing pulsation** — outer scale modulation `1.0 + 0.02 * sin(t * 0.6 * 2π)`, ~1.7s cycle. Applies on top of the existing per-blob morph so the orb gently "breathes" in addition to its internal flow. Suppressed when `reduceMotion` is true (single source of truth: `shouldPause`).
2. **Glass overlay** — radial gradient ellipse anchored at the top of the orb, white@0.20 → clear, blendMode `.screen`, slight blur. Mimics a specular highlight from a top light source.

Both refinements are layered into the existing `body` ZStack — no API change, no callback change.

### Task 2.1: Refactor outer TimelineView to drive both canvas + breathing

**Files:**
- Modify: `SonicMerge/Features/Denoising/AIOrbView.swift` (lines ~143–211, the `body` block)

The current `body` has a `TimelineView` *inside* the `Canvas` for blob animation. Move the `TimelineView` outside the `ZStack` so its `t` value can drive both the canvas blobs AND the outer breathing scale. Single timeline = no double-animation cost.

- [ ] **Step 1: Read AIOrbView.swift body to confirm landmarks**

  Use Read on `SonicMerge/Features/Denoising/AIOrbView.swift` lines 140–215.
  Expected: `var body: some View {` at line 143; `TimelineView(.animation(...)` at line 163 currently wrapping the Canvas; outer `ZStack` from line 146; closing braces around line 211.

- [ ] **Step 2: Restructure body so TimelineView wraps the entire ZStack**

  Use Edit. Old string (line 144 through line 211 of the file — the entire `body` content). New structure:

  ```swift
  var body: some View {
      VStack(spacing: SonicMergeTheme.Spacing.sm) {

          TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: shouldPause)) { timeline in
              let t = timeline.date.timeIntervalSinceReferenceDate
              // Phase 11: breathing scale modulation. ±2% over a ~1.7s cycle.
              // Suppressed when reduceMotion (shouldPause) holds the timeline still.
              let breath = 1.0 + 0.02 * sin(t * 0.6 * 2 * .pi)

              ZStack {
                  // 1. Outer bloom — separate Circle layer, NOT inside Canvas
                  Circle()
                      .fill(RadialGradient(
                          colors: [
                              Color(uiColor: semantic.accentAI).opacity(0.18),
                              Color.clear
                          ],
                          center: .center,
                          startRadius: 0,
                          endRadius: 144
                      ))
                      .frame(width: 288, height: 288)
                      .blur(radius: reduceTransparency ? 8 : 24)
                      .blendMode(.screen)

                  // 2. Canvas orb — 4 animated blobs driven by `t`
                  Canvas { ctx, size in
                      for blob in makeBlobs() {
                          let r = blob.baseRadius * (1 + 0.08 * sin(t * blob.frequency * 2 * .pi + blob.phaseOffset))
                          let cx = blob.baseCenter.x + cos(t * blob.frequency * 2 * .pi + blob.phaseOffset) * 12
                          let cy = blob.baseCenter.y + sin(t * blob.frequency * 1.3 * 2 * .pi + blob.phaseOffset) * 12
                          let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                          let shading = GraphicsContext.Shading.radialGradient(
                              Gradient(colors: blob.gradientColors),
                              center: CGPoint(x: cx, y: cy),
                              startRadius: 0,
                              endRadius: r
                          )
                          ctx.blendMode = blob.blendMode
                          ctx.fill(Ellipse().path(in: rect), with: shading)
                      }
                  }
                  .frame(width: 240, height: 240)
                  .saturation(1.15)

                  // 3. Phase 11: glass overlay — top-anchored specular highlight
                  glassOverlay

                  // 4. Progress ring — visible when isProcessing
                  if viewModel.isProcessing {
                      Circle()
                          .trim(from: 0, to: CGFloat(viewModel.progress))
                          .stroke(
                              Color(uiColor: semantic.accentAI),
                              style: StrokeStyle(lineWidth: 4, lineCap: .round)
                          )
                          .rotationEffect(.degrees(-90))
                          .frame(width: 256, height: 256)
                          .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: viewModel.progress)
                          .accessibilityHidden(true)
                  }

                  // 5. Full ring when success state
                  if !viewModel.isProcessing && viewModel.hasDenoisedResult {
                      Circle()
                          .trim(from: 0, to: 1.0)
                          .stroke(
                              Color(uiColor: semantic.accentAI),
                              style: StrokeStyle(lineWidth: 4, lineCap: .round)
                          )
                          .rotationEffect(.degrees(-90))
                          .frame(width: 256, height: 256)
                          .accessibilityHidden(true)
                  }
              }
              .scaleEffect(reduceMotion ? 1.0 : breath)
          }

          // 6. State-dependent label (unchanged)
          Text(orbLabel)
              .font(.title3)
              .fontWeight(.semibold)
              .fontDesign(.rounded)
              .foregroundStyle(orbLabelColor)

          // 7. Percent readout — only when processing
          if viewModel.isProcessing {
              Text("\(Int(viewModel.progress * 100))%")
                  .font(.subheadline)
                  .foregroundStyle(Color(uiColor: semantic.textSecondary))
                  .monospacedDigit()
          }

          // 8. Cancel button — only when processing
          if viewModel.isProcessing {
              Button("Cancel denoising") {
                  viewModel.cancelDenoising()
              }
              .buttonStyle(PillButtonStyle(variant: .outline, size: .compact, tint: .accent))
              .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.isProcessing)
          }
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(accessibilityLabel)
      .accessibilityAddTraits(viewModel.isProcessing ? .updatesFrequently : [])
  }
  ```

  Notes on the diff vs. current:
  - Outer `VStack(spacing: SonicMergeTheme.Spacing.sm)` wraps everything (unchanged — same as today).
  - The `TimelineView` moves from inside-the-Canvas to outside-the-ZStack. Now its `t` drives both the per-blob morph and the breathing scale.
  - Existing `shouldPause` logic gates the timeline: idle / reduceMotion → animation halts at t=0 (so blobs and breath both freeze).
  - **New** `glassOverlay` view is added between the Canvas and the progress ring (z-order: bloom < canvas < glass < ring).
  - `.scaleEffect(reduceMotion ? 1.0 : breath)` is applied to the ZStack (the scaling sphere) — outer text/button are not scaled.

- [ ] **Step 3: Add the `glassOverlay` computed property**

  Use Edit. Insert after the `accessibilityLabel` private property (around line 138, before the `body` block). Old string (the closing `}` of accessibilityLabel block + start of `// MARK: - Body`):

  ```swift
      // MARK: - Body
  ```
  New string:
  ```swift
      // MARK: - Phase 11 Glass Overlay

      /// Top-anchored radial gradient mimicking a specular highlight from a
      /// soft light source above the orb. Slight blur softens the edge so it
      /// reads as glass, not paint. .screen blend mode keeps it additive on
      /// top of the orb's color blend without hardening the rim.
      private var glassOverlay: some View {
          Ellipse()
              .fill(
                  RadialGradient(
                      colors: [
                          Color.white.opacity(reduceTransparency ? 0.10 : 0.20),
                          Color.white.opacity(0.05),
                          Color.clear
                      ],
                      center: UnitPoint(x: 0.5, y: 0.25),
                      startRadius: 0,
                      endRadius: 80
                  )
              )
              .frame(width: 168, height: 100)
              .blendMode(.screen)
              .offset(y: -50)
              .blur(radius: reduceTransparency ? 2 : 5)
              .accessibilityHidden(true)
      }

      // MARK: - Body
  ```

- [ ] **Step 4: Verify build**

  Run the build command. Expected: `** BUILD SUCCEEDED **`.

  If the editor flags duplicate label declarations, check that the `// MARK: - Body` marker isn't duplicated (the original is now further down, after the new glassOverlay block).

### Task 2.2: Commit Chunk 2

- [ ] **Step 1: Commit**

  ```bash
  git add SonicMerge/Features/Denoising/AIOrbView.swift
  git commit -m "$(cat <<'EOF'
  feat(11-w2): AI Orb breathing pulsation + glass overlay

  Two additions to AIOrbView, both layered on the existing 4-blob nebula:

  1. Breathing pulse: outer ZStack scaleEffect modulated by 1.0 + 0.02 *
     sin(t * 0.6 * 2π) — ±2% range, ~1.7s period. Driven by the same
     TimelineView that powers the canvas blobs (refactored to wrap the
     ZStack instead of nesting inside Canvas), so we keep one animation
     pump per orb and the existing shouldPause logic (reduceMotion ||
     !isProcessing) freezes both motions together.
  2. Glass overlay: a top-anchored radial-gradient Ellipse, white@0.20 →
     clear, .screen blend, slight blur, offset y=-50. Reads as a soft
     specular highlight from above and gives the orb a glassy 3D feel.
     reduceTransparency reduces the highlight opacity to 0.10 and the
     blur radius to 2.

  No new tokens; no new ViewModel surface; no API change to AIOrbView.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Chunk 3: Waveform — Bar Style → Continuous Glowing Path

Two waveform renderers exist today (`MergeSlotWaveformView` inside `MergeSlotRow.swift`, `WaveformCanvasView` inside `CleaningLabView.swift`) and both use `Canvas` with rectangle bars. This chunk introduces a single shared `WaveformPathView` that draws a continuous closed path with a glow shadow, and migrates both call sites to it.

### Task 3.1: Create `WaveformPathView.swift`

**Files:**
- Create: `SonicMerge/DesignSystem/WaveformPathView.swift`

- [ ] **Step 1: Create the file**

  Use Write to create `SonicMerge/DesignSystem/WaveformPathView.swift`:

  ```swift
  // WaveformPathView.swift
  // SonicMerge
  //
  // Phase 11 (Premium Studio Polish): continuous glowing waveform path,
  // replacing the Phase 7/8 bar-style renderers. Closes a single Canvas path
  // through the top of every peak, mirrors back through the bottom for a
  // symmetric blob, then fills with the existing Deep Indigo → Purple
  // gradient. A drop-shadow filter gives the waveform depth inside its card.

  import SwiftUI
  import UIKit

  /// Shared continuous-path waveform renderer.
  ///
  /// `peaks` are normalized [0, 1] amplitudes; the renderer assumes pre-
  /// normalized peaks (call sites already provide this — same input shape
  /// the bar renderers used).
  struct WaveformPathView: View {
      let peaks: [Float]

      /// Vertical inset from the canvas top/bottom so the path doesn't kiss
      /// the card edges. Tunable per call site (clip thumbnail vs. full-width
      /// Cleaning Lab readout).
      var verticalInset: CGFloat = 4

      /// Drop-shadow radius. Set to 0 for no shadow.
      var shadowRadius: CGFloat = 6

      @Environment(\.sonicMergeSemantic) private var semantic
      @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

      var body: some View {
          Canvas { ctx, size in
              guard peaks.count > 1 else { return }
              let centerY = size.height / 2
              let usable = max(centerY - verticalInset, 1)
              let stepX = size.width / CGFloat(peaks.count - 1)

              var path = Path()
              // Top edge — left to right through every peak.
              for (i, peak) in peaks.enumerated() {
                  let x = CGFloat(i) * stepX
                  let amplitude = CGFloat(max(0.02, min(1.0, peak))) * usable
                  let y = centerY - amplitude
                  if i == 0 {
                      path.move(to: CGPoint(x: x, y: y))
                  } else {
                      path.addLine(to: CGPoint(x: x, y: y))
                  }
              }
              // Bottom edge — right to left, mirrored through center.
              for (i, peak) in peaks.enumerated().reversed() {
                  let x = CGFloat(i) * stepX
                  let amplitude = CGFloat(max(0.02, min(1.0, peak))) * usable
                  let y = centerY + amplitude
                  path.addLine(to: CGPoint(x: x, y: y))
              }
              path.closeSubpath()

              // Drop shadow filter — affects subsequent fill.
              // reduceTransparency drops the shadow entirely.
              if shadowRadius > 0 && !reduceTransparency {
                  ctx.addFilter(.shadow(
                      color: Color(uiColor: semantic.accentAction).opacity(0.30),
                      radius: shadowRadius,
                      x: 0,
                      y: 3
                  ))
              }

              // Fill with the same Indigo → Purple gradient as the bar renderer.
              let gradient = LinearGradient(
                  colors: [
                      Color(uiColor: semantic.accentAction),
                      Color(uiColor: semantic.accentGradientEnd)
                  ],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
              )
              ctx.fill(path, with: .style(gradient))
          }
      }
  }

  #Preview("WaveformPathView") {
      WaveformPathView(
          peaks: (0..<50).map { Float(0.3 + 0.6 * sin(Double($0) * 0.4)) }
      )
      .frame(width: 320, height: 80)
      .padding()
  }
  ```

  **Why a closed-path fill (not just a stroke):** the path is mirrored through center, so closing it produces a symmetric blob that fills with gradient. A pure stroke would render only an outline. The Phase 11 spec says "continuous glowing path … shadow beneath the waveform line to give it depth" — a filled closed shape with a drop-shadow filter satisfies "path" + "shadow beneath" + reads as a continuous waveform shape (not bars).

- [ ] **Step 2: Verify build**

  Run the build command. Expected: `** BUILD SUCCEEDED **`. The new file is auto-included via `fileSystemSynchronizedGroups`.

### Task 3.2: Migrate `MergeSlotRow` clip thumbnail

**Files:**
- Modify: `SonicMerge/Features/MixingStation/MergeSlotRow.swift`

The clip thumbnail uses `MergeSlotWaveformView` at 96×44 with corner radius 8 (Phase 10 Wave 4). The new path renderer doesn't need the masked-canvas pattern; we can drop the wrapping ZStack with the surface well and use `WaveformPathView` directly inside the rounded clip frame.

- [ ] **Step 1: Replace the thumbnail call site**

  Use Edit. Old string:
  ```swift
                  MergeSlotWaveformView(peaks: peaks)
                      .frame(width: 96, height: 44)
                      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  ```
  New string:
  ```swift
                  WaveformPathView(peaks: peaks, verticalInset: 4, shadowRadius: 4)
                      .frame(width: 96, height: 44)
                      .background(
                          // Phase 7/10 backing well preserved for contrast
                          // when the waveform amplitude is low.
                          RoundedRectangle(cornerRadius: 8, style: .continuous)
                              .fill(Color(uiColor: semantic.surfaceBase).opacity(0.85))
                      )
                      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  ```

  Note: smaller `shadowRadius: 4` for the thumbnail so the drop shadow doesn't bleed past the 8pt clip rect.

- [ ] **Step 2: Delete the now-unused `MergeSlotWaveformView`**

  The old `private struct MergeSlotWaveformView: View { ... }` block at the bottom of `MergeSlotRow.swift` is no longer referenced. Delete the entire struct (and the `private var waveformGradient` it owns) so the file shrinks. Use Edit with the old string being the entire `private struct MergeSlotWaveformView { ... }` block (lines ~84–151 currently) and the new string being empty.

- [ ] **Step 3: Verify build**

  Run the build command. Expected: `** BUILD SUCCEEDED **`. The old `MeshGradient` iOS 18 / `LinearGradient` iOS 17 bar gradient is no longer needed in this file (the new shared renderer uses a simple `LinearGradient` since the closed-shape silhouette already provides the visual richness the mesh used to).

### Task 3.3: Migrate Cleaning Lab waveform

**Files:**
- Modify: `SonicMerge/Features/Denoising/CleaningLabView.swift`

`CleaningLabView` currently uses a private `WaveformCanvasView` (lines ~370–412 of the file). Replace its single call site with `WaveformPathView`, then delete the private struct.

- [ ] **Step 1: Replace the call site**

  Use Edit. Old string:
  ```swift
                      } else if !viewModel.waveformPeaks.isEmpty {
                          WaveformCanvasView(peaks: viewModel.waveformPeaks)
                              .padding(.horizontal, SonicMergeTheme.Spacing.sm)
                      } else if viewModel.isProcessing {
  ```
  New string:
  ```swift
                      } else if !viewModel.waveformPeaks.isEmpty {
                          WaveformPathView(
                              peaks: viewModel.waveformPeaks,
                              verticalInset: 6,
                              shadowRadius: 8
                          )
                          .padding(.horizontal, SonicMergeTheme.Spacing.sm)
                      } else if viewModel.isProcessing {
  ```

  (Larger `shadowRadius: 8` and `verticalInset: 6` for the full-width readout vs. the small thumbnail — proportional to the card size.)

- [ ] **Step 2: Delete the `WaveformCanvasView` private struct**

  Use Edit. Old string is the entire `// MARK: - WaveformCanvasView` block plus the `private struct WaveformCanvasView: View { ... }` definition through to the closing `}` of the struct. New string: empty.

  After this edit, the file should end after the `startExport` function — no trailing private renderer.

- [ ] **Step 3: Verify build**

  Run the build command. Expected: `** BUILD SUCCEEDED **`.

### Task 3.4: Commit Chunk 3

- [ ] **Step 1: Commit**

  ```bash
  git add SonicMerge/DesignSystem/WaveformPathView.swift \
          SonicMerge/Features/MixingStation/MergeSlotRow.swift \
          SonicMerge/Features/Denoising/CleaningLabView.swift
  git commit -m "$(cat <<'EOF'
  refactor(11-w3): swap bar waveform for continuous glowing path

  Both waveform call sites (clip thumbnails in MergeSlotRow + full-width
  readout in CleaningLabView) replace their bar-Canvas renderers with a
  single shared WaveformPathView that closes a path through every peak,
  mirrors it through center, fills with the Phase 6 Indigo → Purple
  gradient, and adds a drop-shadow filter for "Material Depth".

  - New: SonicMerge/DesignSystem/WaveformPathView.swift
    - Closed-path fill (not stroke) → continuous waveform silhouette
    - .addFilter(.shadow) for the depth-inside-card effect; suppressed
      when accessibilityReduceTransparency is on
    - Two tunable params: verticalInset (margin from canvas edges),
      shadowRadius (drop-shadow blur). Thumbnail uses 4/4; full-width
      readout uses 6/8.
  - MergeSlotRow: WaveformPathView replaces MergeSlotWaveformView. The
    surfaceBase backing well is preserved as a .background to keep
    low-amplitude waveforms readable.
  - CleaningLabView: WaveformPathView replaces WaveformCanvasView.
  - Both private renderers are deleted (MergeSlotWaveformView, the iOS-18
    MeshGradient/iOS-17 LinearGradient bar gradient, WaveformCanvasView).

  No model/VM/service changes. No new tokens.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Chunk 4: Button Specular Highlight

Add a new `specularHighlight` overlay layer to `PillButtonStyle` that strokes a 1pt white-to-clear capsule along the top inner edge — sits alongside the existing `innerGlowOverlay` (soft white gradient at top) without replacing it. The two together produce a layered glass surface: soft inner glow plus a sharp specular line.

Applies only to filled variants (`.outline` has a transparent fill — no surface for a specular line). Suppressed when `accessibilityReduceTransparency` is on.

### Task 4.1: Add `specularHighlight` overlay

**Files:**
- Modify: `SonicMerge/DesignSystem/PillButtonStyle.swift` (lines 42–65, the `makeBody` function + new private property near `innerGlowOverlay` at line 124)

- [ ] **Step 1: Add the new `specularHighlight` private property**

  Use Edit. Old string (the existing `innerGlowOverlay` declaration block):
  ```swift
      @ViewBuilder
      private var innerGlowOverlay: some View {
          if variant == .filled && isEnabled {
              Capsule()
                  .fill(
                      LinearGradient(
                          colors: [
                              Color.white.opacity(0.25),
                              Color.white.opacity(0)
                          ],
                          startPoint: .top,
                          endPoint: UnitPoint(x: 0.5, y: 0.6)
                      )
                  )
                  .allowsHitTesting(false)
          }
      }
  ```
  New string (innerGlow unchanged + new specularHighlight appended):
  ```swift
      @ViewBuilder
      private var innerGlowOverlay: some View {
          if variant == .filled && isEnabled {
              Capsule()
                  .fill(
                      LinearGradient(
                          colors: [
                              Color.white.opacity(0.25),
                              Color.white.opacity(0)
                          ],
                          startPoint: .top,
                          endPoint: UnitPoint(x: 0.5, y: 0.6)
                      )
                  )
                  .allowsHitTesting(false)
          }
      }

      /// Phase 11: thin white line at the top inner edge — a specular
      /// highlight that reads as light reflecting off a glass surface.
      /// Layered ON TOP of innerGlowOverlay (the broad soft glow) for a
      /// premium glass effect: soft glow + sharp top highlight.
      /// Suppressed for outline variants (no surface to reflect off) and
      /// when accessibilityReduceTransparency is on.
      @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

      @ViewBuilder
      private var specularHighlight: some View {
          if variant == .filled && isEnabled && !reduceTransparency {
              Capsule()
                  .stroke(
                      LinearGradient(
                          colors: [
                              Color.white.opacity(0.55),
                              Color.white.opacity(0.10),
                              Color.clear
                          ],
                          startPoint: .top,
                          endPoint: UnitPoint(x: 0.5, y: 0.45)
                      ),
                      lineWidth: 1
                  )
                  .blendMode(.screen)
                  .allowsHitTesting(false)
          }
      }
  ```

- [ ] **Step 2: Add the new overlay to `makeBody`**

  Use Edit. Old string:
  ```swift
              .overlay(borderOverlay)
              .overlay(innerGlowOverlay)
  ```
  New string:
  ```swift
              .overlay(borderOverlay)
              .overlay(innerGlowOverlay)
              .overlay(specularHighlight)
  ```

- [ ] **Step 3: Verify build**

  Run the build command. Expected: `** BUILD SUCCEEDED **`.

  Visual sanity (build-only): the specular line is 1pt, gradient stops at 45% from top so the bottom half of the capsule has no stroke. Outline variants render unchanged because `specularHighlight` is empty in that branch.

### Task 4.2: Commit Chunk 4

- [ ] **Step 1: Commit**

  ```bash
  git add SonicMerge/DesignSystem/PillButtonStyle.swift
  git commit -m "$(cat <<'EOF'
  feat(11-w4): specular highlight on filled PillButtons

  Adds a new specularHighlight overlay layer to PillButtonStyle — a 1pt
  Capsule.stroke with a white@0.55 → clear LinearGradient running from
  the top to 45% down the capsule. Layered on top of the existing
  innerGlowOverlay (soft glow), which together produce a glass-surface
  feel: broad soft glow underneath + sharp top specular line on top.

  - Renders only for variant == .filled && isEnabled — outline variants
    have no surface to reflect off; disabled state shouldn't gleam.
  - .blendMode(.screen) keeps the highlight additive on any tint
    (Deep Indigo .accent or Lime Green .ai both look natural).
  - Suppressed entirely when accessibilityReduceTransparency is true,
    matching the established pattern (SquircleCard glass, AIOrb bloom).
  - .allowsHitTesting(false) — pure decoration, never steals taps.

  No API change. Every existing call site (Export pill, play icon
  buttons, Denoise pills, junction Add capsule, etc.) inherits the
  highlight automatically.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Chunk 5: Junction Menu Distinct Haptics

Replace the single `.sensoryFeedback(.impact(weight: .light), trigger: triggerKey)` modifier on `JunctionView` with explicit `UIImpactFeedbackGenerator` calls inside each Menu action. Different feedback weights per interaction type so users feel a distinct tactile response for each kind of choice:

| Interaction | Weight | Rationale |
|-------------|--------|-----------|
| Pick "No gap" or any gap duration (Picker) | light | subtle setting change |
| Pick "Crossfade" (explicit Button) | medium | bigger semantic change (transition style flip) |
| Pick "Insert clip here" (explicit Button) | medium | initiates a flow — file importer presents |

The `.sensoryFeedback` modifier on Picker selection is replaced by a `.onChange(of: picked)` handler that dispatches the right generator weight. The two Buttons (Crossfade / Insert) call `UIImpactFeedbackGenerator(style:).impactOccurred()` directly in their action closures.

### Task 5.1: Replace `.sensoryFeedback` with explicit per-action haptics

**Files:**
- Modify: `SonicMerge/Features/MixingStation/JunctionView.swift`

- [ ] **Step 1: Remove the outer `.sensoryFeedback` modifier**

  Use Edit. Old string:
  ```swift
          .onChange(of: picked) { _, newValue in
              switch newValue {
              case .gap(let d):
                  onTransitionChange(d, false)
              case .crossfade:
                  onTransitionChange(nil, true)
              }
          }
          .sensoryFeedback(.impact(weight: .light), trigger: triggerKey)
          .accessibilityLabel("Transition: \(picked.voiceOverLabel). Double-tap to change.")
  ```
  New string:
  ```swift
          .onChange(of: picked) { oldValue, newValue in
              // Phase 11 distinct haptics: light for any gap change (incl.
              // "No gap"), medium for the crossfade flip. Picker selections
              // route through this single observer; the explicit Crossfade
              // and Insert buttons fire their own generator before mutating
              // state so the haptic precedes the menu dismiss animation.
              let style: UIImpactFeedbackGenerator.FeedbackStyle = {
                  switch newValue {
                  case .gap:       return .light
                  case .crossfade: return .medium
                  }
              }()
              UIImpactFeedbackGenerator(style: style).impactOccurred()

              switch newValue {
              case .gap(let d):
                  onTransitionChange(d, false)
              case .crossfade:
                  onTransitionChange(nil, true)
              }
          }
          .accessibilityLabel("Transition: \(picked.voiceOverLabel). Double-tap to change.")
  ```

  Note: the `.sensoryFeedback(...)` line is removed entirely; the dispatch happens inside `.onChange`. `triggerKey` is no longer referenced — leave the helper in place (it's harmless; future modifiers may use it).

- [ ] **Step 2: Add explicit haptic on the Crossfade Button**

  Use Edit. Old string:
  ```swift
              Button {
                  picked = .crossfade
              } label: {
                  Label("Crossfade", systemImage: "arrow.triangle.merge")
              }
  ```
  New string:
  ```swift
              Button {
                  // Phase 11: medium-weight tap precedes the state flip so
                  // the haptic lands at the moment of choice, not after the
                  // menu dismisses.
                  UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                  picked = .crossfade
              } label: {
                  Label("Crossfade", systemImage: "arrow.triangle.merge")
              }
  ```

  Note: the `.onChange(of: picked)` observer above will ALSO fire when `picked = .crossfade` runs — but since we've already triggered a medium haptic explicitly, the .onChange dispatcher will fire ANOTHER one of equal weight. Acceptable (single combined feel), but if double-haptic is too much in field testing, the `.onChange` block can guard against the case `(oldValue, newValue) == (.gap, .crossfade)` to skip its own dispatch.

- [ ] **Step 3: Add explicit haptic on the Insert clip Button**

  Use Edit. Old string:
  ```swift
              if let onInsertClip {
                  Divider()
                  Button(action: onInsertClip) {
                      Label("Insert clip here", systemImage: "plus")
                  }
              }
  ```
  New string:
  ```swift
              if let onInsertClip {
                  Divider()
                  Button {
                      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                      onInsertClip()
                  } label: {
                      Label("Insert clip here", systemImage: "plus")
                  }
              }
  ```

- [ ] **Step 4: Verify build**

  Run the build command. Expected: `** BUILD SUCCEEDED **`. The `import UIKit` already at the top of `JunctionView.swift` exposes `UIImpactFeedbackGenerator`.

### Task 5.2: Commit Chunk 5

- [ ] **Step 1: Commit**

  ```bash
  git add SonicMerge/Features/MixingStation/JunctionView.swift
  git commit -m "$(cat <<'EOF'
  feat(11-w5): distinct UIImpactFeedbackGenerator per junction Menu action

  Replaces JunctionView's single .sensoryFeedback(.impact(weight: .light),
  trigger: triggerKey) with explicit, per-action UIImpactFeedbackGenerator
  calls so users feel a distinct tactile response per interaction type:

  - Pick a gap duration (Picker → .gap(d)):    light  via .onChange dispatch
  - Pick "No gap" (Picker → .gap(0)):          light  via .onChange dispatch
  - Pick "Crossfade" (Button):                 medium via direct call + .onChange
  - Pick "Insert clip here" (Button):          medium via direct call

  The .onChange(of: picked) observer dispatches the right generator weight
  based on the new value. Crossfade/Insert buttons fire their own generator
  ahead of state mutation so the haptic lands at the moment of choice
  rather than after the menu dismiss animation completes.

  triggerKey computed property is left in place — harmless dead code, may
  be used by future modifiers without re-introducing the property.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Final Verification

### Task F.1: Regression test pass

- [ ] **Step 1: Run the full test suite**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/sm-p11-final.log | tail -8
  echo "PASS=$(grep -cE '✔ Test .* passed' /tmp/sm-p11-final.log)"
  echo "FAIL=$(grep -cE '✘ Test .* failed' /tmp/sm-p11-final.log)"
  ```
  Expected: 53 passes, 5 failures (the same Phase 5/3/2 baseline). Anything else means a Phase 11 chunk regressed something — bisect via `git bisect` against the chunk commits.

### Task F.2: Human device verification

Phase 11 is visual-only and not unit-testable in this repo. The acceptance gate is human eyes on the simulator. Open `iPhone 17 Simulator (iOS 26.2)` and verify:

- [ ] **Background** — both screens show subtle indigo-corner mesh wash, not flat white. Not blocking on iOS 17 (fallback).
- [ ] **AI Orb** — visible breathing pulse during processing. Top of the orb has a soft white glass highlight. Both effects stop on `Settings → Accessibility → Motion → Reduce Motion`.
- [ ] **Waveforms** — clip thumbnails and Cleaning Lab readout render as continuous filled-shape waveforms, not bars. Drop shadow visible inside the white card. With `Reduce Transparency` on, shadow disappears (filter suppressed).
- [ ] **Buttons** — every filled pill (Export, play icons, Denoise, junction Add capsule's Crossfade selection, etc.) shows a thin white specular line at the top. Outline pills (the Add capsule itself) don't.
- [ ] **Junction Menu haptics** — physical device only. Tap junction → pick "No gap" or any duration: **light** impact. Tap "Crossfade": **medium**. Tap "Insert clip here": **medium**. If on simulator, this step is N/A.

### Task F.3: Push branch + open PR

- [ ] **Step 1: Push**

  ```bash
  git push -u origin phase-11-premium-studio-polish
  ```

- [ ] **Step 2: Open PR**

  `gh` CLI not available in this environment — open the URL the push prints in a browser, paste a summary derived from the chunk commit messages plus the Final Verification table.

---

## Rollback

Each chunk is a single atomic commit. To revert any one:

```bash
git revert <sha>
```

The chunks are independent — reverting Chunk 5 (haptics) doesn't disturb Chunk 1 (background), and so on. Most likely revert candidate based on field-testing risk:

- **Chunk 5** — if the double-haptic (explicit + onChange dispatch) on Crossfade/Insert feels wrong, revert and add the guard noted in Task 5.1 Step 2.
- **Chunk 2** — if breathing pulsation feels seasick on long denoise runs, revert just the breath; glass overlay can stay if the `glassOverlay` block is extracted into its own commit.
- **Chunk 3** — if the closed-path waveform looks worse than the bars (subjective design call), revert for both call sites simultaneously since they share the renderer.

---

## Summary Ledger

| Chunk | Files | Lines (approx) | Requirement |
|-------|-------|----------------|-------------|
| 1 | PremiumBackground.swift (new) + 2 modified | ~75 | Background mesh gradient |
| 2 | AIOrbView.swift | ~90 | Liquid morph (breath) + glass overlay |
| 3 | WaveformPathView.swift (new) + 2 modified | ~90 | Continuous glowing path waveform |
| 4 | PillButtonStyle.swift | ~30 | Specular highlight on filled pills |
| 5 | JunctionView.swift | ~25 | Distinct UIImpactFeedbackGenerator per Menu action |

**Commits expected:** 5 chunk commits, branch `phase-11-premium-studio-polish`. Final verification + push as separate steps (no commits).
