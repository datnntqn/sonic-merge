import Testing
import Foundation
import SwiftData
@testable import SonicMerge

@MainActor
struct SmartCutViewModelSessionInitTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([SmartCutSession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    /// Stages a real source file at the path the init will resolve. Uses the
    /// App Group path when entitled (production), sandbox-fallback otherwise.
    /// Returns the staged URL and a cleanup closure to remove the directory.
    private func stageSourceFile(for session: SmartCutSession) throws -> (url: URL, cleanup: () -> Void) {
        let dir: URL
        if let groupDir = try? AppConstants.smartCutSessionDirectory(for: session.id) {
            dir = groupDir
        } else {
            dir = FileManager.default.temporaryDirectory
                .appending(path: "smart-cut-fallback")
                .appending(path: session.id.uuidString)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let url = dir.appending(path: session.sourceFilename)
        try Data([0x00, 0x01, 0x02]).write(to: url)
        return (url, { try? FileManager.default.removeItem(at: dir) })
    }

    @Test func sessionInitWithMissingSourceLandsInError() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let session = SmartCutSession(
            name: "Missing",
            sourceFilename: "does-not-exist.m4a",
            sourceHashHex: "deadbeef",
            durationSeconds: 30
        )
        context.insert(session)

        let library = FillerLibrary(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
        let coordinator = PlaybackCoordinator()

        let vm = SmartCutViewModel(
            session: session,
            library: library,
            coordinator: coordinator,
            modelContext: context
        )

        if case .error(let message) = vm.state {
            #expect(message == "Source file missing")
        } else {
            Issue.record("Expected .error state, got \(vm.state)")
        }
    }

    @Test func sessionInitWithEmptyEditListLandsInIdle() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let session = SmartCutSession(
            name: "Empty",
            sourceFilename: "source.m4a",
            sourceHashHex: "deadbeef",
            durationSeconds: 30
        )
        context.insert(session)
        let staged = try stageSourceFile(for: session)
        defer { staged.cleanup() }

        let library = FillerLibrary(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
        let coordinator = PlaybackCoordinator()

        let vm = SmartCutViewModel(
            session: session,
            library: library,
            coordinator: coordinator,
            modelContext: context
        )

        #expect(vm.state == .idle)
        #expect(vm.editList.fillers.isEmpty)
        #expect(vm.editList.pauses.isEmpty)
    }

    @Test func sessionInitWithValidEditListJSONDecodesIntoVM() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let session = SmartCutSession(
            name: "WithEdits",
            sourceFilename: "source.m4a",
            sourceHashHex: "abc",
            durationSeconds: 30
        )
        let edits = EditList(
            fillers: [],
            pauses: [PauseEdit(timeRange: 1.0...2.5, isEnabled: true)]
        )
        session.editListJSON = try JSONEncoder().encode(edits)
        context.insert(session)
        let staged = try stageSourceFile(for: session)
        defer { staged.cleanup() }

        let library = FillerLibrary(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
        let coordinator = PlaybackCoordinator()

        let vm = SmartCutViewModel(
            session: session,
            library: library,
            coordinator: coordinator,
            modelContext: context
        )

        #expect(vm.editList == edits)
        // State stays .idle until the user re-analyzes — transcript-cache
        // resume is a follow-up.
        #expect(vm.state == .idle)
    }

    @Test func sessionInitWithCorruptEditListJSONClearsBlobAndLandsInIdle() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let session = SmartCutSession(
            name: "Corrupt",
            sourceFilename: "source.m4a",
            sourceHashHex: "abc",
            durationSeconds: 30
        )
        // Garbage bytes that JSONDecoder cannot parse as EditList.
        session.editListJSON = Data([0xFF, 0xFE, 0xFD])
        context.insert(session)
        let staged = try stageSourceFile(for: session)
        defer { staged.cleanup() }

        let library = FillerLibrary(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
        let coordinator = PlaybackCoordinator()

        let vm = SmartCutViewModel(
            session: session,
            library: library,
            coordinator: coordinator,
            modelContext: context
        )

        #expect(vm.state == .idle)
        #expect(session.editListJSON == nil, "corrupt blob should be cleared on decode failure")
    }
}
