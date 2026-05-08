// SonicMergeTests/Features/Recording/AudioRecorderServiceTests.swift
import Testing
import Foundation
@testable import SonicMerge

@MainActor
struct AudioRecorderServiceTests {

    private struct StubPermissions: RecordPermissionProvider {
        let granted: Bool
        func request() async -> Bool { granted }
    }

    @Test func startThrowsWhenPermissionDenied() async {
        let svc = AudioRecorderService(permissions: StubPermissions(granted: false))
        await #expect(throws: AudioRecorderService.RecorderError.micPermissionDenied) {
            try await svc.start()
        }
    }
}
