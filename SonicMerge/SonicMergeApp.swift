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
        let config = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(AppConstants.appGroupID)
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Fatal: if the SwiftData store cannot be created, the app cannot function.
            // Most common cause: App Group entitlement missing from the target.
            // Fix: Xcode > target > Signing & Capabilities > App Groups >
            //      add "group.com.yourteam.SonicMerge"
            fatalError("Failed to create ModelContainer: \(error). Check App Group entitlement.")
        }
    }()

    init() {
        configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            // ContentView is a placeholder. ImportView (Plan 04) replaces this.
            ContentView()
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
