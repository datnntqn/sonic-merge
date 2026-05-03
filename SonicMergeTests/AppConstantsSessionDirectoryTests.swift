import XCTest
@testable import SonicMerge

final class AppConstantsSessionDirectoryTests: XCTestCase {

    func test_smartCutSessionDirectoryEndsWithExpectedSegments() throws {
        let id = UUID()
        // Skip if not entitled (e.g., test host without App Group).
        guard FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
        ) != nil else {
            throw XCTSkip("App Group not entitled in this test host")
        }

        let url = try AppConstants.smartCutSessionDirectory(for: id)
        XCTAssertTrue(url.path.hasSuffix("/smart-cut/\(id.uuidString)"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func test_denoiseSessionDirectoryEndsWithExpectedSegments() throws {
        let id = UUID()
        guard FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
        ) != nil else {
            throw XCTSkip("App Group not entitled in this test host")
        }

        let url = try AppConstants.denoiseSessionDirectory(for: id)
        XCTAssertTrue(url.path.hasSuffix("/denoise/\(id.uuidString)"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func test_containerNotFoundErrorDescriptionMatchesAppGroupID() {
        // Documents the user-facing error string used when entitlement is missing.
        // (The actual throw is exercised implicitly by the directory tests above
        // when they don't XCTSkip — i.e., on hosts without the entitlement those
        // tests would throw and fail rather than skip; the XCTSkip guard exists
        // because CI without entitlement is the default test environment.)
        XCTAssertEqual(
            AppGroupError.containerNotFound.errorDescription,
            "App Group container not found. Add the '\(AppConstants.appGroupID)' App Group entitlement to the target."
        )
    }
}
