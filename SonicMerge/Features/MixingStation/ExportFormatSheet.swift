// ExportFormatSheet.swift
// SonicMerge

import SwiftUI
import UIKit

/// Carries export configuration from ExportFormatSheet to the export callback.
/// Introduced in Phase 4 to add the LUFS normalization flag alongside format.
struct ExportOptions: Sendable {
    let format: ExportFormat
    let lufsNormalize: Bool
}

/// Bottom sheet presented when user taps Export.
/// User selects .m4a or .wav, then taps the Export button to begin.
/// Free users are restricted to .wav; .m4a shows a PRO badge and triggers the paywall.
struct ExportFormatSheet: View {
    @Binding var isPresented: Bool
    @Binding var paywallReason: PaywallReason?
    let onExport: (ExportOptions) -> Void

    @State private var selectedFormat: ExportFormat = .wav
    @AppStorage("lufsNormalizationEnabled") private var lufsEnabled: Bool = false

    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(EntitlementService.self) private var entitlements

    var body: some View {
        VStack(spacing: 24) {
            Text("Export Format")
                .font(.system(.headline))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
                .padding(.top, 20)

            Text("Files are rendered locally on your device.")
                .font(.caption)
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

            VStack(spacing: 8) {
                formatRow(format: .wav, label: ".wav (Lossless)", isPro: false)
                formatRow(format: .m4a, label: ".m4a (AAC)", isPro: !entitlements.isPro)
            }
            .padding(.horizontal, 24)

            // LUFS normalization toggle row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Normalize to -16 LUFS")
                        .font(.system(.body))
                        .foregroundStyle(Color(uiColor: semantic.textPrimary))
                    Text("Podcast standard (-16 LUFS)")
                        .font(.system(.caption))
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                }
                Spacer()
                Toggle("", isOn: $lufsEnabled)
                    .labelsHidden()
                    .tint(Color(uiColor: semantic.accentAction))
            }
            .padding(.horizontal, 24)

            Button("Export Audio") {
                if !entitlements.isPro && selectedFormat != .wav {
                    paywallReason = .watermarkExport
                    return
                }
                isPresented = false
                onExport(ExportOptions(format: selectedFormat, lufsNormalize: lufsEnabled))
            }
            .buttonStyle(PillButtonStyle(variant: .filled, size: .regular))
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .presentationDetents([.height(320)])
    }

    @ViewBuilder
    private func formatRow(format: ExportFormat, label: String, isPro: Bool) -> some View {
        Button {
            if isPro {
                paywallReason = .watermarkExport
            } else {
                selectedFormat = format
            }
        } label: {
            HStack {
                Image(systemName: selectedFormat == format ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(Color(uiColor: semantic.accentAction))
                Text(label)
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
                Spacer()
                if isPro {
                    Text("PRO")
                        .font(.caption2.weight(.heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(LinearGradient(
                            colors: semantic.accentAIGradientStops.map { Color(uiColor: $0) },
                            startPoint: .leading, endPoint: .trailing
                        )))
                        .foregroundStyle(.white)
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
