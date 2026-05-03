import Testing
import Foundation
import SwiftData
@testable import SonicMerge

@MainActor
struct DeepLinkReroutingTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([SmartCutSession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test func cloudSuffixIsStrippedAndMatches() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let session = SmartCutSession(
            name: "Episode",
            sourceFilename: "source.m4a",
            sourceHashHex: "abc123",
            durationSeconds: 60
        )
        context.insert(session)
        try context.save()

        let raw = "abc123#cloud"
        let bareHash = raw.split(separator: "#").first.map(String.init) ?? raw

        let descriptor = FetchDescriptor<SmartCutSession>(
            predicate: #Predicate { $0.sourceHashHex == bareHash }
        )
        let matched = try context.fetch(descriptor).first
        #expect(matched?.id == session.id)
    }

    @Test func localSuffixIsStrippedAndMatches() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = SmartCutSession(
            name: "Local",
            sourceFilename: "source.m4a",
            sourceHashHex: "deadbeef",
            durationSeconds: 30
        )
        context.insert(session)

        let bareHash = "deadbeef#local".split(separator: "#").first.map(String.init) ?? ""
        let descriptor = FetchDescriptor<SmartCutSession>(
            predicate: #Predicate { $0.sourceHashHex == bareHash }
        )
        #expect(try context.fetch(descriptor).first != nil)
    }

    @Test func unknownHashReturnsNoMatch() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(SmartCutSession(
            name: "X",
            sourceFilename: "source.m4a",
            sourceHashHex: "real",
            durationSeconds: 30
        ))

        let bareHash = "ghost#cloud".split(separator: "#").first.map(String.init) ?? ""
        let descriptor = FetchDescriptor<SmartCutSession>(
            predicate: #Predicate { $0.sourceHashHex == bareHash }
        )
        #expect(try context.fetch(descriptor).first == nil)
    }

    @Test func hashWithNoSuffixIsAccepted() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(SmartCutSession(
            name: "NoSuffix",
            sourceFilename: "source.m4a",
            sourceHashHex: "plainhash",
            durationSeconds: 30
        ))

        let raw = "plainhash"
        let bareHash = raw.split(separator: "#").first.map(String.init) ?? raw
        #expect(bareHash == "plainhash")
    }

    @Test func resolveSessionForHashClearsPendingHashAndResolvesMatch() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = SmartCutSession(
            name: "Episode",
            sourceFilename: "source.m4a",
            sourceHashHex: "abc",
            durationSeconds: 60
        )
        context.insert(session)

        PendingSmartCutOpen.shared.hash = "abc#cloud"
        let resolved = RootTabView.resolveSessionForPendingHash(in: context)
        #expect(resolved?.id == session.id)
        #expect(PendingSmartCutOpen.shared.hash == nil, "router must clear pending hash after read")
    }

    @Test func resolveSessionForHashClearsPendingHashEvenOnMiss() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(SmartCutSession(
            name: "Other",
            sourceFilename: "source.m4a",
            sourceHashHex: "real",
            durationSeconds: 30
        ))

        PendingSmartCutOpen.shared.hash = "ghost#local"
        let resolved = RootTabView.resolveSessionForPendingHash(in: context)
        #expect(resolved == nil)
        #expect(PendingSmartCutOpen.shared.hash == nil, "router must clear pending hash on miss too")
    }
}
