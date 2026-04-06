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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title3)
                .foregroundStyle(Color(uiColor: semantic.trustIcon))
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
        .background(Color(uiColor: semantic.surfaceElevated))
        .clipShape(RoundedRectangle(cornerRadius: SonicMergeTheme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SonicMergeTheme.Radius.card, style: .continuous)
                .strokeBorder(Color(uiColor: semantic.trustIcon).opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}
