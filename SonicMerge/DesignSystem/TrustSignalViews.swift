// TrustSignalViews.swift
// SonicMerge
//
// Local-first and on-device AI messaging. English UI copy.

import SwiftUI
import UIKit

enum TrustSignalCopy {
    static let localFirstTitle = "Private by design"
    static let localFirstSubtitle = "Audio stays on your iPhone. Processing runs on-device — no upload, no account."
    static let aiDenoiseTitle = "On-device AI denoise"
    static let aiDenoiseSubtitle = "Core ML removes noise from your merge. Your files never leave this device."
}

struct LocalFirstTrustStrip: View {
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title3)
                .foregroundStyle(Color(uiColor: semantic.accentGlow))
            VStack(alignment: .leading, spacing: 4) {
                Text(TrustSignalCopy.localFirstTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
                Text(TrustSignalCopy.localFirstSubtitle)
                    .font(.caption)
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    Color(uiColor: semantic.accentGlow).opacity(0.30),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color(uiColor: semantic.accentGlow).opacity(0.20),
            radius: 12,
            x: 0,
            y: 0
        )
    }

    @ViewBuilder
    private var glassBackground: some View {
        if reduceTransparency {
            Color(uiColor: semantic.surfaceCard)
        } else {
            ZStack {
                Color(uiColor: semantic.accentGlow).opacity(0.08)
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }
}
