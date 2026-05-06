import Testing
import Foundation
import SwiftData
@testable import SonicMerge

@MainActor
struct MixingStationViewModelGatingTests {

    private func freshContext() throws -> ModelContext {
        let schema = Schema([AudioClip.self, GapTransition.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func freshService() -> EntitlementService {
        let suite = "MixingStationGatingTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let tracker = DailyUsageTracker(
            defaults: defaults,
            calendar: Calendar(identifier: .gregorian),
            dateProvider: { Date(timeIntervalSince1970: 1714824000) }
        )
        return EntitlementService(usageTracker: tracker)
    }

    @Test func freeUserUnderCapPassesGate() throws {
        let svc = freshService()
        let vm = MixingStationViewModel(modelContext: try freshContext(), entitlements: svc)
        // Importing 3 fake files when clips is empty: total projected = 3.
        // freeMergeMaxClips = 3, so 3 ≤ 3 = allowed. Method may still fail
        // for *file-system* reasons — that's fine; we only check the gate.
        let urls = [URL(fileURLWithPath: "/tmp/a.m4a"),
                    URL(fileURLWithPath: "/tmp/b.m4a"),
                    URL(fileURLWithPath: "/tmp/c.m4a")]
        let result = vm.importFiles(urls)
        // Either nil (gate passed, file-system error doesn't propagate) or
        // a non-paywall failure surfaced via `importErrors`.
        #expect(result == nil)
    }

    @Test func freeUserExceedsClipCountCap() throws {
        let svc = freshService()
        let vm = MixingStationViewModel(modelContext: try freshContext(), entitlements: svc)
        let urls = (0..<5).map { URL(fileURLWithPath: "/tmp/\($0).m4a") }
        let result = vm.importFiles(urls)
        #expect(result == .hitLengthCap)
        // Sanity: nothing got imported because we reject the whole batch.
        #expect(vm.clips.isEmpty)
    }

    @Test func proUserBypassesClipCountCap() throws {
        let svc = freshService()
        svc.setEntitlement(.lifetime)
        let vm = MixingStationViewModel(modelContext: try freshContext(), entitlements: svc)
        let urls = (0..<10).map { URL(fileURLWithPath: "/tmp/\($0).m4a") }
        let result = vm.importFiles(urls)
        #expect(result == nil)
    }
}
