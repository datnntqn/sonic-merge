import SwiftUI
import UIKit

/// One-line message rendered by `CapLimitToast`. Equatable so SwiftUI can
/// diff it on the host's `@State var toastMessage: ToastMessage?` binding;
/// the `id` is fresh on every construction so identical text still triggers
/// a fresh dismiss timer when re-assigned.
struct ToastMessage: Equatable, Identifiable {
    let id = UUID()
    let text: String

    /// "This 7:14 clip exceeds the Free 5-min cap." — Smart Cut / Denoise
    /// length-cap copy. `seconds` is the actual clip duration; `capSeconds`
    /// is the Free-tier ceiling for that workspace (300 or 180).
    static func lengthCap(seconds: TimeInterval, capSeconds: TimeInterval) -> ToastMessage {
        let total = Int(seconds.rounded(.down))
        let mmss = String(format: "%d:%02d", total / 60, total % 60)
        let capMin = Int(capSeconds / 60)
        return ToastMessage(text: "This \(mmss) clip exceeds the Free \(capMin)-min cap.")
    }

    /// "You've used today's 3 free sessions." — daily-quota copy.
    static let dailyCap = ToastMessage(text: "You've used today's 3 free sessions.")

    /// "Free is limited to 3 clips." — Merge clip-count copy.
    static let mergeClipCount = ToastMessage(text: "Free is limited to 3 clips.")
}

/// Top-anchored ephemeral toast that surfaces when a Free user hits a cap
/// but the paywall is throttled (already shown this session, or dismissed
/// past the threshold). Tap to open the paywall via `.settingsUpgrade`,
/// which bypasses the throttle.
///
/// Color is indigo chrome (`semantic.accentAction`). Lime is reserved for
/// AI moments per CLAUDE.md color discipline.
struct CapLimitToast: View {
    let message: ToastMessage
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(Color(uiColor: semantic.accentAction))
            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button {
                onUpgrade()
                onDismiss()
            } label: {
                HStack(spacing: 4) {
                    Text("Upgrade")
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(uiColor: semantic.accentAction))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("CapLimitToast.upgradeButton")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(uiColor: semantic.accentAction).opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .accessibilityIdentifier("CapLimitToast")
        .accessibilityElement(children: .combine)
        .task(id: message.id) {
            UIAccessibility.post(notification: .announcement, argument: message.text)
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { onDismiss() }
        }
    }
}

#if DEBUG
#Preview("CapLimitToast") {
    VStack {
        CapLimitToast(
            message: ToastMessage(text: "This 7:14 clip exceeds the Free 5-min cap."),
            onUpgrade: {},
            onDismiss: {}
        )
        Spacer()
    }
}
#endif
