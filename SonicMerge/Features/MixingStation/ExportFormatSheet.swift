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
struct ExportFormatSheet: View {
    @Binding var isPresented: Bool
    let onExport: (ExportOptions) -> Void

    @State private var selectedFormat: ExportFormat = .m4a
    @AppStorage("lufsNormalizationEnabled") private var lufsEnabled: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Export Format")
                .font(.system(.headline))
                .foregroundStyle(Color(uiColor: SonicMergeTheme.ColorPalette.primaryText))
                .padding(.top, 20)

            Text("Files are rendered locally on your device.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

            Picker("Format", selection: $selectedFormat) {
                Text(".m4a (AAC)").tag(ExportFormat.m4a)
                Text(".wav (Lossless)").tag(ExportFormat.wav)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)

            // LUFS normalization toggle row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Normalize to -16 LUFS")
                        .font(.system(.body))
                        .foregroundStyle(Color(uiColor: SonicMergeTheme.ColorPalette.primaryText))
                    Text("Podcast standard (-16 LUFS)")
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $lufsEnabled)
                    .labelsHidden()
                    .tint(Color(uiColor: SonicMergeTheme.ColorPalette.primaryAccent))
            }
            .padding(.horizontal, 24)

            Button(action: {
                isPresented = false
                onExport(ExportOptions(format: selectedFormat, lufsNormalize: lufsEnabled))
            }) {
                Text("Export")
                    .font(.system(.body, design: .default, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(uiColor: SonicMergeTheme.ColorPalette.primaryAccent))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .presentationDetents([.height(320)])
    }
}
