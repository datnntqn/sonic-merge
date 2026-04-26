import SwiftUI

/// A glassmorphic chassis for a floating bottom action bar.
///
/// Renders its content inside a Capsule().fill(.ultraThinMaterial) with a soft drop shadow,
/// padded for safe-area clearance. Intended to be placed inside an `.overlay(alignment: .bottom)`
/// or in a ZStack's bottom alignment.
///
/// Empty-state handling: callers that want the bar to disappear in some states should wrap the
/// entire `FloatingActionBar` in an `if`. SwiftUI cannot reliably detect "empty content" inside
/// a @ViewBuilder, so this view does NOT attempt to hide itself when content is empty.
struct FloatingActionBar<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
    }
}
