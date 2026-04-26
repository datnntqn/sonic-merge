// SonicMergeTests/DesignSystem/SegmentedPillTests.swift
import Testing
import SwiftUI
@testable import SonicMerge

@MainActor
struct SegmentedPillTests {

    private enum TwoOption: Hashable, CaseIterable {
        case first, second
    }

    @Test func testBuildsWithTwoOptions() {
        let view = SegmentedPill<TwoOption>(
            selection: .constant(.first),
            label: { option in
                switch option {
                case .first:  return "First"
                case .second: return "Second"
                }
            }
        )
        // Smoke test — body must build without crashing.
        _ = view.body
    }

    @Test func testSelectionBindingIsReadable() {
        var captured: TwoOption = .first
        let binding = Binding<TwoOption>(
            get: { captured },
            set: { captured = $0 }
        )
        let view = SegmentedPill<TwoOption>(
            selection: binding,
            label: { _ in "" }
        )
        _ = view.body
        // Verify the binding wiring compiles — actual interaction is manual QA.
        #expect(captured == .first)
    }
}
