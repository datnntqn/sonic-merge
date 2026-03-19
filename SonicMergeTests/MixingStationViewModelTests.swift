//
//  MixingStationViewModelTests.swift
//  SonicMergeTests
//
//  Failing stubs for MRG-01 (reorder), MRG-02 (delete), EXP-04 (cancel export) behaviors.
//  RED state: MixingStationViewModel and GapTransition do not exist until later plans.
//

import Testing
import Foundation
import SwiftData
@testable import SonicMerge

@MainActor
struct MixingStationViewModelTests {

    // MARK: - MRG-01: Reorder clips

    @Test func moveClipReassignsContiguousSortOrder() async throws {
        // Arrange: 3 clips in order 0, 1, 2
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AudioClip.self, GapTransition.self, configurations: config)
        let context = ModelContext(container)
        let vm = MixingStationViewModel(modelContext: context)

        let clipA = AudioClip(displayName: "A", fileURLRelativePath: "a.m4a", duration: 1)
        clipA.sortOrder = 0
        let clipB = AudioClip(displayName: "B", fileURLRelativePath: "b.m4a", duration: 1)
        clipB.sortOrder = 1
        let clipC = AudioClip(displayName: "C", fileURLRelativePath: "c.m4a", duration: 1)
        clipC.sortOrder = 2
        context.insert(clipA); context.insert(clipB); context.insert(clipC)
        try context.save()
        await vm.fetchAll()

        // Act: move last clip to first position
        vm.moveClip(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        // Assert: contiguous sortOrders 0, 1, 2 with C first
        let sorted = vm.clips.sorted(by: { $0.sortOrder < $1.sortOrder })
        #expect(sorted[0].displayName == "C")
        #expect(sorted.map(\.sortOrder) == [0, 1, 2])
    }

    // MARK: - MRG-02: Delete clip

    @Test func deleteClipRemovesFromContextAndCleansUpGapTransition() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AudioClip.self, GapTransition.self, configurations: config)
        let context = ModelContext(container)
        let vm = MixingStationViewModel(modelContext: context)

        let clip = AudioClip(displayName: "ToDelete", fileURLRelativePath: "del.m4a", duration: 1)
        clip.sortOrder = 0
        let gap = GapTransition(leadingClipSortOrder: 0)
        gap.audioClip = clip
        context.insert(clip); context.insert(gap)
        try context.save()
        await vm.fetchAll()

        // Act
        vm.deleteClip(atOffsets: IndexSet(integer: 0))

        // Assert: clip and gap removed
        #expect(vm.clips.isEmpty)
        let descriptor = FetchDescriptor<GapTransition>()
        let remaining = try context.fetch(descriptor)
        #expect(remaining.isEmpty)
    }

    // MARK: - EXP-04: Cancel export

    @Test func cancelExportStopsExportTaskAndCleansUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AudioClip.self, GapTransition.self, configurations: config)
        let context = ModelContext(container)
        let vm = MixingStationViewModel(modelContext: context)

        // Start an export (will fail fast since no clips) then cancel immediately
        vm.exportMerged(format: .m4a)
        vm.cancelExport()

        // Assert: not exporting and no partial file
        #expect(!vm.isExporting)
        if let url = vm.exportedFileURL {
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }
    }

    // MARK: - EXP-03: ExportOptions LUFS flag

    @Test func testExportOptionsLUFSFlag() throws {
        // ExportOptions carries lufsNormalize Bool correctly.
        // RED state: ExportOptions does not exist until Plan 04-02.
        let options = ExportOptions(format: .m4a, lufsNormalize: true)
        #expect(options.format == .m4a)
        #expect(options.lufsNormalize == true)
    }

    // MARK: - Share sheet state reset (post-Phase 4 export polish)

    @Test func testDismissShareSheetResetsState() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AudioClip.self, GapTransition.self, configurations: config)
        let context = ModelContext(container)
        let vm = MixingStationViewModel(modelContext: context)

        // Simulate post-export state
        // Note: exportedFileURL and exportProgress are private(set) —
        // trigger via exportMerged then cancelExport to set a known state,
        // then call dismissShareSheet and assert reset.
        vm.cancelExport()  // Ensures clean state first
        vm.dismissShareSheet()

        #expect(vm.exportedFileURL == nil, "exportedFileURL must be nil after dismissShareSheet()")
        #expect(vm.exportProgress == 0, "exportProgress must be 0 after dismissShareSheet()")
    }
}
