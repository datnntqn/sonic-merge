import SwiftUI

/// Small text button used inside the paywall footer + Settings.
/// Calls `StoreKitClient.restore()`. Shows a brief inline spinner while
/// restoring. Apple guideline 3.1.1 requires this be visible on the
/// paywall and somewhere in Settings.
struct RestorePurchasesButton: View {

    @Environment(\.sonicMergeSemantic) private var semantic

    @Binding var isRestoring: Bool
    let onRestore: () async throws -> Void

    var body: some View {
        Button {
            Task {
                isRestoring = true
                defer { isRestoring = false }
                try? await onRestore()
            }
        } label: {
            if isRestoring {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color(uiColor: semantic.textSecondary))
            } else {
                Text("Restore Purchases")
                    .font(.footnote)
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
            }
        }
        .accessibilityLabel("Restore Purchases")
    }
}
