// ExportProgressSheet.swift
// SonicMerge

import SwiftUI

/// Non-dismissible modal displayed during export.
/// Shows a ProgressView, percentage text, and a Cancel button.
/// .interactiveDismissDisabled(true) prevents swipe-to-dismiss.
struct ExportProgressSheet: View {
    var isNormalizing: Bool = false
    let progress: Float
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(isNormalizing ? "Exporting & Normalizing..." : "Exporting...")
                .font(.system(.headline))
                .foregroundStyle(Color(red: 0.110, green: 0.110, blue: 0.118))
                .padding(.top, 28)

            ProgressView(value: Double(progress))
                .progressViewStyle(.linear)
                .tint(Color(red: 0, green: 0.478, blue: 1.0))
                .padding(.horizontal, 32)

            Text("\(Int(progress * 100))%")
                .font(.system(.caption))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Button(role: .destructive, action: onCancel) {
                Text("Cancel")
                    .font(.system(.body))
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(220)])
        .interactiveDismissDisabled(true)
    }
}
