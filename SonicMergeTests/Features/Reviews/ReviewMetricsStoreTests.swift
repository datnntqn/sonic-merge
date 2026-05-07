import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct ReviewMetricsStoreTests {

    private func freshStore() -> ReviewMetricsStore {
        let suite = "ReviewMetricsStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return ReviewMetricsStore(defaults: defaults)
    }

    @Test func freshStoreHasZeroExports() {
        let store = freshStore()
        #expect(store.exportCount == 0)
    }

    @Test func incrementExportPersists() {
        let store = freshStore()
        store.incrementExportCount()
        store.incrementExportCount()
        store.incrementExportCount()
        #expect(store.exportCount == 3)
    }

    @Test func installDateInitializedOnFirstRead() {
        let store = freshStore()
        let now = Date()
        let installed = store.installDate
        #expect(abs(installed.timeIntervalSince(now)) < 5.0, "Install date should be ~now on first read")
    }

    @Test func installDatePersistsAfterFirstRead() {
        let suite = "ReviewMetricsStoreInstallDateTest-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store1 = ReviewMetricsStore(defaults: defaults)
        let date1 = store1.installDate
        let store2 = ReviewMetricsStore(defaults: defaults)
        #expect(store2.installDate == date1)
    }

    @Test func lastPromptDateNilByDefault() {
        let store = freshStore()
        #expect(store.lastPromptDate == nil)
    }

    @Test func setLastPromptDatePersists() {
        let store = freshStore()
        let now = Date()
        store.lastPromptDate = now
        #expect(store.lastPromptDate == now)
    }
}
