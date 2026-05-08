// SonicMerge/DesignSystem/ImportSourceSheet.swift
//
// Bottom sheet shown when the user taps any tab's Import button. Renders
// three source rows (Files / Record / Photos & Videos) and writes the
// chosen action into a binding. The host view reads the binding from
// .sheet(onDismiss:) and presents the matching destination.
//

import SwiftUI

struct ImportSourceSheet: View {

    @Binding var pendingAction: ImportSourceAction?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color(uiColor: semantic.textSecondary).opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 4)

            Text("Import audio")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            row(action: .files,
                systemImage: "folder.fill",
                title: "Files / iCloud Drive",
                subtitle: "Browse files on your device or iCloud")
            row(action: .record,
                systemImage: "mic.fill",
                title: "Record now",
                subtitle: "Capture audio with the microphone")
            row(action: .photos,
                systemImage: "photo.on.rectangle",
                title: "Photos & Videos",
                subtitle: "Extract audio from a video")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .background(Color(uiColor: semantic.surfaceBase))
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.hidden)
    }

    private func row(action: ImportSourceAction,
                     systemImage: String,
                     title: String,
                     subtitle: String) -> some View {
        Button {
            pendingAction = action
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(uiColor: semantic.accentAction))
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(Color(uiColor: semantic.textPrimary))
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(uiColor: semantic.textSecondary).opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .studioFrostedCapsule(cornerRadius: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
