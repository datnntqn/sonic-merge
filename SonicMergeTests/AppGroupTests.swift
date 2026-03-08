//
//  AppGroupTests.swift
//  SonicMergeTests
//
//  Failing unit test stub for App Group container URL resolution.
//  Disabled: App Group entitlement not available in unit test sandbox.
//  Manual step: run on device after App Group entitlement is configured in
//  Xcode > target > Signing & Capabilities > App Groups.
//

import Testing
import Foundation
@testable import SonicMerge

struct AppGroupTests {
    // Disabled: App Group entitlement not available in unit test sandbox.
    // This test serves as a manual checklist item. Run on device after
    // App Group entitlement is configured in Xcode Signing & Capabilities.
    @Test(.disabled("App Group entitlement not available in unit test sandbox"))
    func testContainerURLNotNil() {
        let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
        )
        #expect(url != nil)
    }
}
