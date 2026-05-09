import SwiftUI

struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.storeKitClient) private var client
    @Environment(EntitlementService.self) private var entitlements

    @State private var paywallReason: PaywallReason?
    @State private var isRestoring = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProStatusCard(paywallReason: $paywallReason)

                VStack(spacing: 0) {
                    SettingsRowLink(title: "Privacy Policy", url: URL(string: "https://datnntqn.github.io/clearcut-legal/privacy.html")!)
                    Divider().padding(.leading, 16)
                    SettingsRowLink(title: "Terms of Service", url: URL(string: "https://datnntqn.github.io/clearcut-legal/terms.html")!)
                    Divider().padding(.leading, 16)
                    SettingsRowLink(title: "About", url: URL(string: "https://datnntqn.github.io/clearcut-legal/")!)
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(uiColor: semantic.surfaceCard))
                )

                HStack {
                    RestorePurchasesButton(isRestoring: $isRestoring) {
                        try await client?.restore()
                    }
                    Spacer()
                    Text("v\(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
                        .font(.caption2)
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                }
                .padding(.horizontal, 4)
                .padding(.top, 8)
            }
            .padding(20)
        }
        .background(Color(uiColor: semantic.surfaceBase))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(Color(uiColor: semantic.accentAction))
            }
        }
        .paywall(reason: $paywallReason)
        // No .task to create StoreKitClient — it's injected via
        // \.storeKitClient from RootTabView at app level. If client is
        // nil here (defensive), Restore Purchases simply no-ops; that
        // shouldn't happen in practice since the root injection runs
        // before any view is rendered.
    }
}

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
    var appBuild: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }
}
