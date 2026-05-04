# CleanCut Rebrand Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the indigo+lime two-color palette with a deep-navy + fire-gradient (red→orange→magenta→violet) brand, and replace the generic `sparkles` SF Symbol — used for Smart Cut at 8 in-app callsites, in onboarding, and as the app icon — with a custom `SmartCutMark` SwiftUI view rendered as the same glyph everywhere.

**Architecture:** Token-driven. Add primitives to `SonicMergeTheme.ColorPalette`, swap values in the `SonicMergeSemantic` resolver, add ONE new slot (`accentAIGradientStops: [UIColor]`) for places that need a gradient instead of a flat color. The mark is a single parametric SwiftUI view (`SmartCutMark`) used at every callsite + as the source for both an `Assets.xcassets/SmartCutTabIcon.imageset/` (so the tab bar can render the gradient) and the 1024×1024 `AppIcon.appiconset/` PNGs (rendered headlessly via a macOS-host `Scripts/RenderSmartCutAppIcon.swift` ImageRenderer script).

**Tech Stack:** Swift 6, SwiftUI, UIKit (UIColor primitives), Swift Testing, ImageRenderer (macOS 13+ host).

**Spec:** `docs/superpowers/specs/2026-05-04-cleancut-rebrand-design.md`

**Branch:** `main` (per user direction; auto-mode work).

---

## Chunk 1: Palette primitives + semantic resolver

**Why first:** Everything downstream reads `SonicMergeSemantic`. Land the resolver change first so `SmartCutMark` (Chunk 2) and all callsite swaps (Chunks 4–5) can read the new gradient stops via the environment immediately.

### Task 1.1: Add fire-gradient color primitives

**Files:**
- Modify: `SonicMerge/DesignSystem/SonicMergeTheme.swift`

- [ ] **Step 1: Read current `SonicMergeTheme.swift`** to confirm line numbers haven't drifted

Run: `grep -n "static let " SonicMerge/DesignSystem/SonicMergeTheme.swift`
Expected: `primaryAccent`, `aiAccent`, `limeGreen`, `darkBackground`, etc. listed.

- [ ] **Step 2: Append new fire-gradient primitives**

Inside `enum ColorPalette`, after the existing `systemPurple` declaration (currently the last static let), append:

```swift
// MARK: Fire-gradient primitives (CleanCut rebrand 2026-05-04)

/// Ember red — fire-gradient stop 1 (warmest)
static let emberRed = UIColor(red: 255 / 255, green: 78 / 255, blue: 80 / 255, alpha: 1)

/// Ember orange — fire-gradient stop 2
static let emberOrange = UIColor(red: 249 / 255, green: 166 / 255, blue: 108 / 255, alpha: 1)

/// Magenta — fire-gradient stop 3, also flat `accentAI` (replaces lime green)
static let magentaAccent = UIColor(red: 240 / 255, green: 80 / 255, blue: 110 / 255, alpha: 1)

/// Deep violet — fire-gradient stop 4, also `accentAction` (replaces deep indigo)
static let deepViolet = UIColor(red: 111 / 255, green: 45 / 255, blue: 189 / 255, alpha: 1)

/// Deep navy — dark-mode `surfaceBase` (replaces pure black)
static let deepNavy = UIColor(red: 10 / 255, green: 10 / 255, blue: 24 / 255, alpha: 1)

/// Deep navy card — dark-mode `surfaceCard`/`surfaceSlot`/`surfaceElevated` (replaces #0F0F0F)
static let deepNavyCard = UIColor(red: 21 / 255, green: 23 / 255, blue: 43 / 255, alpha: 1)
```

- [ ] **Step 3: Build to verify the file still compiles**

Run: `set -o pipefail; xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add SonicMerge/DesignSystem/SonicMergeTheme.swift
git commit -m "feat(theme): add fire-gradient color primitives

Adds emberRed/emberOrange/magentaAccent/deepViolet + deepNavy/deepNavyCard
to ColorPalette. Used by the upcoming accentAIGradientStops slot and the
new dark-mode surface/accent token swap (CleanCut rebrand).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 1.2: Add `accentAIGradientStops` slot to `SonicMergeSemantic`

**Files:**
- Modify: `SonicMerge/DesignSystem/SonicMergeTheme+Appearance.swift`
- Test: `SonicMergeTests/DesignSystem/SonicMergeSemanticGradientTests.swift` (NEW)

- [ ] **Step 1: Write the failing test**

Create `SonicMergeTests/DesignSystem/SonicMergeSemanticGradientTests.swift`:

```swift
import Testing
import UIKit
@testable import SonicMerge

struct SonicMergeSemanticGradientTests {

    @Test func darkResolverExposesFourFireGradientStops() {
        let s = SonicMergeSemantic.resolved(colorScheme: .dark, preference: .dark)
        #expect(s.accentAIGradientStops.count == 4)
    }

    @Test func lightResolverExposesFourFireGradientStops() {
        let s = SonicMergeSemantic.resolved(colorScheme: .light, preference: .light)
        #expect(s.accentAIGradientStops.count == 4)
    }

    @Test func firstStopIsEmberRed() {
        let s = SonicMergeSemantic.resolved(colorScheme: .light, preference: .light)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        s.accentAIGradientStops[0].getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(Int(r * 255) == 255)
        #expect(Int(g * 255) == 78)
        #expect(Int(b * 255) == 80)
    }

    @Test func lastStopIsDeepViolet() {
        let s = SonicMergeSemantic.resolved(colorScheme: .dark, preference: .dark)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        s.accentAIGradientStops[3].getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(Int(r * 255) == 111)
        #expect(Int(g * 255) == 45)
        #expect(Int(b * 255) == 189)
    }

    @Test func accentActionIsDeepVioletInBothSchemes() {
        let dark = SonicMergeSemantic.resolved(colorScheme: .dark, preference: .dark)
        let light = SonicMergeSemantic.resolved(colorScheme: .light, preference: .light)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        dark.accentAction.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(Int(r * 255) == 111 && Int(g * 255) == 45 && Int(b * 255) == 189)
        light.accentAction.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(Int(r * 255) == 111 && Int(g * 255) == 45 && Int(b * 255) == 189)
    }

    @Test func accentAIIsMagentaFlat() {
        let s = SonicMergeSemantic.resolved(colorScheme: .light, preference: .light)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        s.accentAI.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(Int(r * 255) == 240 && Int(g * 255) == 80 && Int(b * 255) == 110)
    }

    @Test func darkSurfaceBaseIsDeepNavy() {
        let s = SonicMergeSemantic.resolved(colorScheme: .dark, preference: .dark)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        s.surfaceBase.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(Int(r * 255) == 10 && Int(g * 255) == 10 && Int(b * 255) == 24)
    }
}
```

- [ ] **Step 2: Add the test file to the SonicMergeTests target**

In Xcode: drag the new file into the `SonicMergeTests/DesignSystem/` group and ensure target membership = `SonicMergeTests`.

(Or via pbxproj edit if scripted; the implementer subagent should use Xcode's UI step or `xcodeproj` Ruby gem if available. Confirm by `grep "SonicMergeSemanticGradientTests" SonicMerge.xcodeproj/project.pbxproj` returns 1+ hits.)

- [ ] **Step 3: Run the test to verify it fails**

Run: `set -o pipefail; xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SonicMergeTests/SonicMergeSemanticGradientTests test 2>&1 | tail -10`
Expected: FAIL with "value of type 'SonicMergeSemantic' has no member 'accentAIGradientStops'" or compile error referencing the missing slot.

- [ ] **Step 4: Add the new slot + flip every value in the resolver**

Edit `SonicMerge/DesignSystem/SonicMergeTheme+Appearance.swift`. Apply two patches:

**(a)** In the `struct SonicMergeSemantic { ... }` declaration, after the existing `accentGradientEnd: UIColor` line, add:

```swift
/// Fire-gradient stops red → orange → magenta → violet (CleanCut rebrand 2026-05-04).
/// Use as `LinearGradient(colors: stops.map { Color(uiColor: $0) }, startPoint: ..., endPoint: ...)`.
/// Callsites that need a single flat color should keep using `accentAI` (the magenta stop).
var accentAIGradientStops: [UIColor]
```

**(b)** Replace the `lightClassic()` and `darkConveyor()` factory bodies. Light:

```swift
private static func lightClassic() -> SonicMergeSemantic {
    SonicMergeSemantic(
        surfaceBase: SonicMergeTheme.ColorPalette.canvasBackground,       // #FBFBFC (unchanged)
        surfaceSlot: SonicMergeTheme.ColorPalette.cardSurface,            // #FFFFFF (unchanged)
        surfaceElevated: UIColor.white,
        accentAction: SonicMergeTheme.ColorPalette.deepViolet,            // #6F2DBD (was #5856D6)
        accentWaveform: SonicMergeTheme.ColorPalette.deepViolet,          // #6F2DBD (was #5856D6)
        textPrimary: SonicMergeTheme.ColorPalette.primaryText,
        textSecondary: UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.6),
        trustIcon: SonicMergeTheme.ColorPalette.deepViolet,               // #6F2DBD (was #5856D6)
        accentAI: SonicMergeTheme.ColorPalette.magentaAccent,             // #F0506E (was lime #A7C957)
        accentGlow: SonicMergeTheme.ColorPalette.magentaAccent,           // #F0506E (was indigo)
        surfaceCard: SonicMergeTheme.ColorPalette.cardSurface,            // #FFFFFF (unchanged)
        surfaceGlass: UIColor(red: 251 / 255, green: 251 / 255, blue: 252 / 255, alpha: 0.6),
        accentGradientEnd: SonicMergeTheme.ColorPalette.deepViolet,       // #6F2DBD (was #AF52DE)
        accentAIGradientStops: [
            SonicMergeTheme.ColorPalette.emberRed,                        // #FF4E50
            SonicMergeTheme.ColorPalette.emberOrange,                     // #F9A66C
            SonicMergeTheme.ColorPalette.magentaAccent,                   // #F0506E
            SonicMergeTheme.ColorPalette.deepViolet                       // #6F2DBD
        ]
    )
}
```

Dark:

```swift
private static func darkConveyor() -> SonicMergeSemantic {
    SonicMergeSemantic(
        surfaceBase: SonicMergeTheme.ColorPalette.deepNavy,               // #0A0A18 (was #000000)
        surfaceSlot: SonicMergeTheme.ColorPalette.deepNavyCard,           // #15172B (was #0F0F0F)
        surfaceElevated: SonicMergeTheme.ColorPalette.deepNavyCard,       // #15172B (was #0F0F0F)
        accentAction: SonicMergeTheme.ColorPalette.deepViolet,            // #6F2DBD (was #5856D6)
        accentWaveform: SonicMergeTheme.ColorPalette.deepViolet,          // #6F2DBD (was #5856D6)
        textPrimary: SonicMergeTheme.ColorPalette.darkTextPrimary,
        textSecondary: SonicMergeTheme.ColorPalette.darkTextSecondary,
        trustIcon: SonicMergeTheme.ColorPalette.deepViolet,               // #6F2DBD (was #5856D6)
        accentAI: SonicMergeTheme.ColorPalette.magentaAccent,             // #F0506E (was lime)
        accentGlow: SonicMergeTheme.ColorPalette.magentaAccent,           // #F0506E (was indigo)
        surfaceCard: SonicMergeTheme.ColorPalette.deepNavyCard,           // #15172B (was #0F0F0F)
        surfaceGlass: UIColor(red: 10 / 255, green: 10 / 255, blue: 24 / 255, alpha: 0.7), // deep navy @ 0.7
        accentGradientEnd: SonicMergeTheme.ColorPalette.deepViolet,       // #6F2DBD (was #AF52DE)
        accentAIGradientStops: [
            SonicMergeTheme.ColorPalette.emberRed,
            SonicMergeTheme.ColorPalette.emberOrange,
            SonicMergeTheme.ColorPalette.magentaAccent,
            SonicMergeTheme.ColorPalette.deepViolet
        ]
    )
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `set -o pipefail; xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SonicMergeTests/SonicMergeSemanticGradientTests test 2>&1 | tail -10`
Expected: PASS (7 tests).

- [ ] **Step 6: Run the full suite — confirm baseline FAIL=5 unchanged**

Run: `set -o pipefail; xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3`
Then: `echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/test.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"`
Expected: `FAIL=5` with the names listed in CLAUDE.md baseline.

- [ ] **Step 7: Commit**

```bash
git add SonicMerge/DesignSystem/SonicMergeTheme+Appearance.swift \
        SonicMergeTests/DesignSystem/SonicMergeSemanticGradientTests.swift \
        SonicMerge.xcodeproj/project.pbxproj
git commit -m "feat(theme): swap palette to fire gradient + add accentAIGradientStops

Replaces indigo accentAction with deep violet #6F2DBD; lime accentAI
with magenta #F0506E; pure-black surfaceBase with deep navy #0A0A18 in
dark mode. Adds new accentAIGradientStops slot exposing the 4-stop fire
gradient (red → orange → magenta → violet) for callsites that want a
gradient instead of a flat color.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Chunk 2: SmartCutMark SwiftUI view

### Task 2.1: Create the parametric mark view

**Files:**
- Create: `SonicMerge/DesignSystem/SmartCutMark.swift`
- Test: `SonicMergeTests/DesignSystem/SmartCutMarkTests.swift` (NEW)

- [ ] **Step 1: Write the failing test**

Create `SonicMergeTests/DesignSystem/SmartCutMarkTests.swift`:

```swift
import Testing
import SwiftUI
@testable import SonicMerge

struct SmartCutMarkTests {

    @Test func toolbarSizeRendersWithoutCrash() {
        let view = SmartCutMark(size: .toolbar)
        let renderer = ImageRenderer(content: view.frame(width: 22, height: 22))
        renderer.scale = 1
        #expect(renderer.uiImage != nil)
    }

    @Test func heroSizeRendersWithoutCrash() {
        let view = SmartCutMark(size: .hero)
        let renderer = ImageRenderer(content: view.frame(width: 56, height: 56))
        renderer.scale = 1
        #expect(renderer.uiImage != nil)
    }

    @Test func splashSizeRendersWithoutCrash() {
        let view = SmartCutMark(size: .splash)
        let renderer = ImageRenderer(content: view.frame(width: 96, height: 96))
        renderer.scale = 1
        #expect(renderer.uiImage != nil)
    }

    @Test func monochromeTintAppliesFlatColor() {
        let view = SmartCutMark(size: .toolbar, monochromeTint: .white)
        let renderer = ImageRenderer(content: view.frame(width: 22, height: 22))
        renderer.scale = 1
        #expect(renderer.uiImage != nil)
    }

    /// Pixel-diversity smoke test: the gradient version should produce more
    /// distinct colors than the monochrome version. Gives confidence the
    /// LinearGradient is actually rendering, not silently flattening.
    @Test func gradientProducesMoreColorVarietyThanMonochrome() {
        let gradient = SmartCutMark(size: .splash)
        let mono = SmartCutMark(size: .splash, monochromeTint: .white)

        func uniquePixelCount(_ view: some View) -> Int {
            let r = ImageRenderer(content: view.frame(width: 96, height: 96))
            r.scale = 1
            guard let img = r.uiImage, let cg = img.cgImage,
                  let data = cg.dataProvider?.data,
                  let ptr = CFDataGetBytePtr(data) else { return 0 }
            let length = CFDataGetLength(data)
            var samples = Set<UInt32>()
            // Sample every 4th pixel (RGBA 4 bytes each — stride 16)
            var i = 0
            while i + 4 <= length {
                let r = UInt32(ptr[i]); let g = UInt32(ptr[i+1])
                let b = UInt32(ptr[i+2]); let a = UInt32(ptr[i+3])
                samples.insert((r << 24) | (g << 16) | (b << 8) | a)
                i += 16
            }
            return samples.count
        }

        let gradientUnique = uniquePixelCount(gradient)
        let monoUnique = uniquePixelCount(mono)
        #expect(gradientUnique > monoUnique, "gradient=\(gradientUnique) mono=\(monoUnique)")
    }
}
```

Add the file to the `SonicMergeTests` target in pbxproj.

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild ... -only-testing:SonicMergeTests/SmartCutMarkTests test 2>&1 | tail -5`
Expected: FAIL — "Cannot find 'SmartCutMark' in scope"

- [ ] **Step 3: Implement `SmartCutMark.swift`**

Create `SonicMerge/DesignSystem/SmartCutMark.swift`:

```swift
import SwiftUI

/// Custom Smart Cut glyph — 8 vertical waveform bars bisected by a
/// diagonal slash. Reads as "audio cut" at every size from 22pt toolbar
/// to 1024pt app icon. Replaces the generic SF Symbol `sparkles`.
///
/// Two render modes:
/// - Default: bars filled with the fire gradient (red → orange → magenta → violet)
///   read from `\.sonicMergeSemantic.accentAIGradientStops`.
/// - `monochromeTint:` non-nil: bars filled with that flat color (used when
///   a parent context requires single-color rendering, e.g. SF-Symbol-style
///   contexts that template-tint).
struct SmartCutMark: View {

    enum Size {
        case toolbar    // 22pt — tab bar, toolbar buttons
        case hero       // 56pt — onboarding feature pill, AI Orb idle
        case splash     // 96pt — onboarding hero, empty-state badge

        var pointSize: CGFloat {
            switch self {
            case .toolbar: return 22
            case .hero: return 56
            case .splash: return 96
            }
        }

        /// Diagonal stroke width as a fraction of pointSize.
        var diagonalStroke: CGFloat { pointSize * 0.047 }  // 1pt @ 22, 4.5pt @ 96
    }

    let size: Size
    var monochromeTint: Color? = nil

    @Environment(\.sonicMergeSemantic) private var semantic

    private var barFill: AnyShapeStyle {
        if let tint = monochromeTint {
            return AnyShapeStyle(tint)
        }
        return AnyShapeStyle(LinearGradient(
            colors: semantic.accentAIGradientStops.map { Color(uiColor: $0) },
            startPoint: .leading,
            endPoint: .trailing
        ))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // 8 bars: 4 left of diagonal (heights 35/55/80/100% from outer-in),
            // 4 right (mirror). All percentages of the canvas height.
            let barWidth = w * 0.047           // ~3pt @ 64-canvas
            let gap = w * 0.078                // ~5pt @ 64
            let leftHeights: [CGFloat] = [0.16, 0.36, 0.56, 0.78]
            let rightHeights: [CGFloat] = [0.78, 0.56, 0.36, 0.16]
            let leftOpacities: [CGFloat] = [0.35, 0.55, 0.80, 1.00]
            let rightOpacities: [CGFloat] = [1.00, 0.80, 0.55, 0.35]

            ZStack {
                // Left bars
                ForEach(0..<4, id: \.self) { i in
                    let xCenter = w * 0.10 + CGFloat(i) * gap
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(barFill)
                        .opacity(leftOpacities[i])
                        .frame(width: barWidth, height: h * leftHeights[i])
                        .position(x: xCenter, y: h / 2)
                }
                // Right bars
                ForEach(0..<4, id: \.self) { i in
                    let xCenter = w * 0.62 + CGFloat(i) * gap
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(barFill)
                        .opacity(rightOpacities[i])
                        .frame(width: barWidth, height: h * rightHeights[i])
                        .position(x: xCenter, y: h / 2)
                }
                // Diagonal slash — solid white, ~26° angle
                Path { p in
                    p.move(to: CGPoint(x: w * 0.42, y: h * 0.10))
                    p.addLine(to: CGPoint(x: w * 0.58, y: h * 0.90))
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: size.diagonalStroke, lineCap: .round))
            }
        }
        .frame(width: size.pointSize, height: size.pointSize)
        .accessibilityHidden(true)
    }
}

#Preview("Sizes — dark") {
    HStack(spacing: 24) {
        SmartCutMark(size: .toolbar)
        SmartCutMark(size: .hero)
        SmartCutMark(size: .splash)
    }
    .padding(40)
    .background(Color.black)
    .environment(\.sonicMergeSemantic, .resolved(colorScheme: .dark, preference: .dark))
}

#Preview("Monochrome white on dark") {
    HStack(spacing: 24) {
        SmartCutMark(size: .toolbar, monochromeTint: .white)
        SmartCutMark(size: .hero, monochromeTint: .white)
        SmartCutMark(size: .splash, monochromeTint: .white)
    }
    .padding(40)
    .background(Color.black)
}
```

Add the file to the `SonicMerge` target in pbxproj.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild ... -only-testing:SonicMergeTests/SmartCutMarkTests test 2>&1 | tail -5`
Expected: PASS (5 tests). The pixel-diversity test is the strongest signal that the gradient is actually rendering, not silently flattening.

- [ ] **Step 5: Run full suite**

Run: `set -o pipefail; xcodebuild ... -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3`
Expected: `FAIL=5` (baseline preserved).

- [ ] **Step 6: Commit**

```bash
git add SonicMerge/DesignSystem/SmartCutMark.swift \
        SonicMergeTests/DesignSystem/SmartCutMarkTests.swift \
        SonicMerge.xcodeproj/project.pbxproj
git commit -m "feat(design-system): SmartCutMark — custom waveform-cut glyph

Three size presets (toolbar/hero/splash). Default render uses the
fire-gradient stops from \\.sonicMergeSemantic; monochromeTint: parameter
flattens to a single color for tab-bar template contexts. Replaces
sparkles SF Symbol everywhere Smart Cut is represented.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Chunk 3: Asset rendering — tab-bar imageset + app icon

### Task 3.1: Create the headless render script

**Files:**
- Create: `Scripts/RenderSmartCutAppIcon.swift`

The script is a single-file Swift program runnable via `swift Scripts/RenderSmartCutAppIcon.swift` (Swift 5.5+ script mode) on macOS host. It imports `SwiftUI` and uses `ImageRenderer`. It reproduces the `SmartCutMark` glyph inline (NOT importing `SmartCutMark.swift`, to avoid the module-import gymnastics of running an iOS-target file in a script context — the glyph constants are simple enough to duplicate).

- [ ] **Step 1: Create the script**

```swift
#!/usr/bin/env swift
//
// RenderSmartCutAppIcon.swift
//
// Headless macOS-host renderer that produces the PNGs consumed by
// Assets.xcassets/AppIcon.appiconset/ and SmartCutTabIcon.imageset/.
//
// Run from repo root:
//     swift Scripts/RenderSmartCutAppIcon.swift
//
// Produces:
//   SonicMerge/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
//   SonicMerge/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-Dark.png
//   SonicMerge/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-Tinted.png
//   SonicMerge/Assets.xcassets/SmartCutTabIcon.imageset/SmartCutTabIcon.png
//   SonicMerge/Assets.xcassets/SmartCutTabIcon.imageset/SmartCutTabIcon@2x.png
//   SonicMerge/Assets.xcassets/SmartCutTabIcon.imageset/SmartCutTabIcon@3x.png

import SwiftUI
import AppKit

let stops: [Color] = [
    Color(red: 255/255, green: 78/255,  blue: 80/255),
    Color(red: 249/255, green: 166/255, blue: 108/255),
    Color(red: 240/255, green: 80/255,  blue: 110/255),
    Color(red: 111/255, green: 45/255,  blue: 189/255)
]
let deepNavy = Color(red: 10/255, green: 10/255, blue: 24/255)

struct Mark: View {
    let canvas: CGFloat
    let background: Color?
    let monochromeTint: Color?

    var fill: AnyShapeStyle {
        if let t = monochromeTint { return AnyShapeStyle(t) }
        return AnyShapeStyle(LinearGradient(colors: stops, startPoint: .leading, endPoint: .trailing))
    }

    var body: some View {
        ZStack {
            if let bg = background { bg }
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let barWidth = w * 0.047
                let gap = w * 0.078
                let leftHeights: [CGFloat] = [0.16, 0.36, 0.56, 0.78]
                let rightHeights: [CGFloat] = [0.78, 0.56, 0.36, 0.16]
                let leftOpacity: [CGFloat] = [0.35, 0.55, 0.80, 1.00]
                let rightOpacity: [CGFloat] = [1.00, 0.80, 0.55, 0.35]
                ForEach(0..<4, id: \.self) { i in
                    let x = w * 0.10 + CGFloat(i) * gap
                    RoundedRectangle(cornerRadius: barWidth/2)
                        .fill(fill).opacity(leftOpacity[i])
                        .frame(width: barWidth, height: h * leftHeights[i])
                        .position(x: x, y: h/2)
                }
                ForEach(0..<4, id: \.self) { i in
                    let x = w * 0.62 + CGFloat(i) * gap
                    RoundedRectangle(cornerRadius: barWidth/2)
                        .fill(fill).opacity(rightOpacity[i])
                        .frame(width: barWidth, height: h * rightHeights[i])
                        .position(x: x, y: h/2)
                }
                Path { p in
                    p.move(to: CGPoint(x: w * 0.42, y: h * 0.10))
                    p.addLine(to: CGPoint(x: w * 0.58, y: h * 0.90))
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: w * 0.047, lineCap: .round))
            }
        }
        .frame(width: canvas, height: canvas)
    }
}

@MainActor
func render(_ view: some View, size: CGFloat, to path: String) {
    let renderer = ImageRenderer(content: view.frame(width: size, height: size))
    renderer.scale = 1
    guard let nsImage = renderer.nsImage,
          let tiff = nsImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("Failed to render \(path)\n".data(using: .utf8)!)
        exit(1)
    }
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    do {
        try png.write(to: url)
        print("✓ \(path)")
    } catch {
        FileHandle.standardError.write("Failed to write \(path): \(error)\n".data(using: .utf8)!)
        exit(1)
    }
}

let appIconDir = "SonicMerge/Assets.xcassets/AppIcon.appiconset"
let tabIconDir = "SonicMerge/Assets.xcassets/SmartCutTabIcon.imageset"

await MainActor.run {
    // App icon — 1024×1024, deep navy bg, fire gradient glyph
    render(Mark(canvas: 1024, background: deepNavy, monochromeTint: nil),
           size: 1024, to: "\(appIconDir)/AppIcon-1024.png")

    // App icon dark — same canvas (per spec D-03 — dark default for the icon)
    render(Mark(canvas: 1024, background: deepNavy, monochromeTint: nil),
           size: 1024, to: "\(appIconDir)/AppIcon-1024-Dark.png")

    // App icon tinted — grayscale source (white glyph on transparent for iOS 18 to tint)
    render(Mark(canvas: 1024, background: nil, monochromeTint: .white),
           size: 1024, to: "\(appIconDir)/AppIcon-1024-Tinted.png")

    // Tab bar — 22 / 44 / 66 px, transparent bg, fire gradient
    render(Mark(canvas: 22, background: nil, monochromeTint: nil),
           size: 22, to: "\(tabIconDir)/SmartCutTabIcon.png")
    render(Mark(canvas: 44, background: nil, monochromeTint: nil),
           size: 44, to: "\(tabIconDir)/SmartCutTabIcon@2x.png")
    render(Mark(canvas: 66, background: nil, monochromeTint: nil),
           size: 66, to: "\(tabIconDir)/SmartCutTabIcon@3x.png")
}
```

- [ ] **Step 2: Make the script executable and run it**

Run: `chmod +x Scripts/RenderSmartCutAppIcon.swift && swift Scripts/RenderSmartCutAppIcon.swift`
Expected: 6 lines of `✓ SonicMerge/Assets.xcassets/...png` output, all 6 PNGs created.

- [ ] **Step 3: Spot-check the rendered output**

Run: `ls -la SonicMerge/Assets.xcassets/AppIcon.appiconset/*.png SonicMerge/Assets.xcassets/SmartCutTabIcon.imageset/*.png`
Expected: 6 files, AppIcon-1024 ones in the ~50–200 KB range, tab icons under 5 KB.

Manually open `SonicMerge/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` in Preview.app: should show 8 fire-gradient bars + diagonal white slash on a deep navy background. If it looks wrong, iterate on the glyph geometry in the script BEFORE moving on.

- [ ] **Step 4: Commit**

```bash
git add Scripts/RenderSmartCutAppIcon.swift \
        SonicMerge/Assets.xcassets/AppIcon.appiconset/*.png \
        SonicMerge/Assets.xcassets/SmartCutTabIcon.imageset/*.png
git commit -m "feat(assets): render Smart Cut mark to app-icon + tab-bar PNGs

Adds Scripts/RenderSmartCutAppIcon.swift — single-file macOS host script
that produces the AppIcon-1024 (light/dark/tinted) and SmartCutTabIcon
(@1x/@2x/@3x) PNGs from the same SwiftUI glyph used in-app.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 3.2: Wire AppIcon.appiconset Contents.json

**Files:**
- Modify: `SonicMerge/Assets.xcassets/AppIcon.appiconset/Contents.json`

- [ ] **Step 1: Update the Contents.json `images` entries to reference the new PNGs**

Replace the existing `Contents.json` with:

```json
{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "AppIcon-1024-Dark.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "AppIcon-1024-Tinted.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

(Mac entries unchanged — we don't ship a Mac binary, but Xcode templates always emit them. Leave them.)

- [ ] **Step 2: Build and run on simulator to verify icon shows up**

Run: `xcodebuild ... build 2>&1 | tail -5` then launch on the iPhone 17 simulator (`open -a Simulator` and run from Xcode), then go Home and visually confirm the icon shows the new mark on a deep-navy canvas.

If the icon doesn't update, **uninstall the app first** (long-press → Delete App on simulator) — iOS aggressively caches app icons. Re-run.

### Task 3.3: Wire SmartCutTabIcon imageset

**Files:**
- Create: `SonicMerge/Assets.xcassets/SmartCutTabIcon.imageset/Contents.json`

- [ ] **Step 1: Create the imageset Contents.json**

```json
{
  "images" : [
    {
      "filename" : "SmartCutTabIcon.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "filename" : "SmartCutTabIcon@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "filename" : "SmartCutTabIcon@3x.png",
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "template-rendering-intent" : "original"
  }
}
```

The `"template-rendering-intent" : "original"` is the asset-catalog equivalent of `Render As: Original Image` — preserves the gradient when consumed by `Image("SmartCutTabIcon")` and any `UITabBarItem`.

- [ ] **Step 2: Build to verify the asset catalog is valid**

Run: `xcodebuild ... build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED. If asset-catalog compilation fails, fix the JSON.

- [ ] **Step 3: Commit**

```bash
git add SonicMerge/Assets.xcassets/AppIcon.appiconset/Contents.json \
        SonicMerge/Assets.xcassets/SmartCutTabIcon.imageset/Contents.json
git commit -m "feat(assets): wire AppIcon + SmartCutTabIcon catalog entries

AppIcon.appiconset gains filename references for all three appearance
variants. SmartCutTabIcon.imageset adds @1x/@2x/@3x with original-image
rendering intent so the fire gradient survives tab-bar template tinting.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Chunk 4: In-app callsite swap (8 sites)

This chunk swaps every non-onboarding `sparkles` SF Symbol callsite to `SmartCutMark` and updates two CTAs (`Apply Cuts`, `Analyze`) to use the fire gradient. Onboarding is held back to Chunk 5 because the file is the largest single touch point.

### Task 4.1: Tab bar — Smart Cut tab item

**Files:**
- Modify: `SonicMerge/App/RootTabView.swift:55`

- [ ] **Step 1: Replace the `Label(systemImage:)` with the asset reference**

```swift
// Before
.tabItem { Label("Smart Cut", systemImage: "sparkles") }
// After
.tabItem { Label { Text("Smart Cut") } icon: { Image("SmartCutTabIcon") } }
```

The `Label { } icon: { }` form lets us pass an asset-`Image` (which honors original-rendering-intent) instead of an SF Symbol.

- [ ] **Step 2: Build + run, visually verify Smart Cut tab shows the fire-gradient glyph in the tab bar**

Expected: gradient survives in selected AND unselected state (no template tint flattening). Denoise and Merge tabs continue to use SF Symbols and tint with `accentAction` violet — this asymmetry is intentional (per spec D-06).

- [ ] **Step 3: Commit**

```bash
git add SonicMerge/App/RootTabView.swift
git commit -m "feat(rebrand): tab bar uses SmartCutTabIcon asset for Smart Cut tab"
```

### Task 4.2: SmartCutHomeView — empty state hero

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift:65-75`

- [ ] **Step 1: Replace the sparkles `Image` with `SmartCutMark`**

Replace lines 65–75 (the `emptyState` body's first child) with:

```swift
SmartCutMark(size: .splash)
    .padding(20)
    .background(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(LinearGradient(
                colors: semantic.accentAIGradientStops.map { Color(uiColor: $0) }.map { $0.opacity(0.18) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
    )
    .accessibilityHidden(true)
```

The squircle frame keeps the existing visual hierarchy (badge frame around the glyph) but its fill becomes a gradient at 18% alpha — same alpha as the prior solid-color version, so contrast feels familiar.

- [ ] **Step 2: Build + verify visually**

Open Smart Cut tab on simulator with no sessions: should show the fire-gradient glyph inside a soft fire-tinted squircle, with title "Cut fillers in seconds" below.

- [ ] **Step 3: Commit**

```bash
git add SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift
git commit -m "feat(rebrand): SmartCutHomeView empty-state hero uses SmartCutMark"
```

### Task 4.3: SmartCutSessionView — Apply Cuts CTA + toolbar

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Home/SmartCutSessionView.swift:135-141, 144-150`

- [ ] **Step 1: Replace `Label("Apply Cuts", systemImage: "sparkles")` with `SmartCutMark` + text label**

In the `applyCutsButton(for:)` switch, both `.results` and `.applied` (Re-apply path) cases use a `Label`. Replace the `.results` case with:

```swift
case .results:
    Button { Task { await vm.apply() } } label: {
        HStack(spacing: 6) {
            SmartCutMark(size: .toolbar)
            Text("Apply Cuts")
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
```

The `.applied`/Re-apply path keeps the `arrow.clockwise` symbol (it's a re-action, not a Smart-Cut moment) — leave that unchanged.

- [ ] **Step 2: Build + verify visually**

In a Smart Cut session that's transitioned to `.results`, the floating CTA at the bottom should show the gradient glyph + "Apply Cuts" label, with the `.ai` pill style behind it (which is itself flat magenta — that's fine, the glyph carries the gradient identity).

- [ ] **Step 3: Commit**

```bash
git add SonicMerge/Features/SmartCut/Views/Home/SmartCutSessionView.swift
git commit -m "feat(rebrand): Apply Cuts CTA uses SmartCutMark"
```

### Task 4.4: SmartCutStudioContainer — Analyze button + idle orb

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift:182, 242-248`

- [ ] **Step 1: Replace the Analyze button label**

Line 182 currently:

```swift
Label(label, systemImage: "sparkles")
    .frame(maxWidth: .infinity)
```

Replace with:

```swift
HStack(spacing: 6) {
    SmartCutMark(size: .toolbar)
    Text(label)
}
.frame(maxWidth: .infinity)
```

- [ ] **Step 2: Replace the idle-state orb**

Lines 242–248 currently:

```swift
private func smartCutOrb(active: Bool) -> some View {
    Image(systemName: "sparkles")
        .font(.system(size: 56, weight: .bold))
        .foregroundStyle(.tint)
        .symbolEffect(.pulse, options: active ? .repeating : .nonRepeating)
        .frame(width: 80, height: 80)
}
```

Replace with:

```swift
private func smartCutOrb(active: Bool) -> some View {
    SmartCutMark(size: .hero)
        .frame(width: 80, height: 80)
        .scaleEffect(active && pulse ? 1.05 : 1.0)
        .animation(active ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default, value: pulse)
        .onAppear { pulse.toggle() }
}
```

And add the state property at the top of `SmartCutStudioContainer`:

```swift
@State private var pulse: Bool = false
```

`SmartCutMark` is not an SF Symbol so `.symbolEffect(.pulse)` is replaced with a manual scale animation — same visual feel (gentle breathing) without symbol-effect machinery.

- [ ] **Step 3: Build + verify visually**

Idle Smart Cut session → idle orb shows the gradient glyph at 80pt with a gentle scale-pulse. Pressing Analyze → analyzing state still shows the orb (active=true) — verify the pulse continues.

- [ ] **Step 4: Commit**

```bash
git add SonicMerge/Features/SmartCut/Views/Studio/SmartCutStudioContainer.swift
git commit -m "feat(rebrand): Smart Cut idle orb + Analyze button use SmartCutMark"
```

### Task 4.5: Full-suite test pass + visual smoke

- [ ] **Step 1: Run full suite**

Run: `set -o pipefail; xcodebuild ... -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3`
Expected: `FAIL=5` (baseline preserved).

- [ ] **Step 2: Manual smoke**

On the simulator, navigate: Smart Cut tab (verify tab icon) → empty state (verify hero) → import sample → idle (verify orb) → analyze → results (verify Apply Cuts CTA) → toggle theme to light, repeat.

If any visual issue, file a follow-up note in `docs/superpowers/qa/2026-05-04-cleancut-rebrand-manual-qa.md` (Chunk 5 will create the file).

---

## Chunk 5: Onboarding callsite swap + manual QA + final

### Task 5.1: Onboarding hero — step 1 BrandOpenerStep

**Files:**
- Modify: `SonicMerge/Features/Onboarding/OnboardingFlow.swift:158-176`

- [ ] **Step 1: Replace the hero badge with SmartCutMark inside a fire-gradient frame**

Replace lines 158–176 (the `// Hero badge — gradient at 20% alpha, sparkles inside` ZStack) with:

```swift
// Hero badge — fire gradient frame at 20% alpha, SmartCutMark inside.
// Frame uses the gradient stops from the semantic resolver so it matches
// the in-app fire identity exactly.
ZStack {
    RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(LinearGradient(
            colors: semantic.accentAIGradientStops.map { Color(uiColor: $0) }.map { $0.opacity(0.20) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ))
    SmartCutMark(size: .hero)
        .scaleEffect(bounceTrigger ? 1.05 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.55), value: bounceTrigger)
}
.frame(width: 80, height: 80)
.accessibilityHidden(true)
.padding(.bottom, 20)
.onAppear { if !reduceMotion { bounceTrigger.toggle() } }
```

The previous `.symbolEffect(.bounce)` is replaced with a `.scaleEffect` + `.spring` animation since `SmartCutMark` is not a SF Symbol. Same one-shot bounce on appear.

### Task 5.2: Onboarding feature pill — accept arbitrary icon view

**Files:**
- Modify: `SonicMerge/Features/Onboarding/OnboardingFlow.swift:193-249` (the `FeaturePill` struct + its 3 callsites at 193–198)

- [ ] **Step 1: Refactor `FeaturePill` to accept a `View` instead of a String symbol**

Replace the `FeaturePill` struct with:

```swift
private struct FeaturePill<Icon: View>: View {
    @ViewBuilder let icon: () -> Icon
    let iconBg: Color
    let title: String
    let subtitle: String
    let semantic: SonicMergeSemantic

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(iconBg)
                icon()
                    .frame(width: 14, height: 14)  // matches the prior 13pt SF Symbol weight
            }
            .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
                Text(subtitle).font(.caption)
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: semantic.surfaceCard))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(uiColor: .systemGray5), lineWidth: 0.5)
                )
        )
    }
}
```

Update the 3 callsites at lines 193–198:

```swift
VStack(spacing: 10) {
    FeaturePill(icon: {
        SmartCutMark(size: .toolbar, monochromeTint: .white)
    }, iconBg: Color(uiColor: semantic.accentAI),
        title: "Smart Cut", subtitle: "remove fillers", semantic: semantic)
    FeaturePill(icon: {
        Image(systemName: "waveform.badge.minus")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
    }, iconBg: Color(uiColor: semantic.accentAI),
        title: "Denoise", subtitle: "clean noisy clips", semantic: semantic)
    FeaturePill(icon: {
        Image(systemName: "rectangle.stack")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
    }, iconBg: Color(uiColor: semantic.accentAction),
        title: "Merge", subtitle: "combine audio", semantic: semantic)
}
```

The Smart Cut pill's icon uses `monochromeTint: .white` — at 14pt the gradient is too small to read; flat white on the magenta `iconBg` is cleaner. Denoise + Merge keep their SF Symbols (they aren't Smart Cut, the rebrand is glyph-targeted).

### Task 5.3: Onboarding sample-podcast CTA — fire gradient

**Files:**
- Modify: `SonicMerge/Features/Onboarding/OnboardingFlow.swift:412-417`

- [ ] **Step 1: Replace the Label + flat capsule fill**

Lines 412–417 currently render:

```swift
Label("Smart Cut This Sample", systemImage: "sparkles")
    .font(...)
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 14)
    .background(Capsule().fill(Color(uiColor: semantic.accentAI)))
```

Replace with:

```swift
HStack(spacing: 6) {
    SmartCutMark(size: .toolbar, monochromeTint: .white)
    Text("Smart Cut This Sample")
}
.font(...)
.foregroundStyle(.white)
.frame(maxWidth: .infinity)
.padding(.vertical, 14)
.background(Capsule().fill(LinearGradient(
    colors: semantic.accentAIGradientStops.map { Color(uiColor: $0) },
    startPoint: .leading,
    endPoint: .trailing
)))
```

The CTA gets the **full fire gradient** as its capsule fill (per spec D-07 — matches the in-app "Apply Cuts" feel). Glyph uses monochrome white because at 22pt against a gradient capsule, a gradient-on-gradient glyph muddies. White-on-fire reads cleanly.

(Preserve the existing `.font(...)` declaration verbatim — don't change typography.)

### Task 5.4: Build, full-suite test, manual QA checklist

- [ ] **Step 1: Build to verify all onboarding edits compile**

Run: `xcodebuild ... build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED.

- [ ] **Step 2: Run full suite**

Run: `set -o pipefail; xcodebuild ... -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3`
Expected: `FAIL=5` baseline preserved. If any new failure, root-cause before proceeding.

- [ ] **Step 3: Write the manual QA checklist**

Create `docs/superpowers/qa/2026-05-04-cleancut-rebrand-manual-qa.md`:

```markdown
# CleanCut Rebrand — Manual QA Checklist

**Build:** local debug, iPhone 17 simulator (iOS 17 floor; verify on iOS 18 sim too if convenient).
**Reset before testing:** delete the app from the simulator Home screen so iOS clears its app-icon cache.

## App icon
- [ ] After fresh install, Home screen shows the new icon: deep navy canvas with 8 fire-gradient bars + diagonal white slash. Not the generic `sparkles` placeholder.
- [ ] Toggle simulator appearance light → dark. Icon variant changes per Contents.json (currently same canvas in both, per spec D-03).
- [ ] iOS 18+ tinted variant: long-press a Home empty area → Edit Home Screen → tinted appearance. Icon should auto-tint to a single-color version of the glyph.

## Tab bar
- [ ] Smart Cut tab (leftmost): shows the fire-gradient glyph, NOT a flat-tinted symbol.
- [ ] Selected vs. unselected state: the glyph stays full-color in both (intentional — see spec D-06 visual asymmetry note).
- [ ] Denoise + Merge tabs: their SF Symbols template-tint with the new violet `accentAction` color when selected, gray when unselected.

## Smart Cut tab
- [ ] Empty state: hero badge shows fire-tinted squircle with the gradient glyph.
- [ ] Import a clip → idle state shows orb with the gradient glyph + gentle scale-pulse.
- [ ] Tap Analyze → analyzing state still shows the orb pulsing.
- [ ] Results state → "Apply Cuts" floating CTA: gradient glyph + label, magenta pill background.
- [ ] Studio's idle Analyze button: gradient glyph + "Analyze ~N min" label.

## Denoise + Merge tabs
- [ ] Visual unchanged except for color swap: surfaces/cards/text follow the new dark-navy in dark mode and unchanged light mode.
- [ ] Theme toggle in toolbar still works in both directions, both tabs.

## Onboarding (re-trigger by deleting app and reinstalling, or by setting hasOnboarded=false in defaults)
- [ ] Step 1 BrandOpener: hero badge shows fire-tinted squircle + gradient glyph + scale-bounce on appear.
- [ ] Step 1 feature pills: Smart Cut pill has white-glyph-on-magenta; Denoise pill has white SF Symbol on magenta; Merge pill has white SF Symbol on violet.
- [ ] "Smart Cut This Sample" CTA in onboarding step 4 (or wherever the sample lives): full fire-gradient capsule fill + white glyph + label.
- [ ] Onboarding ProgressView tints (Analyzing… / Applying cuts…) read as flat magenta — no gradient (`.tint()` cannot take a gradient — confirm visual is acceptable).
- [ ] Sample-podcast result-summary chip background: flat magenta.

## Theme toggle
- [ ] Light → dark transition: surfaces fade from #FBFBFC to #0A0A18; violet `accentAction` (selected tab indicator, primary CTAs) reads well on both surfaces; magenta `accentAI` reads well on both surfaces.
- [ ] No two-source-of-truth bug: tab bar appearance flips alongside chrome (per RootTabView's environment+preferredColorScheme injection).

## Regression spot-checks
- [ ] Full test suite still reports `FAIL=5` baseline (the same names listed in CLAUDE.md). No new failures.
- [ ] Smart Cut analyze pipeline still works end-to-end on a real audio sample.
- [ ] Denoise tab still produces a clean output on a noisy sample.
- [ ] Merge tab still combines two clips.

## Known intentional visual changes (NOT bugs)
- App icon is the same dark canvas in light/dark/tinted appearance (spec D-03).
- Smart Cut tab icon doesn't dim when unselected (spec D-06).
- Waveform mesh-gradient end-stop changed from system purple to violet (spec non-goal §2 phrasing).
```

- [ ] **Step 4: Commit Chunk 5**

```bash
git add SonicMerge/Features/Onboarding/OnboardingFlow.swift \
        docs/superpowers/qa/2026-05-04-cleancut-rebrand-manual-qa.md
git commit -m "feat(rebrand): onboarding uses SmartCutMark + fire-gradient CTAs

Hero badge swaps sparkles for SmartCutMark inside a fire-tinted squircle.
FeaturePill becomes generic over Icon: View so the Smart Cut pill can
host the mark while Denoise/Merge keep their SF Symbols. Sample-podcast
'Smart Cut This Sample' CTA gets the full fire gradient as its capsule
fill. Adds manual-QA checklist for the rebrand.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 5.5: Update auto-memory feedback rule

**Files:**
- Modify: `/Users/datnnt/.claude/projects/-Users-datnnt-Desktop-DatNNT-App-SonicMerge/memory/feedback_color_discipline.md`
- Modify: `/Users/datnnt/.claude/projects/-Users-datnnt-Desktop-DatNNT-App-SonicMerge/memory/MEMORY.md`

The persisted feedback memory currently says "indigo = navigation/CTAs; lime green reserved for AI moments only." After this rebrand, the rule shape is unchanged but the colors flip.

- [ ] **Step 1: Update `feedback_color_discipline.md`**

Rewrite to: "Two-color brand discipline still in effect: **deep violet `#6F2DBD`** (= `accentAction`) for navigation, primary CTAs, tab-bar selection, back-chevrons. **Magenta `#F0506E`** flat (= `accentAI`) for AI moments that need a single color (chips, ProgressView tints). **Fire gradient red→orange→magenta→violet** (= `accentAIGradientStops`) for AI moments that can host a gradient (Smart Cut mark, Apply Cuts capsule, idle orb). **Why:** user picked direction A in the 2026-05-04 rebrand, replacing indigo+lime with the AHS-Audio-inspired fire palette. **How to apply:** when adding a new visual element, ask: is this navigation (→ violet), is this an AI moment that needs a flat color (→ magenta), or is this an AI moment that can host a gradient (→ fire gradient stops)?"

- [ ] **Step 2: Update the index entry in `MEMORY.md`** (the line description should reflect the new rule shape).

### Task 5.6: Final commit + finishing the branch

- [ ] **Step 1: Run the full suite one last time**

Run: `set -o pipefail; xcodebuild ... -parallel-testing-enabled NO test 2>&1 | tee /tmp/test.log | tail -3`
Expected: `FAIL=5`. If any drift, fix before finishing.

- [ ] **Step 2: Invoke @superpowers:finishing-a-development-branch**

The branch is `main` per user direction; finishing-a-development-branch will likely just verify tests pass and confirm the work is complete (no merge step since there's no feature branch). If the user later decides to push, that's a separate explicit ask.
