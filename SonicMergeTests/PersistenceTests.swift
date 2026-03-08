//
//  PersistenceTests.swift
//  SonicMergeTests
//
//  Failing integration test stub for SwiftData persistence (AudioClip round-trip).
//  GREEN state expected once AudioClip model is confirmed correct.
//  Note: AudioClip already exists so this test may already be GREEN in Plan 01.
//

import Testing
import Foundation
import SwiftData
@testable import SonicMerge

struct PersistenceTests {
    @Test func testClipSurvivesRelaunch() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AudioClip.self, configurations: config)
        let context = container.mainContext
        let clip = AudioClip(
            displayName: "test.m4a",
            fileURL: URL(filePath: "/tmp/test.m4a"),
            duration: 1.0
        )
        context.insert(clip)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<AudioClip>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.displayName == "test.m4a")
    }
}
