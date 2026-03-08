//
//  SonicMergeApp.swift
//  SonicMerge
//
//  Created by DATNNT on 8/3/26.
//

import SwiftUI
import SwiftData
import AVFAudio

@main
struct SonicMergeApp: App {

    /// SwiftData ModelContainer configured with the App Group shared container.
    ///
    /// The App Group entitlement must be added in Xcode > target > Signing & Capabilities
    /// > App Groups > "group.com.yourteam.SonicMerge" before this works on a real device
    /// or in a simulator with entitlements. Without the entitlement, `containerURL(...)` returns
    /// nil and ModelConfiguration falls back to the app sandbox — which is acceptable during
    /// development but will not be shared with the future Share Extension target.
    let modelContainer: ModelContainer = {
        let schema = Schema([AudioClip.self])
        // Use App Group container when entitlement is available; fall back to the default
        // sandbox container when not (e.g., unit test host process or simulator without
        // App Group capability configured). The Share Extension (Phase 5) requires the
        // App Group container on device.
        //
        // Note: We check whether the App Group container URL resolves BEFORE creating
        // ModelConfiguration with groupContainer — ModelConfiguration asserts internally
        // if the group identifier cannot be resolved in the current sandbox.
        let useAppGroup = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID) != nil

        if useAppGroup {
            let config = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(AppConstants.appGroupID)
            )
            if let container = try? ModelContainer(for: schema, configurations: config) {
                return container
            }
        }

        // Fallback: default sandbox container (no App Group sharing)
        let fallbackConfig = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: fallbackConfig)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    init() {
        configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ImportView()
                .environment(ImportViewModel(modelContext: modelContainer.mainContext))
        }
        .modelContainer(modelContainer)
    }

    /// Activates AVAudioSession with `.playback` category at launch.
    ///
    /// - Category `.playback`: the app imports pre-recorded files and does not record live audio.
    /// - Option `.mixWithOthers`: background music continues while the app is in use.
    /// - Activation at launch avoids an audio "pop" when the session starts mid-import.
    ///
    /// Failure is non-fatal: normalization via AVAssetWriter writes to disk without an active
    /// audio session. Phase 2 (playback) retries activation before the first playback attempt.
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[SonicMergeApp] AVAudioSession configuration failed: \(error)")
        }
    }
}
