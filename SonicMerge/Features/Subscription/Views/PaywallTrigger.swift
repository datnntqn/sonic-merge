import SwiftUI

/// Coordinator-aware paywall presenter. Same call signature as before
/// (`view.paywall(reason: $paywallReason)`) — but every presentation now
/// goes through `PaywallTriggerCoordinator.shouldPresent(_:)` so session
/// throttling and dismiss-count limits actually apply.
///
/// Sub-project 2 sites that just write `paywallReason = .X` get the new
/// behavior for free; no callsite change required.
extension View {
    func paywall(reason: Binding<PaywallReason?>) -> some View {
        modifier(PaywallTriggerModifier(reason: reason))
    }
}

private struct PaywallTriggerModifier: ViewModifier {
    @Binding var reason: PaywallReason?
    @Environment(\.paywallCoordinator) private var coordinator

    func body(content: Content) -> some View {
        content
            .onChange(of: reason) { _, newValue in
                guard let candidate = newValue else { return }
                if !coordinator.shouldPresent(candidate) {
                    reason = nil
                } else {
                    coordinator.markPresented(candidate)
                }
            }
            .sheet(item: $reason) { actual in
                PaywallView(reason: actual)
                    .interactiveDismissDisabled(false)
                    .onDisappear {
                        coordinator.recordDismiss(actual)
                    }
            }
    }
}

extension PaywallReason: Identifiable {
    var id: String { rawValue }
}
