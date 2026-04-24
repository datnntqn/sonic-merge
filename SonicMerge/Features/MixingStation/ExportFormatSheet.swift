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

    @Environment(\.sonicMergeSemantic) private var semantic

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
                isPresented = false
                onExport(ExportOptions(format: selectedFormat, lufsNormalize: lufsEnabled))
            }
            .buttonStyle(PillButtonStyle(variant: .filled, size: .regular))
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .presentationDetents([.height(320)])
    }
}
