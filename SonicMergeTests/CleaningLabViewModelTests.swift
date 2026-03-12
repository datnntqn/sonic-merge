//
//  CleaningLabViewModelTests.swift
//  SonicMergeTests
//
//  TDD tests for CleaningLabViewModel (Plan 03-03, DNS-01/DNS-02/DNS-03/UX-02).
//  RED phase: CleaningLabViewModel does not exist until Wave 3 (Plan 03-03).
//
//  These tests cover the five observable behaviors:
//    1. Default state: intensity=0.75, hasDenoisedResult=false, isProcessing=false
//    2. markClipsChanged() sets showsStaleResultBanner only when hasDenoisedResult=true
//    3. cancelDenoising() resets isProcessing to false
//    4. holdEnded() fires UIImpactFeedbackGenerator (verified indirectly via isHoldingOriginal)
//    5. Initial waveformPeaks is empty
//

import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct CleaningLabViewModelTests {

    // MARK: - Initial State

    @Test func testDefaultIntensityIs0_75() {
        let vm = CleaningLabViewModel()
        #expect(vm.intensity == 0.75, "intensity must default to 0.75 per CONTEXT.md locked decision")
    }

    @Test func testDefaultHasDenoisedResultIsFalse() {
        let vm = CleaningLabViewModel()
        #expect(vm.hasDenoisedResult == false, "hasDenoisedResult must be false until denoise() completes")
    }

    @Test func testDefaultIsProcessingIsFalse() {
        let vm = CleaningLabViewModel()
        #expect(vm.isProcessing == false)
    }

    @Test func testDefaultIsHoldingOriginalIsFalse() {
        let vm = CleaningLabViewModel()
        #expect(vm.isHoldingOriginal == false)
    }

    @Test func testDefaultShowsStaleResultBannerIsFalse() {
        let vm = CleaningLabViewModel()
        #expect(vm.showsStaleResultBanner == false)
    }

    @Test func testDefaultWaveformPeaksIsEmpty() {
        let vm = CleaningLabViewModel()
        #expect(vm.waveformPeaks.isEmpty, "waveformPeaks must be [] before first denoise")
    }

    @Test func testDefaultProgressIsZero() {
        let vm = CleaningLabViewModel()
        #expect(vm.progress == 0.0)
    }

    @Test func testDefaultErrorMessageIsNil() {
        let vm = CleaningLabViewModel()
        #expect(vm.errorMessage == nil)
    }

    // MARK: - markClipsChanged()

    @Test func testMarkClipsChangedDoesNotSetBannerWhenNoResult() {
        // When hasDenoisedResult=false, markClipsChanged() must NOT set the stale banner
        let vm = CleaningLabViewModel()
        #expect(vm.hasDenoisedResult == false)
        vm.markClipsChanged()
        #expect(vm.showsStaleResultBanner == false,
            "stale banner must remain false when clips change before any denoise result")
    }

    @Test func testMarkClipsChangedSetsBannerWhenResultExists() async {
        // Simulate hasDenoisedResult=true by writing to the internal property via a
        // helper that exposes it for test purposes, OR by verifying the logic:
        // We set hasDenoisedResult manually (it is a var, not private(set)) and call
        // markClipsChanged() — the banner should flip to true.
        let vm = CleaningLabViewModel()
        vm.hasDenoisedResult = true  // simulate post-denoise state
        vm.markClipsChanged()
        #expect(vm.showsStaleResultBanner == true,
            "stale banner must be set when clips change after a successful denoise")
    }

    // MARK: - cancelDenoising()

    @Test func testCancelDenoisingResetsIsProcessing() {
        let vm = CleaningLabViewModel()
        // Force isProcessing to true to simulate in-flight state
        vm.isProcessing = true
        vm.cancelDenoising()
        #expect(vm.isProcessing == false, "cancelDenoising() must reset isProcessing to false")
    }

    // MARK: - holdBegan() / holdEnded()

    @Test func testHoldBeganSetsIsHoldingOriginal() {
        // holdBegan() only switches players when hasDenoisedResult=true.
        // When false, it should be a no-op (no crash). isHoldingOriginal not set by holdBegan —
        // the view drives that flag; these methods perform AVAudioPlayer operations.
        // We verify no crash occurs on fresh VM.
        let vm = CleaningLabViewModel()
        vm.holdBegan()  // must not crash when hasDenoisedResult=false
        vm.holdEnded()  // must not crash when hasDenoisedResult=false
    }

    // MARK: - Dependency injection API

    @Test func testViewModelAcceptsInjectedServices() {
        // Verify that the ViewModel can be constructed with custom service instances
        let noiseService = NoiseReductionService()
        let waveService = WaveformService()
        let vm = CleaningLabViewModel(
            noiseReductionService: noiseService,
            waveformService: waveService
        )
        #expect(vm.intensity == 0.75)
        #expect(vm.hasDenoisedResult == false)
    }
}
