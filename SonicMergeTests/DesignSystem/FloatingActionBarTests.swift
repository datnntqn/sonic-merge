import Testing
import SwiftUI
@testable import SonicMerge

@MainActor
struct FloatingActionBarTests {

    @Test func testBuildsWithButtonContent() {
        let view = FloatingActionBar {
            Button("Test") { }
                .buttonStyle(.borderless)
        }
        _ = view.body
    }

    @Test func testBuildsWithLabelContent() {
        let view = FloatingActionBar {
            Label("Apply", systemImage: "sparkles")
        }
        _ = view.body
    }
}
