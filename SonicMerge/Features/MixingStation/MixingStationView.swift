// MixingStationView.swift
// SonicMerge
//
// Root view: Mixing Station with conveyor timeline, toolbar, sheets.

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MixingStationView: View {
    @Environment(MixingStationViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("sonicMergeThemePreference") private var themePreferenceRaw: String = ThemePreference.system.rawValue

    /// Phase 10 (D-06): persists across launches once the user has ever imported a clip.
    /// Gates the LocalFirstTrustStrip render in MergeTimelineView.
    @AppStorage("sonicMerge.hasImportedFirstClip") private var hasImportedFirstClip: Bool = false

    @State private var showDocumentPicker = false
    @State private var showExportSheet = false
    @State private var showCleaningLab = false
    @State private var mergedFileURLForCleaning: URL?

    // POL-01: one trigger @State per toolbar button — prevents cross-firing
    @State private var importHaptic = false
    @State private var appearanceHaptic = false
    @State private var exportHaptic = false
    @State private var denoiseHaptic = false

    private var themePreference: ThemePreference {
        ThemePreference(rawValue: themePreferenceRaw) ?? .system
    }

    private var semantic: SonicMergeSemantic {
        SonicMergeSemantic.resolved(colorScheme: colorScheme, preference: themePreference)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                if viewModel.clips.isEmpty {
                    emptyState
                } else {
                    MergeTimelineView(onExportTap: { showExportSheet = true })
                }
            }
            .navigationTitle("SonicMerge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .navigationDestination(isPresented: $showCleaningLab) {
                if let url = mergedFileURLForCleaning {
                    CleaningLabView(mergedFileURL: url)
                }
            }
            .sheet(isPresented: $showExportSheet) {
                ExportFormatSheet(isPresented: $showExportSheet) { options in
                    viewModel.exportMerged(options: options)
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel.isExporting },
                set: { _ in }
            )) {
                ExportProgressSheet(
                    isNormalizing: viewModel.isNormalizingExport,
                    progress: viewModel.exportProgress,
                    onCancel: { viewModel.cancelExport() }
                )
            }
            .sheet(isPresented: Binding(
                get: { viewModel.showShareSheet },
                set: { if !$0 { viewModel.dismissShareSheet() } }
            )) {
                if let url = viewModel.exportedFileURL {
                    ActivityViewController(
                        activityItems: [url],
                        onDismiss: { viewModel.dismissShareSheet() }
                    )
                }
            }
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: UTType.audioImportTypes,
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls): viewModel.importFiles(urls)
                case .failure: break
                }
            }
            .onDrop(of: UTType.audioDropTypes, isTargeted: nil) { providers in
                guard !providers.isEmpty else { return false }
                Task {
                    let urls = await AudioDropImport.urls(from: providers)
                    guard !urls.isEmpty else { return }
                    await MainActor.run {
                        viewModel.importFiles(urls)
                    }
                }
                return true
            }
        }
        .environment(\.sonicMergeSemantic, semantic)
        .onChange(of: showCleaningLab) { _, isShowing in
            if !isShowing, let url = mergedFileURLForCleaning {
                try? FileManager.default.removeItem(at: url)
                mergedFileURLForCleaning = nil
            }
        }
        .onChange(of: viewModel.clips.count) { _, newCount in
            // Phase 10 D-06: flip the first-launch trust-banner flag the first
            // time the user has any clips. Persists across launches via @AppStorage.
            if newCount > 0 && !hasImportedFirstClip {
                hasImportedFirstClip = true
            }
        }
        .task {
            await viewModel.fetchAll()
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: SonicMergeTheme.Spacing.md) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundStyle(Color(uiColor: semantic.accentAction))
                .shadow(
                    color: Color(uiColor: semantic.accentGlow).opacity(0.35),
                    radius: 20,
                    x: 0,
                    y: 0
                )
                .accessibilityHidden(true)
            Text("No clips yet")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
            Text("Tap + to add audio files\nor drop them here")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                .multilineTextAlignment(.center)
            Button {
                showDocumentPicker = true
            } label: {
                Label("Import Audio", systemImage: "plus.circle.fill")
            }
            .buttonStyle(PillButtonStyle(variant: .filled, size: .regular))
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                importHaptic.toggle()
                showDocumentPicker = true
            } label: {
                Label("Import", systemImage: "plus")
            }
            .disabled(viewModel.isImporting || viewModel.isExporting)
            .sensoryFeedback(.impact(weight: .light), trigger: importHaptic)
        }
        // Phase 10 D-03: source order Denoise → Export → ••• yields visual layout
        // (left-to-right) Denoise · Export · ••• at the trailing edge, with ••• as
        // the canonical "more" position at the far-right corner.
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                denoiseHaptic.toggle()
                navigateToCleaningLab()
            } label: {
                Label("Denoise", systemImage: "waveform.badge.minus")
            }
            .disabled(viewModel.clips.isEmpty)
            // Phase 10: tint Lime Green to reinforce the Phase 8 AI identity —
            // this is the only AI-feature affordance in the toolbar, and the
            // tint differentiates it from the indigo-default Export / ••• icons.
            // iOS dims the tint automatically in the disabled state.
            .tint(Color(uiColor: semantic.accentAI))
            .sensoryFeedback(.impact(weight: .light), trigger: denoiseHaptic)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                exportHaptic.toggle()
                showExportSheet = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel.clips.isEmpty || viewModel.isExporting)
            .sensoryFeedback(.impact(weight: .light), trigger: exportHaptic)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Appearance", selection: $themePreferenceRaw) {
                    Text("System").tag(ThemePreference.system.rawValue)
                    Text("Light").tag(ThemePreference.light.rawValue)
                    Text("Dark conveyor").tag(ThemePreference.dark.rawValue)
                }
            } label: {
                Label("More options", systemImage: "ellipsis.circle")
            }
            .sensoryFeedback(.impact(weight: .light), trigger: themePreferenceRaw)
        }
    }

    // MARK: - Cleaning Lab Navigation

    private func navigateToCleaningLab() {
        viewModel.stopClipPreview()
        let destURL = FileManager.default.temporaryDirectory
            .appending(path: "SonicMerge-CleaningLab-\(UUID().uuidString).wav")

        Task {
            let mergerService = AudioMergerService()
            let stream = await mergerService.export(
                clips: viewModel.clips.sorted(by: { $0.sortOrder < $1.sortOrder }),
                transitions: viewModel.transitions,
                format: .wav,
                destinationURL: destURL
            )
            for await _ in stream {}
            if FileManager.default.fileExists(atPath: destURL.path) {
                mergedFileURLForCleaning = destURL
                showCleaningLab = true
            }
        }
    }
}

// MARK: - Drag & drop

private enum AudioDropImport {
    static func urls(from providers: [NSItemProvider]) async -> [URL] {
        await withTaskGroup(of: URL?.self) { group in
            for provider in providers {
                group.addTask { await url(from: provider) }
            }
            var result: [URL] = []
            for await url in group {
                if let url {
                    result.append(url)
                }
            }
            return result
        }
    }

    private static func url(from provider: NSItemProvider) async -> URL? {
        if provider.canLoadObject(ofClass: URL.self) {
            return await withCheckedContinuation { continuation in
                _ = provider.loadObject(ofClass: URL.self) { object, _ in
                    continuation.resume(returning: object)
                }
            }
        }
        for ut in UTType.audioDropTypes where provider.hasItemConformingToTypeIdentifier(ut.identifier) {
            return await withCheckedContinuation { continuation in
                provider.loadFileRepresentation(forTypeIdentifier: ut.identifier) { tempURL, error in
                    guard let tempURL, error == nil else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let dest = FileManager.default.temporaryDirectory
                        .appending(path: "SonicMerge-drop-\(UUID().uuidString)-\(tempURL.lastPathComponent)")
                    do {
                        try FileManager.default.copyItem(at: tempURL, to: dest)
                        continuation.resume(returning: dest)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
        return nil
    }
}
