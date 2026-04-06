// MixingStationClipIndexResolverTests.swift
// SonicMergeTests

import Foundation
import Testing
@testable import SonicMerge

struct MixingStationClipIndexResolverTests {

    @Test func findsIndex_byUUID() {
        let a = AudioClip(displayName: "A", fileURLRelativePath: "a.m4a", duration: 1)
        let b = AudioClip(displayName: "B", fileURLRelativePath: "b.m4a", duration: 2)
        let clips = [a, b]
        #expect(MixingStationClipIndexResolver.index(for: b.id, in: clips) == 1)
        #expect(MixingStationClipIndexResolver.index(for: UUID(), in: clips) == nil)
    }
}
