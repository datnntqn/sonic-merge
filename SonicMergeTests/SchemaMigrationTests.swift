import XCTest
import SwiftData
@testable import SonicMerge

@MainActor
final class SchemaMigrationTests: XCTestCase {

    func test_expandedSchemaSupportsAllFourEntityTypes() throws {
        let schema = Schema([
            AudioClip.self,
            GapTransition.self,
            SmartCutSession.self,
            DenoiseSession.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = container.mainContext

        // AudioClip insert (existing entity, must still load cleanly).
        let clip = AudioClip(
            displayName: "test.m4a",
            fileURLRelativePath: "test.m4a",
            duration: 30
        )
        context.insert(clip)

        // SmartCutSession insert.
        let smartCut = SmartCutSession(
            name: "smartcut",
            sourceFilename: "source.m4a",
            sourceHashHex: "abc",
            durationSeconds: 60
        )
        context.insert(smartCut)

        // DenoiseSession insert.
        let denoise = DenoiseSession(
            name: "denoise",
            sourceFilename: "source.wav",
            durationSeconds: 60
        )
        context.insert(denoise)

        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<AudioClip>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SmartCutSession>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DenoiseSession>()).count, 1)
    }
}
