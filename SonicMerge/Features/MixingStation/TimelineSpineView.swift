// TimelineSpineView.swift
// SonicMerge
//
// Phase 7 (MIX-02): Central vertical connecting line for the Vertical Timeline Hybrid layout.
// Drawn per-row via `.background(alignment: .leading)` on each clip's VStack in MergeTimelineView,
// locked to a fixed 60pt leading inset. Decorative — accessibilityHidden.

import SwiftUI
import UIKit

struct TimelineSpineView: View {
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Horizontal distance from the row leading edge to the spine centerline.
    /// 60pt = row inset(16) + card padding(16) + half waveform thumbnail(50) - half line width(1) + rounding.
    /// See 07-UI-SPEC.md "Central Connecting Line" for the full math.
    static let leadingInset: CGFloat = 60

    /// Line thickness in points.
    static let thickness: CGFloat = 2

    var body: some View {
        Rectangle()
            .fill(Color(uiColor: semantic.accentGlow).opacity(opacity))
            .frame(width: Self.thickness)
            .padding(.leading, Self.leadingInset)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    private var opacity: Double {
        // reduceTransparency bumps the line from 0.35 → 0.55 for stronger contrast
        reduceTransparency ? 0.55 : 0.35
    }
}

#Preview("TimelineSpineView") {
    ZStack(alignment: .topLeading) {
        Color.white
        TimelineSpineView()
            .frame(height: 200)
    }
    .frame(width: 375, height: 200)
}
