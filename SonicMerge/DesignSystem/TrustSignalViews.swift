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
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title3)
                .foregroundStyle(Color(uiColor: SonicMergeTheme.ColorPalette.aiAccent))
            VStack(alignment: .leading, spacing: 4) {
                Text(TrustSignalCopy.localFirstTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(uiColor: SonicMergeTheme.ColorPalette.primaryText))
                Text(TrustSignalCopy.localFirstSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(uiColor: SonicMergeTheme.ColorPalette.cardSurface))
        .clipShape(RoundedRectangle(cornerRadius: SonicMergeTheme.Radius.card, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}
