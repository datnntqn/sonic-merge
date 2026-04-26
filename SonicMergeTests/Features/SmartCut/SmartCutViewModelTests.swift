import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct SmartCutViewModelTests {

    @Test func testInitialStateIsIdle() {
        let vm = SmartCutViewModel(coordinator: PlaybackCoordinator(),
                                   library: FillerLibrary(defaults: UserDefaults(suiteName: "vm-\(UUID())")!))
        #expect(vm.state == .idle)
    }

    @Test func testInvalidateResetsResultsToIdle() {
        let vm = SmartCutViewModel(coordinator: PlaybackCoordinator(),
                                   library: FillerLibrary(defaults: UserDefaults(suiteName: "vm-\(UUID())")!))
        vm._injectResultsForTesting(EditList(fillers: [], pauses: []))
        #expect(vm.state == .results)
        vm.invalidate()
        #expect(vm.state == .idle)
        #expect(vm.editList.fillers.isEmpty)
    }

    @Test func testStaleStateAppliedWhenInvalidatedFromResults() {
        let vm = SmartCutViewModel(coordinator: PlaybackCoordinator(),
                                   library: FillerLibrary(defaults: UserDefaults(suiteName: "vm-\(UUID())")!))
        vm._injectResultsForTesting(EditList(fillers: [], pauses: []))
        vm.markDenoiseChanged()
        #expect(vm.state == .stale)
    }

    @Test func testReanalyzeFromStaleClearsAndReturnsToIdle() {
        let vm = SmartCutViewModel(coordinator: PlaybackCoordinator(),
                                   library: FillerLibrary(defaults: UserDefaults(suiteName: "vm-\(UUID())")!))
        vm._injectResultsForTesting(EditList(fillers: [], pauses: []))
        vm.markDenoiseChanged()
        vm.requestReanalyze()
        #expect(vm.state == .idle)
    }

    @Test func testCategoryToggleUpdatesEditListAndSavings() {
        let vm = SmartCutViewModel(coordinator: PlaybackCoordinator(),
                                   library: FillerLibrary(defaults: UserDefaults(suiteName: "vm-\(UUID())")!))
        let edit = FillerEdit(matchedText: "um",
                              timeRange: 1...1.5,
                              confidence: 0.9,
                              contextExcerpt: "ctx",
                              isEnabled: true)
        vm._injectResultsForTesting(EditList(fillers: [edit], pauses: []))
        #expect(vm.editList.enabledSavings == 0.5)
        vm.setCategory("um", enabled: false)
        #expect(vm.editList.enabledSavings == 0)
    }

    @Test func testHasDirtyEditsSinceApplyFalseInitially() {
        let vm = SmartCutViewModel(coordinator: PlaybackCoordinator(),
                                   library: FillerLibrary(defaults: UserDefaults(suiteName: "vm-\(UUID())")!))
        let edit = FillerEdit(matchedText: "um", timeRange: 1...1.5, confidence: 0.9,
                              contextExcerpt: "ctx", isEnabled: true)
        vm._injectResultsForTesting(EditList(fillers: [edit], pauses: []))
        #expect(vm.hasDirtyEditsSinceApply == false)
    }

    @Test func testHasDirtyEditsSinceApplyTrueAfterToggleFollowingApply() {
        let vm = SmartCutViewModel(coordinator: PlaybackCoordinator(),
                                   library: FillerLibrary(defaults: UserDefaults(suiteName: "vm-\(UUID())")!))
        let edit = FillerEdit(matchedText: "um", timeRange: 1...1.5, confidence: 0.9,
                              contextExcerpt: "ctx", isEnabled: true)
        vm._injectResultsForTesting(EditList(fillers: [edit], pauses: []))
        vm._injectAppliedSnapshotForTesting(vm.editList)
        #expect(vm.hasDirtyEditsSinceApply == false)
        vm.setCategory("um", enabled: false)
        #expect(vm.hasDirtyEditsSinceApply == true)
    }
}
