#!/usr/bin/env swift
//
// RenderSmartCutAppIcon.swift
//
// Headless macOS-host renderer producing the PNGs consumed by
// Assets.xcassets/AppIcon.appiconset/ and SmartCutTabIcon.imageset/.
//
// Run from repo root:
//     swift Scripts/RenderSmartCutAppIcon.swift
//
// Re-run only when the SmartCutMark glyph geometry changes. The output
// PNGs are committed to git.
//
// IMPORTANT: glyph constants here MUST match SmartCutMark.swift. Drift
// check pre-commit (compares the two files line-by-line on the geometry
// constants):
//     diff <(grep -E 'leftHeights|rightHeights|leftOpacit|rightOpacit|barWidth|gap |0\.42|0\.58|0\.10|0\.90' \
//             SonicMerge/DesignSystem/SmartCutMark.swift) \
//          <(grep -E 'leftHeights|rightHeights|leftOpacit|rightOpacit|barWidth|gap |0\.42|0\.58|0\.10|0\.90' \
//             Scripts/RenderSmartCutAppIcon.swift)

import SwiftUI
import AppKit

let stops: [Color] = [
    Color(red: 255/255, green: 78/255,  blue: 80/255),   // ember red
    Color(red: 249/255, green: 166/255, blue: 108/255),  // ember orange
    Color(red: 240/255, green: 80/255,  blue: 110/255),  // magenta
    Color(red: 111/255, green: 45/255,  blue: 189/255)   // deep violet
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
            // Always include an explicit background — Color.clear when caller
            // passes nil — so ImageRenderer flushes alpha through to the PNG.
            // (Without this, macOS ImageRenderer can rasterize transparent
            // regions as opaque white when the SwiftUI hierarchy has no
            // explicit background.)
            (background ?? Color.clear)
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

// render() must be @MainActor because ImageRenderer is @MainActor-isolated
// in Swift 6. Called from within MainActor.run { } below.
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

    // Tab bar — iOS UITabBar grid is 25pt selected; ship 25/50/75 px
    // (1x/2x/3x) so @3x devices render crisp. Transparent bg, fire gradient.
    render(Mark(canvas: 25, background: nil, monochromeTint: nil),
           size: 25, to: "\(tabIconDir)/SmartCutTabIcon.png")
    render(Mark(canvas: 50, background: nil, monochromeTint: nil),
           size: 50, to: "\(tabIconDir)/SmartCutTabIcon@2x.png")
    render(Mark(canvas: 75, background: nil, monochromeTint: nil),
           size: 75, to: "\(tabIconDir)/SmartCutTabIcon@3x.png")
}
