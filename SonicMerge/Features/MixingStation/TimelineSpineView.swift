// TimelineSpineView.swift
// SonicMerge
//
// Phase 7 (MIX-02): Central vertical connecting line for the Vertical Timeline Hybrid layout.
// Phase 10: refined to 1pt with vertical accentGlow gradient (top→transparent) per
// Continuous Stream design spec.

import SwiftUI
import UIKit

struct TimelineSpineView: View {
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Horizontal distance from the row leading edge to the spine centerline.
    /// Unchanged from Phase 7 even though the waveform thumbnail shrinks in Phase 10 —
    /// keeping the inset preserves layout stability per the design spec.
    static let leadingInset: CGFloat = 60

    /// Line thickness in points. Phase 10: 2pt → 1pt for finer visual presence.
    static let thickness: CGFloat = 1

    var body: some View {
        Rectangle()
            .fill(spineGradient)
            .frame(width: Self.thickness)
            .padding(.leading, Self.leadingInset)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    private var spineGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(uiColor: semantic.accentGlow).opacity(topStopOpacity), location: 0.0),
                .init(color: Color(uiColor: semantic.accentGlow).opacity(0.0), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var topStopOpacity: Double {
        // reduceTransparency raises the top stop from 0.55 → 0.75 for stronger contrast.
        reduceTransparency ? 0.75 : 0.55
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
