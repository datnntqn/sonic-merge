//
//  SmartCutMark.swift
//  SonicMerge
//
//  Custom Smart Cut glyph — 8 vertical waveform bars bisected by a diagonal
//  slash. Reads as "audio cut" at every size from 22pt toolbar to 1024pt
//  app icon. Replaces the generic SF Symbol `sparkles`.
//

import SwiftUI

/// Two render modes:
/// - Default: bars filled with the fire gradient (red → orange → magenta → violet)
///   read from `\.sonicMergeSemantic.accentAIGradientStops`.
/// - `monochromeTint:` non-nil: bars filled with that flat color (used when
///   the parent context requires single-color rendering, e.g. SF-Symbol-style
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

        /// Diagonal stroke width as a fraction of pointSize (~1pt @ 22, ~4.5pt @ 96).
        var diagonalStroke: CGFloat { pointSize * 0.047 }
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
            // 8 bars: 4 left of diagonal (heights 16/36/56/78% center→right),
            // 4 right (mirror). Heights are fractions of canvas h.
            let barWidth = w * 0.047
            let gap = w * 0.078
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
        // Note: we deliberately do NOT apply an inner .frame(width:height:) here.
        // Callers pass `.frame(...)` from the outside (tab bar, CTA, hero badge),
        // and an inner frame would conflict when sizes differ from `size.pointSize`.
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
