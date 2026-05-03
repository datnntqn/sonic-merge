import Testing
import Foundation
import SwiftData
@testable import SonicMerge

@MainActor
struct DenoiseSessionViewModelInitTests {

    /// Stages a real source file at the path the init will resolve. Uses the
    /// App Group path when entitled (production), sandbox-fallback otherwise.
    private func stageSourceFile(for session: DenoiseSession) throws -> (url: URL, cleanup: () -> Void) {
        let dir: URL
        if let groupDir = try? AppConstants.denoiseSessionDirectory(for: session.id) {
            dir = groupDir
        } else {
            dir = FileManager.default.temporaryDirectory
                .appending(path: "denoise-fallback")
                .appending(path: session.id.uuidString)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let url = dir.appending(path: session.sourceFilename)
        try Data([0x00, 0x01, 0x02]).write(to: url)
        return (url, { try? FileManager.default.removeItem(at: dir) })
    }

    @Test func sessionInitRestoresIntensityAndExposesSourceAsMergedFileURL() throws {
        let schema = Schema([DenoiseSession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = container.mainContext

        let session = DenoiseSession(
            name: "Lecture",
            sourceFilename: "source.wav",
            durationSeconds: 60,
            intensity: 0.62
        )
        context.insert(session)
        let staged = try stageSourceFile(for: session)
        defer { staged.cleanup() }

        let vm = DenoiseSessionViewModel(session: session, modelContext: context)

        #expect(abs(vm.intensity - 0.62) < 0.0001)
        #expect(vm.mergedFileURL?.lastPathComponent == "source.wav")
    }

    @Test func sessionInitWithMissingSourceSetsErrorMessage() throws {
        let schema = Schema([DenoiseSession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = container.mainContext

        let session = DenoiseSession(
            name: "Missing",
            sourceFilename: "nope.wav",
            durationSeconds: 60,
            intensity: 0.5
        )
        context.insert(session)

        let vm = DenoiseSessionViewModel(session: session, modelContext: context)

        #expect(vm.errorMessage == "Source file missing")
        #expect(vm.mergedFileURL == nil)
    }
}
