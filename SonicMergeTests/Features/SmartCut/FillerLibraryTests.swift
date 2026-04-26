import Testing
import Foundation
@testable import SonicMerge

struct FillerLibraryTests {

    /// Each test gets its own isolated UserDefaults suite so tests don't pollute each other.
    private func freshLibrary() -> (FillerLibrary, UserDefaults) {
        let suite = "FillerLibraryTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let library = FillerLibrary(defaults: defaults)
        return (library, defaults)
    }

    @Test func testDefaultOnSetMatchesSpec() {
        let (lib, _) = freshLibrary()
        #expect(lib.defaultOnWords == ["um", "uh", "ah", "er"])
    }

    @Test func testDefaultOffSetMatchesSpec() {
        let (lib, _) = freshLibrary()
        #expect(lib.defaultOffWords == ["like", "you know", "sort of", "basically", "actually", "literally"])
    }

    @Test func testAllWordsCombinesBothSets() {
        let (lib, _) = freshLibrary()
        let all = lib.allWords
        #expect(Set(all) == Set(lib.defaultOnWords + lib.defaultOffWords))
    }

    @Test func testAddingCustomWordPersists() {
        let (lib, _) = freshLibrary()
        var mutable = lib
        mutable.addCustom("anyway")
        #expect(mutable.allWords.contains("anyway"))
        // Re-load from same defaults — the change must persist.
        let reloaded = FillerLibrary(defaults: mutable.defaults)
        #expect(reloaded.allWords.contains("anyway"))
    }

    @Test func testAddingDuplicateIsNoOp() {
        let (lib, _) = freshLibrary()
        var mutable = lib
        mutable.addCustom("um")
        let counts = mutable.allWords.filter { $0 == "um" }.count
        #expect(counts == 1)
    }

    @Test func testRemovingDefaultWordPersists() {
        let (lib, _) = freshLibrary()
        var mutable = lib
        mutable.remove("like")
        #expect(!mutable.allWords.contains("like"))
        let reloaded = FillerLibrary(defaults: mutable.defaults)
        #expect(!reloaded.allWords.contains("like"))
    }

    @Test func testIsEnabledByDefault_OnSet() {
        let (lib, _) = freshLibrary()
        #expect(lib.isEnabledByDefault("um") == true)
    }

    @Test func testIsEnabledByDefault_OffSet() {
        let (lib, _) = freshLibrary()
        #expect(lib.isEnabledByDefault("like") == false)
    }

    @Test func testIsEnabledByDefault_CustomDefaultsOff() {
        let (lib, _) = freshLibrary()
        var mutable = lib
        mutable.addCustom("anyway")
        #expect(mutable.isEnabledByDefault("anyway") == false)
    }
}
