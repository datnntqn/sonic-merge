// CircularImportButton.swift
// SonicMerge
//
// Indigo circular waveform.badge.plus button used on every home screen as
// the import affordance. Two sizes: .hero (empty state) and .pinned
// (loaded state, top-trailing of the list/timeline).

import SwiftUI

struct CircularImportButton: View {
    enum Size {
        case hero    // 60×60, 26pt icon, shadow 0.32/r:16/y:6
        case pinned  // 44×44, 18pt icon, shadow 0.28/r:10/y:4

        var diameter: CGFloat { self == .hero ? 60 : 44 }
        var iconPointSize: CGFloat { self == .hero ? 26 : 18 }
        var shadowOpacity: Double { self == .hero ? 0.32 : 0.28 }
        var shadowRadius: CGFloat { self == .hero ? 16 : 10 }
        var shadowY: CGFloat { self == .hero ? 6 : 4 }
    }

    let size: Size
    let action: () -> Void

    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        Button(action: action) {
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: size.iconPointSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size.diameter, height: size.diameter)
                .background(Circle().fill(Color(uiColor: semantic.accentAction)))
                .shadow(
                    color: Color(uiColor: semantic.accentAction).opacity(size.shadowOpacity),
                    radius: size.shadowRadius,
                    x: 0,
                    y: size.shadowY
                )
        }
        .accessibilityLabel("Add audio file")
    }
}
