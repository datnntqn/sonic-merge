// ExportFormatSheet.swift
// SonicMerge

import SwiftUI

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
                .foregroundStyle(Color(red: 0.110, green: 0.110, blue: 0.118))
                .padding(.top, 20)

            Picker("Format", selection: $selectedFormat) {
                Text(".m4a (AAC)").tag(ExportFormat.m4a)
                Text(".wav (Lossless)").tag(ExportFormat.wav)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)

            Toggle("Normalize Loudness (-16 LUFS)", isOn: $lufsEnabled)
                .font(.system(.subheadline))
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
                    .background(Color(red: 0, green: 0.478, blue: 1.0))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .presentationDetents([.height(280)])
    }
}
