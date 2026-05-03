import XCTest
import SwiftData
@testable import SonicMerge

@MainActor
final class SessionModelPersistenceTests: XCTestCase {

    func test_smartCutSessionRoundTripsThroughInMemoryModelContainer() throws {
        let schema = Schema([SmartCutSession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = container.mainContext

        let id = UUID()
        let session = SmartCutSession(
            id: id,
            name: "Episode 14",
            sourceFilename: "source.m4a",
            sourceHashHex: "abc123",
            durationSeconds: 2520
        )
        context.insert(session)
        try context.save()

        let descriptor = FetchDescriptor<SmartCutSession>(
            predicate: #Predicate { $0.id == id }
        )
        let fetched = try context.fetch(descriptor).first
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "Episode 14")
        XCTAssertEqual(fetched?.sourceFilename, "source.m4a")
        XCTAssertEqual(fetched?.sourceHashHex, "abc123")
        XCTAssertEqual(fetched?.durationSeconds, 2520)
        XCTAssertNil(fetched?.editListJSON)
        XCTAssertNil(fetched?.transcriptCacheRef)
    }

    func test_editListJSONRoundTripsAsCodableBlob() throws {
        let schema = Schema([SmartCutSession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = container.mainContext

        let edits = EditList(
            fillers: [],
            pauses: [PauseEdit(timeRange: 1.0...2.5, isEnabled: true)]
        )
        let json = try JSONEncoder().encode(edits)

        let session = SmartCutSession(
            id: UUID(),
            name: "Test",
            sourceFilename: "source.m4a",
            sourceHashHex: "deadbeef",
            durationSeconds: 60
        )
        session.editListJSON = json
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SmartCutSession>()).first
        XCTAssertNotNil(fetched?.editListJSON)
        let decoded = try JSONDecoder().decode(EditList.self, from: fetched!.editListJSON!)
        XCTAssertEqual(decoded, edits)
    }

    func test_denoiseSessionRoundTripsThroughInMemoryModelContainer() throws {
        let schema = Schema([DenoiseSession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = container.mainContext

        let id = UUID()
        let session = DenoiseSession(
            id: id,
            name: "Lecture",
            sourceFilename: "source.wav",
            durationSeconds: 1800,
            intensity: 0.5
        )
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(
            FetchDescriptor<DenoiseSession>(predicate: #Predicate { $0.id == id })
        ).first
        XCTAssertEqual(fetched?.name, "Lecture")
        XCTAssertEqual(fetched?.intensity, 0.5)
        XCTAssertNil(fetched?.processedFilename)
    }
}
