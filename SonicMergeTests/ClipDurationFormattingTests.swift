// ClipDurationFormattingTests.swift
// SonicMergeTests

import Testing
@testable import SonicMerge

struct ClipDurationFormattingTests {

    @Test func formatsMMSS() {
        #expect(ClipDurationFormatting.mmss(from: 74) == "1:14")
    }
}
