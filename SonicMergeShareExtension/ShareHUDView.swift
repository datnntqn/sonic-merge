//
//  ShareHUDView.swift
//  SonicMergeShareExtension
//

import SwiftUI

struct ShareHUDView: View {
    let model: ShareHUDModel
    var onDismiss: () -> Void = {}

    // Colors from UX-01 / UI-SPEC
    private let backgroundGray = Color(red: 0.973, green: 0.976, blue: 0.980)
    private let accentBlue = Color(red: 0, green: 0.478, blue: 1.0)
    private let primaryText = Color(red: 0.110, green: 0.110, blue: 0.118)
    // CleanCut's "accentAction" indigo (#5856D6). Inlined here because the
    // Share Extension is a separate process and does not have access to the
    // main app's `\.sonicMergeSemantic` environment value. Keep in sync with
    // SonicMergeTheme palette.
    private let accentIndigo = Color(red: 0x58 / 255, green: 0x56 / 255, blue: 0xD6 / 255)

    var body: some View {
        ZStack {
            backgroundGray.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: iconName)
                    .font(.system(size: 32))
                    .foregroundStyle(iconColor)

                Text(statusText)
                    .font(.system(.body))
                    .foregroundStyle(primaryText)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(.subheadline))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                if !model.filename.isEmpty && model.state == .copying {
                    Text(model.filename)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if model.state == .copying {
                    ProgressView()
                        .tint(accentBlue)
                }

                if showsDismissButton {
                    Button {
                        onDismiss()
                    } label: {
                        Text("Done")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(dismissTint)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            .padding(.horizontal, 16)
        }
    }

    private var iconName: String {
        switch model.state {
        case .copying: return "doc.badge.plus"
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .freeLimitReached: return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch model.state {
        case .freeLimitReached: return accentIndigo
        default: return accentBlue
        }
    }

    private var statusText: String {
        switch model.state {
        case .copying: return "Adding to CleanCut..."
        case .success: return "Added!"
        case .error: return "Could not add file"
        case .freeLimitReached: return "Free limit reached"
        }
    }

    private var subtitle: String? {
        if case .freeLimitReached(let seconds) = model.state {
            let total = Int(seconds.rounded(.down))
            let mmss = String(format: "%d:%02d", total / 60, total % 60)
            return "This \(mmss) clip exceeds the Free 5-min cap. Open CleanCut to upgrade."
        }
        return nil
    }

    private var showsDismissButton: Bool {
        switch model.state {
        case .error, .freeLimitReached: return true
        default: return false
        }
    }

    private var dismissTint: Color {
        switch model.state {
        case .freeLimitReached: return accentIndigo
        case .error: return .red
        default: return accentBlue
        }
    }
}
