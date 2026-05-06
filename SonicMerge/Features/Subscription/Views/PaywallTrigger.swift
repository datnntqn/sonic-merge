import SwiftUI

/// Convenience modifier: present a `PaywallView` as a sheet bound to a
/// `PaywallReason?`. Sub-projects 3+ add wrappers that consult the
/// `PaywallTriggerCoordinator` before calling the underlying paywall(reason:)
/// modifier. Sub-project 1 only needs the modifier itself (Settings calls it).
extension View {
    func paywall(reason: Binding<PaywallReason?>) -> some View {
        self.sheet(item: reason) { actual in
            PaywallView(reason: actual)
                .interactiveDismissDisabled(false)
        }
    }
}

extension PaywallReason: Identifiable {
    var id: String { rawValue }
}
