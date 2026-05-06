import Testing
import Foundation
import SwiftData
@testable import SonicMerge

@MainActor
struct SmartCutViewModelPersistTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([SmartCutSession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test func persistWritesEditListJSONAndUpdatesLastOpenedAt() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let session = SmartCutSession(
            name: "Test",
            sourceFilename: "source.m4a",
            sourceHashHex: "abc",
            durationSeconds: 30
        )
        context.insert(session)
        try context.save()

        let library = FillerLibrary(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
        let coordinator = PlaybackCoordinator()
        let vm = SmartCutViewModel(coordinator: coordinator, library: library, entitlements: EntitlementService())

        // Inject a non-trivial editList via the existing test seam.
        let edits = EditList(
            fillers: [],
            pauses: [PauseEdit(timeRange: 1.0...2.5, isEnabled: true)]
        )
        vm._injectResultsForTesting(edits)

        let beforeOpenedAt = session.lastOpenedAt
        // Sleep so .now != beforeOpenedAt at observable resolution.
        Thread.sleep(forTimeInterval: 0.05)

        vm.persist(to: session)
        try context.save()

        #expect(session.editListJSON != nil)
        let decoded = try JSONDecoder().decode(EditList.self, from: #require(session.editListJSON))
        #expect(decoded == edits)
        #expect(session.lastOpenedAt > beforeOpenedAt)
    }

    @Test func persistWritesNilEditListJSONWhenEditListIsEmpty() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let session = SmartCutSession(
            name: "Test",
            sourceFilename: "source.m4a",
            sourceHashHex: "abc",
            durationSeconds: 30
        )
        context.insert(session)

        let library = FillerLibrary(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
        let coordinator = PlaybackCoordinator()
        let vm = SmartCutViewModel(coordinator: coordinator, library: library, entitlements: EntitlementService())
        // VM starts with empty editList — persist should write nil, not an
        // empty-list blob, so resume cleanly lands in .idle.
        vm.persist(to: session)

        #expect(session.editListJSON == nil)
    }
}
