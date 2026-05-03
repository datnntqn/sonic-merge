// RootTabView.swift
// SonicMerge
//
// Three-tab shell: Smart Cut · Denoise · Merge. Default selection is Smart
// Cut. Each tab is a NavigationStack with list → detail navigation.

import SwiftUI
import SwiftData
import AVFoundation

struct RootTabView: View {
    enum Tab: Hashable { case smartCut, denoise, merge }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var selection: Tab = .smartCut
    @State private var smartCutPath = NavigationPath()
    @State private var denoisePath = NavigationPath()
    @State private var mergePath = NavigationPath()

    @State private var fillerLibraryStore = FillerLibraryStore()

    /// Lazy-init: created on first appear, after modelContext is available.
    /// MixingStationViewModel.init takes ModelContext and cannot use a
    /// default-arg @State initializer that runs before the environment is
    /// resolved.
    @State private var mixingStationViewModel: MixingStationViewModel?

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack(path: $smartCutPath) {
                SmartCutHomeView { sessionId in
                    smartCutPath.append(sessionId)
                }
                .navigationDestination(for: UUID.self) { sessionId in
                    SmartCutSessionView(sessionId: sessionId)
                }
            }
            .tabItem { Label("Smart Cut", systemImage: "sparkles") }
            .tag(Tab.smartCut)

            NavigationStack(path: $denoisePath) {
                DenoiseHomeView { sessionId in
                    denoisePath.append(sessionId)
                }
                .navigationDestination(for: UUID.self) { sessionId in
                    DenoiseSessionView(sessionId: sessionId)
                }
            }
            .tabItem { Label("Denoise", systemImage: "waveform.badge.minus") }
            .tag(Tab.denoise)

            NavigationStack(path: $mergePath) {
                Group {
                    if let vm = mixingStationViewModel {
                        MixingStationView()
                            .environment(vm)
                    } else {
                        ProgressView()
                    }
                }
            }
            .tabItem { Label("Merge", systemImage: "rectangle.stack") }
            .tag(Tab.merge)
        }
        .environment(\.fillerLibrary, fillerLibraryStore)
        .onAppear {
            if mixingStationViewModel == nil {
                mixingStationViewModel = MixingStationViewModel(modelContext: modelContext)
            }
            handlePendingShareExtensionImport()
            handlePendingSmartCutOpenIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            handlePendingShareExtensionImport()
            handlePendingSmartCutOpenIfNeeded()
        }
        .onOpenURL { url in handleDeepLink(url) }
    }

    // MARK: - Routing

    private func handlePendingShareExtensionImport() {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
        guard let filename = defaults?.string(forKey: "pendingImportFilename") else { return }
        defaults?.removeObject(forKey: "pendingImportFilename")
        let destination = defaults?.string(forKey: "pendingImportDestination") ?? "merge"
        defaults?.removeObject(forKey: "pendingImportDestination")
        let sessionIdString = defaults?.string(forKey: "pendingImportSessionId")
        defaults?.removeObject(forKey: "pendingImportSessionId")
        let basename = defaults?.string(forKey: "pendingImportBasename")
            ?? URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        defaults?.removeObject(forKey: "pendingImportBasename")

        Task { @MainActor in
            await routeShareImport(
                filename: filename,
                destination: destination,
                sessionIdString: sessionIdString,
                basename: basename
            )
        }
    }

    private func routeShareImport(
        filename: String,
        destination: String,
        sessionIdString: String?,
        basename: String
    ) async {
        switch destination {
        case "smart-cut":
            guard let idStr = sessionIdString, let id = UUID(uuidString: idStr) else { return }
            guard let dir = try? AppConstants.smartCutSessionDirectory(for: id) else { return }
            let url = dir.appending(path: filename)
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let duration = (try? await AVURLAsset(url: url).load(.duration).seconds) ?? 0
            let hash = (try? await SourceHasher.sha256Hex(of: url)) ?? ""
            let session = SmartCutSession(
                id: id,
                name: basename,
                sourceFilename: filename,
                sourceHashHex: hash,
                durationSeconds: duration
            )
            modelContext.insert(session)
            try? modelContext.save()
            selection = .smartCut
            smartCutPath.append(id)

        case "merge":
            // Backward-compat: legacy share extension wrote to clips/. Re-emit
            // the legacy key and switch to the Merge tab; MixingStationView's
            // .onAppear reader (Task 6.4) consumes it.
            let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
            defaults?.set(filename, forKey: "pendingImportFilename")
            selection = .merge

        default:
            return
        }
    }

    private func handlePendingSmartCutOpenIfNeeded() {
        guard let session = Self.resolveSessionForPendingHash(in: modelContext) else { return }
        selection = .smartCut
        smartCutPath.append(session.id)
    }

    /// Pure routing helper extracted for testability. Reads
    /// `PendingSmartCutOpen.shared.hash`, strips the `#cloud`/`#local`
    /// suffix, and resolves to a `SmartCutSession`. Always clears the
    /// pending hash — even on miss — so an orphan deep-link doesn't re-fire.
    static func resolveSessionForPendingHash(in context: ModelContext) -> SmartCutSession? {
        guard let raw = PendingSmartCutOpen.shared.hash else { return nil }
        PendingSmartCutOpen.shared.hash = nil
        let bareHash = raw.split(separator: "#").first.map(String.init) ?? raw
        let descriptor = FetchDescriptor<SmartCutSession>(
            predicate: #Predicate { $0.sourceHashHex == bareHash }
        )
        return try? context.fetch(descriptor).first
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "sonicmerge",
              url.host() == "import",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let filename = components.queryItems?.first(where: { $0.name == "file" })?.value
        else { return }
        guard let clipsDir = try? AppConstants.clipsDirectory() else { return }
        let fileURL = clipsDir.appending(path: filename)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        UserDefaults(suiteName: AppConstants.appGroupID)?
            .set(filename, forKey: "pendingImportFilename")
        selection = .merge
    }
}
