import Testing
import Foundation
@testable import SonicMerge

struct EditListTests {

    private func makeEdit(_ text: String, _ start: TimeInterval, _ duration: TimeInterval, enabled: Bool = true) -> FillerEdit {
        FillerEdit(matchedText: text,
                   timeRange: start...(start + duration),
                   confidence: 0.9,
                   contextExcerpt: "ctx",
                   isEnabled: enabled)
    }

    @Test func testEnabledSavingsSumsOnlyEnabledRanges() {
        var list = EditList(
            fillers: [
                makeEdit("um", 0, 0.3, enabled: true),
                makeEdit("um", 5, 0.3, enabled: true),
                makeEdit("uh", 10, 0.4, enabled: false),
            ],
            pauses: [
                PauseEdit(timeRange: 20...22, isEnabled: true),
                PauseEdit(timeRange: 30...31.5, isEnabled: false),
            ]
        )
        // Enabled: 0.3 + 0.3 + 2 = 2.6
        #expect(abs(list.enabledSavings - 2.6) < 0.0001)
    }

    @Test func testToggleCategoryFlipsAllChildren() {
        var list = EditList(
            fillers: [
                makeEdit("um", 0, 0.3, enabled: true),
                makeEdit("um", 5, 0.3, enabled: true),
                makeEdit("uh", 10, 0.3, enabled: true),
            ],
            pauses: []
        )
        list.setCategory("um", enabled: false)
        #expect(list.fillers.filter { $0.matchedText == "um" }.allSatisfy { !$0.isEnabled })
        #expect(list.fillers.filter { $0.matchedText == "uh" }.allSatisfy { $0.isEnabled })
    }

    @Test func testToggleIndividualDoesNotChangeOthers() {
        var list = EditList(
            fillers: [
                makeEdit("um", 0, 0.3, enabled: true),
                makeEdit("um", 5, 0.3, enabled: true),
            ],
            pauses: []
        )
        list.setEdit(id: list.fillers[0].id, enabled: false)
        #expect(list.fillers[0].isEnabled == false)
        #expect(list.fillers[1].isEnabled == true)
    }

    @Test func testCategoryStateMixedWhenSomeEnabled() {
        let list = EditList(
            fillers: [
                makeEdit("um", 0, 0.3, enabled: true),
                makeEdit("um", 5, 0.3, enabled: false),
            ],
            pauses: []
        )
        #expect(list.categoryState(for: "um") == .mixed)
    }

    @Test func testCategoryStateOffWhenAllDisabled() {
        let list = EditList(
            fillers: [makeEdit("um", 0, 0.3, enabled: false)],
            pauses: []
        )
        #expect(list.categoryState(for: "um") == .off)
    }

    @Test func testCategoryStateOnWhenAllEnabled() {
        let list = EditList(
            fillers: [makeEdit("um", 0, 0.3, enabled: true)],
            pauses: []
        )
        #expect(list.categoryState(for: "um") == .on)
    }

    @Test func testCodableRoundTrip() throws {
        let original = EditList(
            fillers: [makeEdit("um", 0, 0.3)],
            pauses: [PauseEdit(timeRange: 10...12, isEnabled: true)]
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EditList.self, from: encoded)
        #expect(decoded == original)
    }

    @Test func testCategoriesPreservesInsertionOrderOfFirstOccurrence() {
        let list = EditList(
            fillers: [
                makeEdit("um", 0, 0.3),
                makeEdit("uh", 5, 0.3),
                makeEdit("um", 10, 0.3),
                makeEdit("like", 15, 0.3),
            ],
            pauses: []
        )
        #expect(list.categories == ["um", "uh", "like"])
    }
}
