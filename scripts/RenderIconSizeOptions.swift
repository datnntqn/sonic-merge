#!/usr/bin/env swift
//
// RenderIconSizeOptions.swift
//
// One-shot helper for the visual companion: renders 4 candidate app-icon
// sizes (100% / 92% / 84% / 76% of canvas) into the brainstorm screen
// directory so the user can pick one in the browser.
//
// Run from repo root:
//     swift scripts/RenderIconSizeOptions.swift
//

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

    var body: some View {
        ZStack {
            Color.clear
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let barWidth = w * 0.047
                let gap = w * 0.078
                let leftHeights: [CGFloat] = [0.16, 0.36, 0.56, 0.78]
                let rightHeights: [CGFloat] = [0.78, 0.56, 0.36, 0.16]
                let leftOpacity: [CGFloat] = [0.35, 0.55, 0.80, 1.00]
                let rightOpacity: [CGFloat] = [1.00, 0.80, 0.55, 0.35]
                let fill = LinearGradient(colors: stops, startPoint: .leading, endPoint: .trailing)
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

struct PaddedIcon: View {
    let canvas: CGFloat
    let glyphScale: CGFloat
    /// iOS applies a squircle corner-radius mask of ~22.37% of canvas. Pre-mask
    /// the preview here so it matches the Home-screen rendering.
    var cornerRadius: CGFloat { canvas * 0.2237 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(deepNavy)
            Mark(canvas: canvas * glyphScale)
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
    try? png.write(to: url)
    print("✓ \(path)")
}

let outDir = ".superpowers/brainstorm/39586-1777903090"

await MainActor.run {
    // Four scale options, all rendered at 512px for browser-preview clarity.
    render(PaddedIcon(canvas: 512, glyphScale: 1.00), size: 512, to: "\(outDir)/icon-100.png")
    render(PaddedIcon(canvas: 512, glyphScale: 0.92), size: 512, to: "\(outDir)/icon-92.png")
    render(PaddedIcon(canvas: 512, glyphScale: 0.84), size: 512, to: "\(outDir)/icon-84.png")
    render(PaddedIcon(canvas: 512, glyphScale: 0.76), size: 512, to: "\(outDir)/icon-76.png")
}
