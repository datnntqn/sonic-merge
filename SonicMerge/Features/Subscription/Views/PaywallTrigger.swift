import SwiftUI

/// Coordinator-aware paywall presenter. Routes a `PaywallReason?` binding
/// through `PaywallTriggerCoordinator.decide(_:)` so session throttling and
/// dismiss-count limits apply.
///
/// Two call shapes:
/// - `paywall(reason:)` — sheet only. Used by views that don't need a
///   toast fallback (Settings, sub-views that surface paywall-from-tap).
/// - `paywall(reason:toast:)` — sheet + top-anchored toast fallback. Used
///   by home views where a cap-hit must always feedback to the user; the
///   caller is responsible for assigning the toast content alongside the
///   reason. When `decide(_:)` returns `.fallbackToast`, the modifier
///   clears `reason` and keeps `toast` so the toast renders; on `.present`
///   it clears `toast` and lets the sheet open.
extension View {
    func paywall(reason: Binding<PaywallReason?>) -> some View {
        modifier(PaywallTriggerModifier(reason: reason, toast: .constant(nil)))
    }

    func paywall(reason: Binding<PaywallReason?>,
                 toast: Binding<ToastMessage?>) -> some View {
        modifier(PaywallTriggerModifier(reason: reason, toast: toast))
    }
}

private struct PaywallTriggerModifier: ViewModifier {
    @Binding var reason: PaywallReason?
    @Binding var toast: ToastMessage?
    @Environment(\.paywallCoordinator) private var coordinator
    @Environment(EntitlementService.self) private var entitlementService

    func body(content: Content) -> some View {
        content
            .onChange(of: reason) { _, newValue in
                guard let candidate = newValue else { return }
                switch coordinator.decide(candidate) {
                case .present:
                    // Sheet replaces the toast — drop any pending toast
                    // content the caller assigned alongside the reason.
                    toast = nil
                case .fallbackToast:
                    // Throttled cap-hit — clear the reason so .sheet doesn't
                    // fire; keep the caller-supplied toast content visible.
                    reason = nil
                case .suppress:
                    reason = nil
                    toast = nil
                }
            }
            .sheet(item: $reason) { actual in
                // Explicit re-injection: SwiftUI's env bridging through .sheet
                // is buggy for @Observable-style values, so PaywallView's
                // @Environment(EntitlementService.self) lookup crashes without
                // this explicit pass-through. Keypath-based env values
                // (\.storeKitClient, \.sonicMergeSemantic) propagate fine.
                PaywallView(reason: actual)
                    .environment(entitlementService)
                    .interactiveDismissDisabled(false)
                    .onDisappear {
                        coordinator.recordDismiss(actual)
                    }
            }
            .overlay(alignment: .top) {
                if let current = toast {
                    CapLimitToast(
                        message: current,
                        onUpgrade: { reason = .settingsUpgrade },
                        onDismiss: { toast = nil }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: toast)
    }
}

extension PaywallReason: Identifiable {
    var id: String { rawValue }
}
