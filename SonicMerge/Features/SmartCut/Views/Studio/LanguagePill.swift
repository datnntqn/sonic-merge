// SonicMerge/Features/SmartCut/Views/Studio/LanguagePill.swift
//
// Compact tappable pill showing the session's analysis language. Tap opens
// LocalePicker. Pinned to ENGLISH names regardless of device locale until
// full UI localization lands (see spec Non-Goals — visual consistency with
// the rest of the English-only studio).
//

import SwiftUI

struct LanguagePill: View {
    let localeIdentifier: String  // BCP-47, e.g. "es-ES"
    let onTap: () -> Void
    var isDisabled: Bool = false

    @Environment(\.sonicMergeSemantic) private var semantic

    private var displayName: String {
        Locale(identifier: "en")
            .localizedString(forIdentifier: localeIdentifier)
            ?? localeIdentifier
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 13, weight: .semibold))
                    .accessibilityHidden(true)
                Text("Language: ")
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
                + Text(displayName)
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
                    .fontWeight(.semibold)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
                    .accessibilityHidden(true)
            }
            .font(.system(.subheadline, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color(uiColor: semantic.surfaceCard))
            )
            .overlay(
                Capsule().strokeBorder(Color(uiColor: .systemGray5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
        .accessibilityLabel("Language: \(displayName). Tap to change.")
    }
}
