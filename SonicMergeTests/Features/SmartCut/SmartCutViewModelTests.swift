import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct SmartCutViewModelTests {

    @Test func testInitialStateIsIdle() {
        let vm = SmartCutViewModel(coordinator: PlaybackCoordinator(),
                                   library: FillerLibrary(defaults: UserDefaults(suiteName: "vm-\(UUID())")!),
                                   entitlements: EntitlementService())
        #expect(vm.state == .idle)
    }

    @Test func testInvalidateResetsResultsToIdle() {
        let vm = SmartCutViewModel(coordinator: PlaybackCoordinator(),
                                   library: FillerLibrary(defaults: UserDefaults(suiteName: "vm-\(UUID())")!),
                                   entitlements: EntitlementService())
        vm._injectResultsForTesting(EditList(fillers: [], pauses: []))
        #expect(vm.state == .results)
        vm.invalidate()
        #expect(vm.state == .idle)
        #expect(vm.editList.fillers.isEmpty)
    }

    @Test func testStaleStateAppliedWhenInvalidatedFromResults() {
        let vm = SmartCutViewModel(coordinator: PlaybackCoordinator(),
                                   library: FillerLibrary(defaults: UserDefaults(suiteName: "vm-\(UUID())")!),
                                   entitlements: EntitlementService())
        vm._injectResultsForTesting(EditList(fillers: [], pauses: []))
        vm.markDenoiseChanged()
        #expect(vm.state == .stale)
    }

    @Test func testReanalyzeFromStaleClearsAndReturnsToIdle() {
        let vm = SmartCutViewModel(coordinator: PlaybackCoordinator(),
                                   library: FillerLibrary(defaults: UserDefaults(suiteName: "vm-\(UUID())")!),
                                   entitlements: EntitlementService())
        vm._injectResultsForTesting(EditList(fillers: [], pauses: []))
        vm.markDenoiseChanged()
        vm.requestReanalyze()
        #expect(vm.state == .idle)
    }

    @Test func testCategoryToggleUpdatesEditListAndSavings() {
        let vm = SmartCutViewModel(coordinator: PlaybackCoordinator(),
                                   library: FillerLibrary(defaults: UserDefaults(suiteName: "vm-\(UUID())")!),
                                   entitlements: EntitlementService())
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
                                   library: FillerLibrary(defaults: UserDefaults(suiteName: "vm-\(UUID())")!),
                                   entitlements: EntitlementService())
        let edit = FillerEdit(matchedText: "um", timeRange: 1...1.5, confidence: 0.9,
                              contextExcerpt: "ctx", isEnabled: true)
        vm._injectResultsForTesting(EditList(fillers: [edit], pauses: []))
        #expect(vm.hasDirtyEditsSinceApply == false)
    }

    @Test func testHasDirtyEditsSinceApplyTrueAfterToggleFollowingApply() {
        let vm = SmartCutViewModel(coordinator: PlaybackCoordinator(),
                                   library: FillerLibrary(defaults: UserDefaults(suiteName: "vm-\(UUID())")!),
                                   entitlements: EntitlementService())
        let edit = FillerEdit(matchedText: "um", timeRange: 1...1.5, confidence: 0.9,
                              contextExcerpt: "ctx", isEnabled: true)
        vm._injectResultsForTesting(EditList(fillers: [edit], pauses: []))
        vm._injectAppliedSnapshotForTesting(vm.editList)
        #expect(vm.hasDirtyEditsSinceApply == false)
        vm.setCategory("um", enabled: false)
        #expect(vm.hasDirtyEditsSinceApply == true)
    }
}

@Suite("SmartCutViewModel.setPauseThreshold")
@MainActor
struct SmartCutViewModelSetPauseThresholdTests {

    private func makeVM() -> SmartCutViewModel {
        let coordinator = PlaybackCoordinator()
        let library = FillerLibrary(defaults: UserDefaults(suiteName: "TestSuite-\(UUID())")!)
        let vm = SmartCutViewModel(coordinator: coordinator, library: library, entitlements: EntitlementService())
        let segments: [TranscriptionState.RecognizedSegment] = [
            .init(text: "hello", startTime: 1.5, endTime: 4.0, confidence: 0.9),
            .init(text: "world", startTime: 6.0, endTime: 9.0, confidence: 0.9)
        ]
        vm._injectCachedTranscriptionForTesting(segments: segments, duration: 10.0)
        return vm
    }

    @Test("Returns no-op when cached segments are empty (per spec: full no-op, including threshold)")
    func setPauseThreshold_noCache_isNoop() {
        let coordinator = PlaybackCoordinator()
        let library = FillerLibrary(defaults: UserDefaults(suiteName: "TestSuite-\(UUID())")!)
        let vm = SmartCutViewModel(coordinator: coordinator, library: library, entitlements: EntitlementService())
        let priorPauses = vm.editList.pauses
        let priorThreshold = vm.pauseThreshold
        vm.setPauseThreshold(2.5)
        #expect(vm.editList.pauses == priorPauses)
        #expect(vm.pauseThreshold == priorThreshold)
    }

    @Test("Updates pauseThreshold and rebuilds editList.pauses from cached segments")
    func setPauseThreshold_rebuildsPauses() {
        let vm = makeVM()
        vm.setPauseThreshold(1.5)
        #expect(vm.pauseThreshold == 1.5)
        #expect(vm.editList.pauses.count == 1)
        #expect(vm.editList.pauses.first?.timeRange == 4.0...6.0)
    }

    @Test("Rebuild detects more pauses when threshold lowers")
    func setPauseThreshold_lowerThresholdDetectsMore() {
        let vm = makeVM()
        vm.setPauseThreshold(1.5)  // 1 pause: 4.0...6.0
        vm.setPauseThreshold(1.0)  // Now leading 1.5s silence ALSO detected -> 2 pauses
        #expect(vm.editList.pauses.count == 2)
    }

    @Test("Preserves user's isEnabled flags on surviving pauses across recompute")
    func setPauseThreshold_preservesUserToggles() {
        let vm = makeVM()
        vm.setPauseThreshold(1.5)
        vm.setEdit(id: vm.editList.pauses[0].id, enabled: false)
        #expect(vm.editList.pauses[0].isEnabled == false)
        vm.setPauseThreshold(1.7)
        #expect(vm.editList.pauses.count == 1)
        #expect(vm.editList.pauses.first?.timeRange == 4.0...6.0)
        #expect(vm.editList.pauses.first?.isEnabled == false)
    }
}
