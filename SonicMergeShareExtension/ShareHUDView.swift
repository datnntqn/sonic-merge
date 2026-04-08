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

    var body: some View {
        ZStack {
            backgroundGray.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: iconName)
                    .font(.system(size: 32))
                    .foregroundStyle(accentBlue)

                Text(statusText)
                    .font(.system(.body))
                    .foregroundStyle(primaryText)

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

                if model.state == .error {
                    Button(role: .destructive) {
                        onDismiss()
                    } label: {
                        Text("Dismiss")
                            .font(.system(.body, weight: .semibold))
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
        }
    }

    private var statusText: String {
        switch model.state {
        case .copying: return "Adding to SonicMerge..."
        case .success: return "Added!"
        case .error: return "Could not add file"
        }
    }
}
