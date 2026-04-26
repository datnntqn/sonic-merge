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

    @Environment(\.scenePhase) private var scenePhase

    /// SwiftData ModelContainer configured with the App Group shared container.
    ///
    /// The App Group entitlement must be added in Xcode > target > Signing & Capabilities
    /// > App Groups > "group.com.yourteam.SonicMerge" before this works on a real device
    /// or in a simulator with entitlements. Without the entitlement, `containerURL(...)` returns
    /// nil and ModelConfiguration falls back to the app sandbox — which is acceptable during
    /// development but will not be shared with the future Share Extension target.
    let modelContainer: ModelContainer = {
        AppConstants.prepareAppGroupPersistentStoreDirectory()
        let schema = Schema([AudioClip.self, GapTransition.self])
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

    /// Retained so the scenePhase handler and onOpenURL handler can call importFiles.
    @State private var viewModel: MixingStationViewModel?

    var body: some Scene {
        WindowGroup {
            Group {
                if let viewModel {
                    MixingStationView()
                        .environment(viewModel)
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = MixingStationViewModel(modelContext: modelContainer.mainContext)
                }
            }
            // Pattern 3 (RESEARCH.md): Main app picks up pending import file from App Group
            // UserDefaults whenever the scene becomes active. This is the primary handoff
            // mechanism from the Share Extension — extensionContext.open() is unsupported
            // for Share Extensions (RESEARCH.md Pitfall 1, overrides D-09).
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
                guard let filename = defaults?.string(forKey: "pendingImportFilename") else { return }
                defaults?.removeObject(forKey: "pendingImportFilename")
                guard let clipsDir = try? AppConstants.clipsDirectory() else { return }
                let fileURL = clipsDir.appending(path: filename)
                guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
                viewModel?.importFiles([fileURL])
            }
            // D-08 fallback: onOpenURL for sonicmerge:// scheme (complementary to scenePhase).
            // This fires if the OS is able to open the URL scheme, which may work on future
            // OS versions or via other callers. The Share Extension itself cannot use this
            // (extensionContext.open is Today-widget-only), but keeping it as a fallback
            // is harmless and allows manual deep-link testing via Safari.
            .onOpenURL { url in
                guard url.scheme == "sonicmerge",
                      url.host() == "import",
                      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let filename = components.queryItems?.first(where: { $0.name == "file" })?.value
                else { return }
                guard let clipsDir = try? AppConstants.clipsDirectory() else { return }
                let fileURL = clipsDir.appending(path: filename)
                guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
                viewModel?.importFiles([fileURL])
            }
        }
        .modelContainer(modelContainer)
    }
}
