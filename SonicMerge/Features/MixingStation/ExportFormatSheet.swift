// ExportFormatSheet.swift
// SonicMerge

import SwiftUI

/// Bottom sheet presented when user taps Export.
/// User selects .m4a or .wav, then taps the Export button to begin.
struct ExportFormatSheet: View {
    @Binding var isPresented: Bool
    let onExport: (ExportFormat) -> Void

    @State private var selectedFormat: ExportFormat = .m4a

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

            Button(action: {
                isPresented = false
                onExport(selectedFormat)
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
        .presentationDetents([.height(200)])
    }
}
