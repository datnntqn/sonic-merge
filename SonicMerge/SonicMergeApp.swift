//
//  SonicMergeApp.swift
//  SonicMerge
//
//  Created by DATNNT on 8/3/26.
//

import SwiftUI
import SwiftData

@main
struct SonicMergeApp: App {

    @UIApplicationDelegateAdaptor(SmartCutAppDelegate.self) private var smartCutAppDelegate
    @AppStorage("sonicMergeThemePreference") private var themePreferenceRaw: String = ThemePreference.light.rawValue

    /// SwiftData ModelContainer configured with the App Group shared container.
    ///
    /// The App Group entitlement must be added in Xcode > target > Signing & Capabilities
    /// > App Groups > "group.com.dtech.cleancut" before this works on a real device
    /// or in a simulator with entitlements. Without the entitlement, `containerURL(...)` returns
    /// nil and ModelConfiguration falls back to the app sandbox — which is acceptable during
    /// development but will not be shared with the future Share Extension target.
    let modelContainer: ModelContainer = {
        AppConstants.prepareAppGroupPersistentStoreDirectory()
        let schema = Schema([
            AudioClip.self,
            GapTransition.self,
            SmartCutSession.self,
            DenoiseSession.self
        ])
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

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .onAppear {
                    if let migrated = Self.migrateLegacyTheme(themePreferenceRaw) {
                        themePreferenceRaw = migrated
                    }
                }
        }
        .modelContainer(modelContainer)
    }

    // MARK: - Theme migration (binary toggle, drops .system)

    /// Returns the new raw value to write back to `@AppStorage("sonicMergeThemePreference")`,
    /// or `nil` if the stored value already matches a valid binary state. Pure — easily testable.
    ///
    /// Legacy `"system"` and any unrecognized raw both normalize to `"light"` (the new default).
    static func migrateLegacyTheme(_ raw: String) -> String? {
        if ThemePreference(rawValue: raw) != nil { return nil }
        return ThemePreference.light.rawValue
    }
}
