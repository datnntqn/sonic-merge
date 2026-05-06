import SwiftUI

/// Gear icon in the home-view toolbar. Tap presents Settings as a sheet.
/// Lives in all 3 home views (SmartCut / Denoise / Merge).
///
/// Note: `EntitlementService` and `\.storeKitClient` are NOT injected here
/// — RootTabView's body injects them at the root, and `.sheet` content
/// inherits the parent environment automatically (SwiftUI sheet
/// modal-presentation rules). Re-injecting would be redundant.
struct SettingsToolbarButton: View {

    @Environment(\.sonicMergeSemantic) private var semantic
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(uiColor: semantic.accentAction))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color(uiColor: semantic.surfaceCard)))
        }
        .accessibilityLabel("Settings")
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                SettingsView()
            }
        }
    }
}
