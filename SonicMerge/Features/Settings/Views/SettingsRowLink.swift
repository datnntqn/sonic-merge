import SwiftUI

/// Standard disclosure-indicator row used for legal links + about.
struct SettingsRowLink: View {

    @Environment(\.sonicMergeSemantic) private var semantic
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack {
                Text(title)
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
    }
}
