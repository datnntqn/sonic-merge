//
//  AppConstants.swift
//  SonicMerge
//
//  Created by DATNNT on 8/3/26.
//

import Foundation

/// Application-wide constants shared across the main app and future Share Extension target.
enum AppConstants {
    /// App Group identifier. Must match the entitlement added in Xcode
    /// Signing & Capabilities > App Groups for both the main target and any extensions.
    static let appGroupID = "group.com.yourteam.SonicMerge"

    /// Returns the URL for the shared clips directory inside the App Group container,
    /// creating it if it does not already exist.
    ///
    /// - Throws: `AppGroupError.containerNotFound` when running without the App Group
    ///   entitlement (e.g. unit tests in the default sandbox).
    static func clipsDirectory() throws -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            throw AppGroupError.containerNotFound
        }
        let dir = container.appending(path: "clips", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return dir
    }
}

/// Errors thrown by App Group container operations.
enum AppGroupError: Error, LocalizedError {
    /// The App Group container URL could not be resolved.
    ///
    /// Fix: add the App Group capability to the target in Xcode > Signing & Capabilities
    /// and ensure the identifier matches `AppConstants.appGroupID`.
    case containerNotFound

    var errorDescription: String? {
        switch self {
        case .containerNotFound:
            return "App Group container not found. Add the '\(AppConstants.appGroupID)' App Group entitlement to the target."
        }
    }
}
