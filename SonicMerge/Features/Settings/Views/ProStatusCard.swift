import SwiftUI

/// Top of Settings: shows the user's Pro status. When Free, big
/// "Upgrade to Pro" CTA. When Pro, smaller "Manage subscription" link.
struct ProStatusCard: View {

    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(EntitlementService.self) private var entitlements

    @Binding var paywallReason: PaywallReason?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACCOUNT")
                .font(.caption.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
            HStack {
                Text(entitlements.currentEntitlement.displayLabel)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Spacer()
                if entitlements.isPro {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(LinearGradient(
                            colors: semantic.accentAIGradientStops.map { Color(uiColor: $0) },
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                }
            }

            if entitlements.isPro {
                Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                    HStack {
                        Text("Manage subscription")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: semantic.accentAction))
                }
            } else {
                Button {
                    paywallReason = .settingsUpgrade
                } label: {
                    HStack {
                        SmartCutMark(size: .toolbar, monochromeTint: .white)
                            .frame(width: 22, height: 22)
                        Text("Upgrade to Pro")
                    }
                    .font(.system(.body, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(LinearGradient(
                        colors: semantic.accentAIGradientStops.map { Color(uiColor: $0) },
                        startPoint: .leading,
                        endPoint: .trailing
                    )))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: semantic.surfaceCard))
        )
    }
}
