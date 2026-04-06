// TrustSignalCopyTests.swift
// SonicMergeTests

import Testing
@testable import SonicMerge

struct TrustSignalCopyTests {

    @Test func localFirstStripTitle_isStableCopy() {
        #expect(TrustSignalCopy.localFirstTitle == "Private by design")
    }

    @Test func localFirstStripSubtitle_mentionsOnDevice() {
        #expect(TrustSignalCopy.localFirstSubtitle.lowercased().contains("on-device"))
        #expect(TrustSignalCopy.localFirstSubtitle.lowercased().contains("cloud") == false)
    }
}
