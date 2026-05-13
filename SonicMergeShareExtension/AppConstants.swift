// AppConstants.swift
// SonicMergeShareExtension
//
// Local copy of AppConstants for the Share Extension target.
// App Extensions are separate processes and cannot reference the main app target's types directly.
// Keep in sync with SonicMerge/App/AppConstants.swift.

import Foundation

enum AppConstants {
    /// App Group identifier. Must match the entitlement added in Xcode
    /// Signing & Capabilities > App Groups for both the main target and any extensions.
    static let appGroupID = "group.com.dtech.cleancut"

    /// Free-tier caps. Mirror of the main app's `AppConstants.FreeCap`.
    /// Extensions are separate processes and cannot import the main target,
    /// so values must be kept in sync with `SonicMerge/App/AppConstants.swift`.
    enum FreeCap {
        static let smartCutSessionsPerDay = 3
        static let denoiseSessionsPerDay = 3
        static let smartCutMaxSeconds: TimeInterval = 300  // 5:00
        static let denoiseMaxSeconds: TimeInterval = 180   // 3:00
        static let mergeMaxClips = 3
    }

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

    /// Mirror of the main app's `smartCutSessionDirectory(for:)`. Layout must
    /// match: `<AppGroup>/smart-cut/<id.uuidString>/`.
    static func smartCutSessionDirectory(for id: UUID) throws -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            throw AppGroupError.containerNotFound
        }
        let dir = container
            .appending(path: "smart-cut", directoryHint: .isDirectory)
            .appending(path: id.uuidString, directoryHint: .isDirectory)
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
    case containerNotFound

    var errorDescription: String? {
        switch self {
        case .containerNotFound:
            return "App Group container not found. Add the '\(AppConstants.appGroupID)' App Group entitlement to the target."
        }
    }
}
