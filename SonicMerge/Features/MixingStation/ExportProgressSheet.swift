// ExportProgressSheet.swift
// SonicMerge

import SwiftUI

/// Non-dismissible modal displayed during export.
/// Shows a ProgressView, percentage text, and a Cancel button.
/// `.interactiveDismissDisabled(true)` prevents swipe-to-dismiss.
struct ExportProgressSheet: View {
    var isNormalizing: Bool = false
    let progress: Float
    let onCancel: () -> Void

    @Environment(\.sonicMergeSemantic) private var semantic
    @State private var cancelHapticTrigger = false

    var body: some View {
        VStack(spacing: 20) {
            Text(isNormalizing ? "Exporting & Normalizing..." : "Exporting...")
                .font(.system(.headline))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
                .padding(.top, 28)

            ProgressView(value: Double(progress))
                .progressViewStyle(.linear)
                .tint(Color(uiColor: semantic.accentAction))
                .padding(.horizontal, 32)

            Text("\(Int(progress * 100))%")
                .font(.system(.caption))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                .monospacedDigit()

            Button(role: .destructive) {
                cancelHapticTrigger.toggle()
                onCancel()
            } label: {
                Text("Cancel Export")
                    .font(.system(.body))
            }
            .padding(.bottom, 32)
            .sensoryFeedback(.impact(weight: .medium), trigger: cancelHapticTrigger)
        }
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(220)])
        .interactiveDismissDisabled(true)
    }
}
