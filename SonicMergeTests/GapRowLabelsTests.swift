// GapRowLabelsTests.swift
// SonicMergeTests

import Testing
@testable import SonicMerge

struct GapRowLabelsTests {

    @Test func pickerAccessibilityLabel_isStable() {
        #expect(GapRowAccessibility.label == "Transition between clips")
    }
}
