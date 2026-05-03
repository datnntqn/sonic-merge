// RootTabView.swift
// SonicMerge
//
// Three-tab shell: Smart Cut · Denoise · Merge. Default selection is Smart
// Cut. Each tab is a NavigationStack with list → detail navigation.

import SwiftUI
import SwiftData

struct RootTabView: View {
    enum Tab: Hashable { case smartCut, denoise, merge }

    @Environment(\.modelContext) private var modelContext

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
        }
    }
}
