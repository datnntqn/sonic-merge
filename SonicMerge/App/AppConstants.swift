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

    /// Creates `Library/Application Support` under the App Group container if missing.
    ///
    /// SwiftData stores `default.store` there. If the directory does not exist yet, Core Data
    /// logs `Failed to stat ... Application Support` and `Sandbox access to file-write-create denied`
    /// on Simulator before recovering — pre-creating the path avoids that noisy failure.
    static func prepareAppGroupPersistentStoreDirectory() {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return }
        let appSupport = container
            .appending(path: "Library", directoryHint: .isDirectory)
            .appending(path: "Application Support", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(
            at: appSupport,
            withIntermediateDirectories: true,
            attributes: nil
        )
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

    /// Returns the URL for the waveform sidecar file corresponding to a normalized clip.
    ///
    /// Sidecar file name: UUID stem of the clip filename + ".waveform"
    /// Example: "A1B2C3D4-....m4a" → "A1B2C3D4-....waveform"
    ///
    /// - Parameter clipFilename: The `fileURLRelativePath` value stored in AudioClip (filename only).
    /// - Throws: `AppGroupError.containerNotFound` when App Group container is inaccessible.
    static func waveformURL(forClipFilename clipFilename: String) throws -> URL {
        let stem = URL(fileURLWithPath: clipFilename).deletingPathExtension().lastPathComponent
        return try clipsDirectory().appending(path: stem + ".waveform")
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
